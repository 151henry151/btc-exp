defmodule BitcoinexExplorerWeb.ExplorerLive do
  use BitcoinexExplorerWeb, :live_view_root_only

  import Phoenix.LiveView, only: [connected?: 1, redirect: 2, push_patch: 2]

  alias BitcoinexExplorer.{
    DataSource,
    Decode,
    OutputClassifier,
    Search,
    TxEnrichment,
    TxFlow
  }

  defp ds, do: DataSource.impl()

  @poll_blocks_ms 15_000
  @poll_mempool_ms 30_000

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:input, "")
      |> assign(:result, nil)
      |> assign(:error, nil)
      |> assign(:page_error, nil)
      |> assign(:nav_input, "")
      # home
      |> assign(:blocks, [])
      |> assign(:tip_hash, nil)
      |> assign(:mempool_stats, nil)
      |> assign(:fee_estimates, nil)
      |> assign(:mempool_error, nil)
      |> assign(:blocks_error, nil)
      # block
      |> assign(:block_data, nil)
      |> assign(:block_txs, [])
      |> assign(:block_tx_start, 0)
      |> assign(:block_txs_next, true)
      |> assign(:block_script_counts, OutputClassifier.empty_counts_map())
      |> assign(:block_chart_data, "[]")
      |> assign(:block_error, nil)
      |> assign(:block_miner, nil)
      # tx
      |> assign(:tx_data, nil)
      |> assign(:tx_enriched_vin, [])
      |> assign(:tx_enriched_vout, [])
      |> assign(:tx_flow_json, "{}")
      |> assign(:tx_error, nil)
      # address
      |> assign(:addr_string, nil)
      |> assign(:addr_decode, nil)
      |> assign(:addr_info, nil)
      |> assign(:addr_txs, [])
      |> assign(:addr_error, nil)
      |> assign(:addr_txs_last, nil)
      |> assign(:addr_txs_has_more, false)
      |> assign(:poll_booted, false)

    {:ok, socket}
  end

  defp schedule_blocks_poll(socket) do
    Process.send_after(self(), :poll_blocks, @poll_blocks_ms)
    socket
  end

  defp schedule_mempool_poll(socket) do
    Process.send_after(self(), :poll_mempool, @poll_mempool_ms)
    socket
  end

  @impl true
  def handle_params(params, _uri, socket) do
    nav =
      case socket.assigns.live_action do
        :tx -> Map.get(params, "txid", "")
        :block -> truncate_nav(Map.get(params, "hash", ""))
        :address -> Map.get(params, "address", "")
        _ -> ""
      end

    socket =
      socket
      |> assign(:nav_input, nav)
      |> assign(:page_title, page_title_for(socket.assigns.live_action, params))

    socket =
      try do
        case socket.assigns.live_action do
          :home ->
            # Chain dashboard calls are sequential (not concurrent): recent blocks
            # (multiple paginated GETs) → fee estimates → mempool. Esplora limits by
            # request arrivals; avoid loading on the disconnected render so we do not
            # duplicate the full burst when the LiveView connects.
            if connected?(socket) do
              fetch_home_data(socket)
            else
              socket
            end

          :block ->
            socket |> load_block(Map.get(params, "hash"))

          :tx ->
            socket |> load_tx(Map.get(params, "txid"))

          :address ->
            socket |> load_address(Map.get(params, "address"))
        end
      rescue
        e ->
          assign(socket, :page_error, Exception.message(e))
      end

    socket =
      cond do
        !connected?(socket) ->
          socket

        socket.assigns.live_action != :home ->
          assign(socket, :poll_booted, false)

        !socket.assigns[:poll_booted] ->
          socket
          |> assign(:poll_booted, true)
          |> tap(fn _ -> Process.send_after(self(), :poll_blocks, @poll_blocks_ms) end)
          |> tap(fn _ -> Process.send_after(self(), :poll_mempool, @poll_mempool_ms) end)

        true ->
          socket
      end

    {:noreply, socket}
  end

  defp page_title_for(:home, _), do: "Bitcoinex Explorer"

  defp page_title_for(:block, %{"hash" => h}),
    do: "Block #{truncate_middle(h, 12)} · Bitcoinex Explorer"

  defp page_title_for(:tx, %{"txid" => t}),
    do: "Tx #{truncate_middle(t, 12)} · Bitcoinex Explorer"

  defp page_title_for(:address, %{"address" => a}),
    do: "Address #{truncate_middle(a, 16)} · Bitcoinex Explorer"

  defp page_title_for(_, _), do: "Bitcoinex Explorer"

  defp truncate_nav(h) when byte_size(h) > 18, do: String.slice(h, 0, 10) <> "…"
  defp truncate_nav(h), do: h

  defp fetch_home_data(socket) do
    socket =
      case ds().get_recent_blocks(100) do
        {:ok, list} when is_list(list) ->
          tip =
            case list do
              [%{"id" => id} | _] -> id
              _ -> nil
            end

          assign(socket, blocks: list, tip_hash: tip, blocks_error: nil)

        {:error, reason} ->
          assign(socket, blocks_error: esplora_err(reason))
      end

    socket =
      case ds().get_fee_estimates() do
        {:ok, fees} ->
          assign(socket, fee_estimates: fees)

        {:error, _} ->
          assign(socket, fee_estimates: %{})
      end

    socket =
      case ds().get_mempool() do
        {:ok, stats} ->
          assign(socket, mempool_stats: stats, mempool_error: nil)

        {:error, reason} ->
          assign(socket, mempool_error: esplora_err(reason))
      end

    socket
  end

  defp load_block(socket, hash) when is_binary(hash) do
    hash = String.downcase(hash)

    socket =
      case ds().get_block(hash) do
        {:ok, block} ->
          miner = guess_miner(block)

          socket
          |> assign(:block_data, block)
          |> assign(:block_error, nil)
          |> assign(:block_miner, miner)

        {:error, :not_found} ->
          assign(socket,
            block_data: nil,
            block_error: "Block not found. Check the hash.",
            block_txs: [],
            block_chart_data: "[]"
          )

        {:error, reason} ->
          assign(socket,
            block_data: nil,
            block_error: esplora_err(reason),
            block_txs: [],
            block_chart_data: "[]"
          )
      end

    if socket.assigns.block_data do
      socket
      |> assign(:block_tx_start, 0)
      |> fetch_block_tx_page(hash, 0)
    else
      socket
    end
  end

  defp guess_miner(block) do
    case ds().get_block_txs(block["id"], 0) do
      {:ok, [coinbase | _]} ->
        TxEnrichment.enrich_vin(Enum.at(Map.get(coinbase, "vin", []), 0) || %{})["coinbase_text"]

      _ ->
        "—"
    end
  end

  defp fetch_block_tx_page(socket, hash, start_index) do
    case ds().get_block_txs(hash, start_index) do
      {:ok, txs} when is_list(txs) ->
        txs = txs || []
        next = length(txs) == 25

        merged = if start_index == 0, do: txs, else: socket.assigns.block_txs ++ txs

        counts =
          merged
          |> Enum.flat_map(&(Map.get(&1, "vout", []) || []))
          |> OutputClassifier.counts_from_vouts()

        chart =
          counts
          |> OutputClassifier.counts_to_chart_data()
          |> Jason.encode!()

        socket
        |> assign(:block_txs, merged)
        |> assign(:block_tx_start, start_index + length(txs))
        |> assign(:block_txs_next, next)
        |> assign(:block_script_counts, counts)
        |> assign(:block_chart_data, chart)

      {:error, reason} ->
        assign(socket, :block_error, esplora_err(reason))
    end
  end

  defp load_tx(socket, txid) when is_binary(txid) do
    txid = String.downcase(txid)

    case ds().get_tx(txid) do
      {:ok, tx} ->
        vin = Enum.map(Map.get(tx, "vin", []) || [], &TxEnrichment.enrich_vin/1)
        vout = Enum.map(Map.get(tx, "vout", []) || [], &TxEnrichment.enrich_vout/1)

        socket
        |> assign(:tx_data, tx)
        |> assign(:tx_enriched_vin, vin)
        |> assign(:tx_enriched_vout, vout)
        |> assign(:tx_flow_json, TxFlow.encode(tx))
        |> assign(:tx_error, nil)

      {:error, :not_found} ->
        socket
        |> assign(:tx_data, nil)
        |> assign(:tx_error, "Transaction not found.")
        |> assign(:tx_flow_json, "{}")
        |> assign(:tx_enriched_vin, [])
        |> assign(:tx_enriched_vout, [])

      {:error, reason} ->
        socket
        |> assign(:tx_data, nil)
        |> assign(:tx_error, esplora_err(reason))
        |> assign(:tx_flow_json, "{}")
        |> assign(:tx_enriched_vin, [])
        |> assign(:tx_enriched_vout, [])
    end
  end

  defp load_address(socket, addr) when is_binary(addr) do
    addr = URI.decode(addr)

    decode =
      case Decode.decode_address(addr) do
        {:ok, m} -> m
        {:error, _} -> nil
      end

    socket =
      socket
      |> assign(:addr_string, addr)
      |> assign(:addr_decode, decode)

    socket =
      case ds().get_address(addr) do
        {:ok, info} ->
          assign(socket, addr_info: info, addr_error: nil)

        {:error, :not_found} ->
          assign(socket, addr_info: nil, addr_error: "Address not found on chain lookup.")

        {:error, reason} ->
          assign(socket, addr_info: nil, addr_error: esplora_err(reason))
      end

    case ds().get_address_txs(addr, nil) do
      {:ok, txs} when is_list(txs) ->
        last = List.last(txs)
        last_id = if last, do: Map.get(last, "txid"), else: nil

        socket
        |> assign(:addr_txs, txs)
        |> assign(:addr_txs_last, last_id)
        |> assign(:addr_txs_has_more, length(txs) >= 25)

      {:error, reason} ->
        assign(socket, :addr_error, esplora_err(reason))
    end
  end

  defp esplora_err({:http_error, status, _}), do: "Esplora HTTP #{status}"
  defp esplora_err({:transport, reason}), do: "Network error: #{inspect(reason)}"
  defp esplora_err(other), do: inspect(other)

  @impl true
  def handle_event("decode", %{"input" => input}, socket) do
    value = String.trim(input || "")

    if value == "" do
      {:noreply, assign(socket, input: "", result: nil, error: nil)}
    else
      case Decode.decode_auto(value) do
        {:ok, result} ->
          {:noreply, assign(socket, input: input, result: result, error: nil)}

        {:error, message} ->
          {:noreply, assign(socket, input: input, result: nil, error: message)}
      end
    end
  end

  def handle_event("search", %{"q" => q}, socket) do
    trimmed = String.trim(q || "")

    if trimmed == "" do
      {:noreply, socket}
    else
      case Search.classify(trimmed) do
        {:bolt11, _} ->
          case Decode.decode_auto(trimmed) do
            {:ok, res} ->
              {:noreply,
               socket
               |> assign(:nav_input, trimmed)
               |> assign(:input, trimmed)
               |> assign(:result, res)
               |> assign(:error, nil)
               |> push_patch(to: ~p"/")}

            {:error, msg} ->
              {:noreply,
               socket
               |> assign(:nav_input, trimmed)
               |> assign(:error, msg)
               |> assign(:result, nil)
               |> push_patch(to: ~p"/")}
          end

        {:psbt, _} ->
          case Decode.decode_auto(trimmed) do
            {:ok, res} ->
              {:noreply,
               socket
               |> assign(:nav_input, trimmed)
               |> assign(:input, trimmed)
               |> assign(:result, res)
               |> assign(:error, nil)
               |> push_patch(to: ~p"/")}

            {:error, msg} ->
              {:noreply,
               socket
               |> assign(:nav_input, trimmed)
               |> assign(:error, msg)
               |> assign(:result, nil)
               |> push_patch(to: ~p"/")}
          end

        {:hex64, h} ->
          case ds().get_tx(h) do
            {:ok, _} ->
              {:noreply, push_patch(socket, to: ~p"/tx/#{h}")}

            {:error, _} ->
              case ds().get_block(h) do
                {:ok, _} ->
                  {:noreply, push_patch(socket, to: ~p"/block/#{h}")}

                {:error, _} ->
                  {:noreply,
                   assign(socket,
                     error: "Nothing found for that 64-character hex (not a tx id or block hash)."
                   )}
              end
          end

        {:block_height, height} ->
          {:noreply, redirect(socket, to: ~p"/block/height/#{height}")}

        {:address, addr} ->
          {:noreply, push_patch(socket, to: ~p"/address/#{addr}")}

        {:decode_only, t} ->
          case Decode.decode_auto(t) do
            {:ok, res} ->
              {:noreply,
               socket
               |> assign(:nav_input, t)
               |> assign(:input, t)
               |> assign(:result, res)
               |> assign(:error, nil)
               |> push_patch(to: ~p"/")}

            {:error, msg} ->
              {:noreply,
               socket
               |> assign(:nav_input, t)
               |> assign(:error, msg)
               |> assign(:result, nil)
               |> push_patch(to: ~p"/")}
          end
      end
    end
  end

  def handle_event("goto_address", %{"address" => addr}, socket) do
    {:noreply, push_patch(socket, to: ~p"/address/#{URI.encode(addr, &URI.char_unreserved?/1)}")}
  end

  def handle_event("load_more_block_txs", %{"hash" => hash}, socket) do
    start = socket.assigns.block_tx_start

    {:noreply,
     socket
     |> fetch_block_tx_page(String.downcase(hash), start)}
  end

  def handle_event("load_more_addr_txs", _, socket) do
    addr = socket.assigns.addr_string
    last = socket.assigns.addr_txs_last

    case ds().get_address_txs(addr, last) do
      {:ok, more} when is_list(more) and more != [] ->
        merged = socket.assigns.addr_txs ++ more
        last = List.last(more) |> then(&Map.get(&1, "txid"))

        {:noreply,
         socket
         |> assign(:addr_txs, merged)
         |> assign(:addr_txs_last, last)
         |> assign(:addr_txs_has_more, length(more) >= 25)}

      _ ->
        {:noreply, assign(socket, :addr_txs_has_more, false)}
    end
  end

  @impl true
  def handle_info(:poll_blocks, socket) do
    socket =
      if socket.assigns.live_action != :home do
        socket
      else
        case ds().get_recent_blocks(100) do
          {:ok, list} when is_list(list) ->
            tip =
              case list do
                [%{"id" => id} | _] -> id
                _ -> nil
              end

            socket =
              if tip != socket.assigns.tip_hash do
                socket
                |> assign(:blocks, list)
                |> assign(:tip_hash, tip)
              else
                socket
              end

            assign(socket, :blocks_error, nil)

          {:error, reason} ->
            assign(socket, :blocks_error, esplora_err(reason))
        end
      end

    {:noreply, schedule_blocks_poll(socket)}
  rescue
    _ ->
      {:noreply, schedule_blocks_poll(socket)}
  end

  def handle_info(:poll_mempool, socket) do
    socket =
      if socket.assigns.live_action != :home do
        socket
      else
        case ds().get_mempool() do
          {:ok, stats} ->
            assign(socket, :mempool_stats, stats)

          {:error, reason} ->
            assign(socket, :mempool_error, esplora_err(reason))
        end
      end

    {:noreply, schedule_mempool_poll(socket)}
  rescue
    _ ->
      {:noreply, schedule_mempool_poll(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="explorer-root" class="min-h-screen bg-[#0f0f0f] text-zinc-100">
      <.nav_bar {assigns} />

      <main class="mx-auto w-full max-w-6xl px-4 py-6 md:px-6">
        <p
          :if={assigns[:page_error]}
          class="mb-4 rounded border border-red-500/40 bg-red-500/10 p-3 text-sm text-red-300"
        >
          <%= @page_error %>
        </p>

        <%= case @live_action do %>
          <% :home -> %>
            <.home_view {assigns} />
          <% :block -> %>
            <.block_view {assigns} />
          <% :tx -> %>
            <.tx_view {assigns} />
          <% :address -> %>
            <.address_view {assigns} />
        <% end %>
      </main>

      <footer class="mx-auto mt-10 max-w-6xl px-4 pb-8 text-center text-xs text-zinc-500">
        <nav class="flex flex-wrap items-center justify-center gap-x-3 gap-y-1">
          <.link
            href="https://hromp.com/"
            class="text-zinc-400 underline-offset-2 hover:text-[#f7931a] hover:underline"
          >
            hromp.com
          </.link>
          <span class="text-zinc-600">·</span>
          <.link
            href="https://github.com/151henry151/bitcoinex-explorer"
            class="text-zinc-400 underline-offset-2 hover:text-[#f7931a] hover:underline"
            target="_blank"
            rel="noopener noreferrer"
          >
            GitHub
          </.link>
        </nav>
        <p class="mt-2">
          Chain data via Esplora-compatible API · Built with River Financial's
          <a
            href="https://github.com/RiverFinancial/bitcoinex"
            class="text-zinc-400 underline-offset-2 hover:text-[#f7931a] hover:underline"
            target="_blank"
            rel="noopener noreferrer"
          >
            Bitcoinex
          </a>
        </p>
      </footer>
    </div>
    """
  end

  defp nav_bar(assigns) do
    ~H"""
    <header class="sticky top-0 z-40 border-b border-zinc-800 bg-[#0f0f0f]/95 backdrop-blur">
      <div class="mx-auto flex max-w-6xl flex-wrap items-center gap-3 px-4 py-3 md:gap-4 md:px-6">
        <.link navigate={~p"/"} class="shrink-0 text-lg font-semibold text-[#f7931a]">
          Bitcoinex Explorer
        </.link>

        <form
          phx-submit="search"
          class="mx-auto flex min-w-[200px] flex-1 items-center gap-2 md:max-w-xl"
        >
          <input
            type="text"
            name="q"
            value={@nav_input}
            placeholder="Txid, block hash, height, address, invoice, PSBT…"
            autocomplete="off"
            class="w-full rounded-lg border border-zinc-700 bg-zinc-950 px-3 py-2 font-mono text-sm text-zinc-100 placeholder:text-zinc-500 focus:border-[#f7931a] focus:outline-none focus:ring-1 focus:ring-[#f7931a]"
          />
          <button
            type="submit"
            class="rounded-lg bg-[#f7931a] px-3 py-2 text-sm font-medium text-black hover:bg-[#ffa433]"
          >
            Search
          </button>
        </form>

        <a
          href="https://hromp.com/bitcoinex-explorer/"
          class="ml-auto shrink-0 text-sm text-zinc-400 hover:text-[#f7931a]"
        >
          About
        </a>
      </div>
    </header>
    """
  end

  defp home_view(assigns) do
    ~H"""
    <div class="flex flex-col gap-8">
      <section class="grid gap-4 md:grid-cols-2">
        <div class="rounded-2xl border border-zinc-800 bg-zinc-900 p-4">
          <h2 class="mb-3 text-lg font-medium text-zinc-200">Mempool</h2>
          <p :if={@mempool_error} class="text-sm text-orange-300"><%= @mempool_error %></p>
          <%= if @mempool_stats do %>
            <dl class="grid grid-cols-2 gap-2 text-sm">
              <dt class="text-zinc-500">Pending txs</dt>
              <dd class="font-mono"><%= @mempool_stats["count"] %></dd>
              <dt class="text-zinc-500">Virtual size</dt>
              <dd class="font-mono"><%= format_vsize(@mempool_stats["vsize"]) %></dd>
            </dl>
          <% end %>
        </div>

        <div class="rounded-2xl border border-zinc-800 bg-zinc-900 p-4">
          <h2 class="mb-3 text-lg font-medium text-zinc-200">Fee estimates (sat/vB)</h2>
          <div class="grid grid-cols-2 gap-2 text-sm md:grid-cols-4">
            <%= for {label, target} <- [{"Next", 1}, {"3 blk", 3}, {"6 blk", 6}, {"~1d", 144}] do %>
              <div class="rounded-lg bg-zinc-950 p-2">
                <div class="text-xs text-zinc-500"><%= label %></div>
                <div class={"mt-1 font-mono #{fee_class(fee_at(@fee_estimates, target))}"}>
                  <%= fmt_fee(fee_at(@fee_estimates, target)) %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </section>

      <section class="rounded-2xl border border-zinc-800 bg-zinc-900 p-4">
        <h2 class="mb-3 flex items-center gap-2 text-lg font-medium text-zinc-200">
          <span class="relative flex h-2 w-2">
            <span class="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-75">
            </span>
            <span class="relative inline-flex h-2 w-2 rounded-full bg-emerald-500"></span>
          </span>
          Live blocks
        </h2>
        <p class="mb-2 text-xs text-zinc-500">
          <%= length(@blocks) %> recent blocks (tip downward). Scroll the table for more — up to ~100 loaded from Esplora.
        </p>
        <p :if={@blocks_error} class="mb-2 text-sm text-orange-300"><%= @blocks_error %></p>
        <div class="overflow-x-auto rounded-lg border border-zinc-800">
          <div class="max-h-[11rem] overflow-y-auto overscroll-y-contain">
            <table class="w-full text-left text-sm">
              <thead class="sticky top-0 z-10 bg-zinc-900 text-xs uppercase text-zinc-500 shadow-[0_1px_0_0_rgba(39,39,42,0.9)]">
                <tr>
                  <th class="px-2 py-2">Height</th>
                  <th class="px-2 py-2">Hash</th>
                  <th class="px-2 py-2">When</th>
                  <th class="px-2 py-2">Txs</th>
                  <th class="px-2 py-2">Size</th>
                </tr>
              </thead>
              <tbody class="font-mono text-xs text-zinc-300">
                <%= for b <- @blocks do %>
                  <tr class="border-t border-zinc-800/80 transition hover:bg-zinc-800/60">
                    <td class="px-2 py-2"><%= b["height"] %></td>
                    <td class="px-2 py-2">
                      <.link
                        navigate={~p"/block/#{b["id"]}"}
                        class="text-[#f7931a] hover:underline"
                        title={b["id"]}
                      >
                        <%= truncate_middle(b["id"], 14) %>
                      </.link>
                    </td>
                    <td class="px-2 py-2 whitespace-nowrap">
                      <span
                        phx-hook="RelativeTime"
                        id={"blk-#{b["id"]}"}
                        data-unix={b["timestamp"]}
                        class="text-zinc-400"
                      >
                        <%= fmt_rel(b["timestamp"]) %>
                      </span>
                    </td>
                    <td class="px-2 py-2"><%= b["tx_count"] %></td>
                    <td class="px-2 py-2"><%= format_kb(b["size"]) %></td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </section>

      <section class="rounded-2xl border border-zinc-800 bg-zinc-900 p-4 md:p-6">
        <h2 class="mb-3 text-lg font-medium text-zinc-200">Decode locally</h2>
        <p class="mb-3 text-sm text-zinc-400">
          Paste a Bitcoin address, BOLT11 Lightning invoice, or base64 PSBT — decoded with Bitcoinex (no chain lookup).
        </p>
        <form id="decode-form" phx-change="decode" class="space-y-3">
          <label class="text-sm font-medium text-zinc-300">Input</label>
          <textarea
            name="input"
            rows="5"
            phx-debounce="300"
            class="w-full rounded-xl border border-zinc-700 bg-zinc-950 p-3 font-mono text-sm leading-6 text-zinc-100 outline-none ring-[#f7931a] placeholder:text-zinc-500 focus:ring-1"
            placeholder="bc1q…, lnbc…, cHNidP8BA…"
          ><%= @input %></textarea>
        </form>

        <p
          :if={@error}
          class="mt-3 rounded-lg border border-orange-500/40 bg-orange-500/10 p-3 text-sm text-orange-300"
        >
          <%= @error %>
        </p>

        <div :if={@result} class="mt-4 overflow-hidden rounded-xl border border-zinc-700">
          <dl class="divide-y divide-zinc-800">
            <%= for {key, value} <- Decode.rows_for_result(@result) do %>
              <div class="grid grid-cols-1 gap-1 p-3 md:grid-cols-[220px_1fr] md:gap-4">
                <dt class="text-xs uppercase tracking-wide text-zinc-400"><%= key %></dt>
                <dd class="break-all whitespace-pre-wrap font-mono text-sm text-zinc-100">
                  <%= value %>
                </dd>
              </div>
            <% end %>
          </dl>
        </div>
      </section>
    </div>
    """
  end

  defp block_view(assigns) do
    ~H"""
    <div class="space-y-6">
      <p
        :if={@block_error}
        class="rounded border border-orange-500/40 bg-orange-500/10 p-3 text-sm text-orange-300"
      >
        <%= @block_error %>
      </p>

      <%= if @block_data do %>
        <% b = @block_data %>
        <section class="rounded-2xl border border-zinc-800 bg-zinc-900 p-4 md:p-6">
          <h1 class="mb-4 text-2xl font-semibold text-[#f7931a]">Block <%= b["height"] %></h1>
          <dl class="grid gap-3 text-sm md:grid-cols-2">
            <.meta_row label="Hash" value={b["id"]} mono={true} link={nil} />
            <.meta_row label="Timestamp" value={fmt_unix(b["timestamp"])} mono={false} link={nil} />
            <.meta_row label="Transactions" value={to_string(b["tx_count"])} mono={false} link={nil} />
            <.meta_row label="Size" value={"#{b["size"]} bytes"} mono={false} link={nil} />
            <.meta_row label="Weight" value={to_string(b["weight"])} mono={false} link={nil} />
            <.meta_row
              label="Difficulty"
              value={format_float(b["difficulty"])}
              mono={false}
              link={nil}
            />
            <.meta_row label="Merkle root" value={b["merkle_root"]} mono={true} link={nil} />
            <.meta_row
              label="Previous block"
              value={b["previousblockhash"]}
              mono={true}
              link={~p"/block/#{b["previousblockhash"]}"}
            />
            <.meta_row label="Miner (coinbase hint)" value={@block_miner} mono={false} link={nil} />
          </dl>
        </section>

        <section class="rounded-2xl border border-zinc-800 bg-zinc-900 p-4">
          <h2 class="mb-3 text-lg font-medium">Output script types (loaded txs)</h2>
          <div
            id="script-type-chart"
            phx-hook="ScriptTypeChart"
            data-chartdata={@block_chart_data}
            class="min-h-[72px] w-full"
          >
          </div>
        </section>

        <section class="rounded-2xl border border-zinc-800 bg-zinc-900 p-4">
          <h2 class="mb-3 text-lg font-medium">Transactions</h2>
          <div class="overflow-x-auto">
            <table class="w-full text-left text-sm">
              <thead class="text-xs uppercase text-zinc-500">
                <tr>
                  <th class="pb-2">Txid</th>
                  <th class="pb-2">In</th>
                  <th class="pb-2">Out</th>
                  <th class="pb-2">Output total</th>
                  <th class="pb-2">Fee</th>
                </tr>
              </thead>
              <tbody class="font-mono text-xs">
                <%= for tx <- @block_txs do %>
                  <tr class="border-t border-zinc-800">
                    <td class="py-2">
                      <.link
                        navigate={~p"/tx/#{tx["txid"]}"}
                        class="text-[#f7931a]"
                        title={tx["txid"]}
                      >
                        <%= truncate_middle(tx["txid"], 14) %>
                      </.link>
                    </td>
                    <td class="py-2"><%= length(Map.get(tx, "vin", []) || []) %></td>
                    <td class="py-2"><%= length(Map.get(tx, "vout", []) || []) %></td>
                    <td class="py-2"><%= fmt_btc(sum_outputs(tx)) %> BTC</td>
                    <td class="py-2"><%= Map.get(tx, "fee", 0) %> sat</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <button
            :if={@block_txs_next}
            type="button"
            phx-click="load_more_block_txs"
            phx-value-hash={@block_data["id"]}
            class="mt-4 rounded-lg border border-zinc-600 px-4 py-2 text-sm text-zinc-200 hover:bg-zinc-800"
          >
            Load more transactions
          </button>
        </section>
      <% end %>
    </div>
    """
  end

  defp meta_row(assigns) do
    ~H"""
    <div>
      <dt class="text-xs uppercase text-zinc-500"><%= @label %></dt>
      <dd class="mt-1 font-mono text-sm break-all text-zinc-200">
        <%= if @link do %>
          <.link navigate={@link} class="text-[#f7931a] hover:underline" title={@value}>
            <%= @value %>
          </.link>
        <% else %>
          <span title={@value}><%= @value %></span>
        <% end %>
      </dd>
    </div>
    """
  end

  defp tx_view(assigns) do
    ~H"""
    <div class="space-y-6">
      <p
        :if={@tx_error}
        class="rounded border border-orange-500/40 bg-orange-500/10 p-3 text-sm text-orange-300"
      >
        <%= @tx_error %>
      </p>

      <%= if @tx_data do %>
        <% t = @tx_data %>
        <% st = Map.get(t, "status", %{}) %>
        <% conf = if st["confirmed"], do: "confirmed", else: "unconfirmed" %>
        <% bh = st["block_height"] %>
        <% fr = fee_rate(t) %>

        <section class="rounded-2xl border border-zinc-800 bg-zinc-900 p-4 md:p-6">
          <h1 class="mb-4 text-2xl font-semibold text-[#f7931a]">Transaction</h1>
          <p class="mb-4 break-all font-mono text-sm text-zinc-300" title={t["txid"]}>
            <%= t["txid"] %>
          </p>
          <dl class="grid gap-3 text-sm md:grid-cols-2">
            <.meta_row label="Status" value={conf} mono={false} link={nil} />
            <.meta_row
              label="Block height"
              value={if(bh, do: to_string(bh), else: "—")}
              mono={false}
              link={if(bh && st["block_hash"], do: ~p"/block/#{st["block_hash"]}", else: nil)}
            />
            <.meta_row label="Fee" value={"#{Map.get(t, "fee", 0)} sat"} mono={false} link={nil} />
            <.meta_row label="Fee rate" value={"#{fr} sat/vB"} mono={false} link={nil} />
            <.meta_row
              label="Size / weight"
              value={"#{t["size"]} / #{t["weight"]}"}
              mono={false}
              link={nil}
            />
            <.meta_row
              label="Locktime"
              value={to_string(Map.get(t, "locktime", 0))}
              mono={false}
              link={nil}
            />
          </dl>
        </section>

        <section class="rounded-2xl border border-zinc-800 bg-zinc-900 p-4">
          <h2 class="mb-3 text-lg font-medium">Flow</h2>
          <div
            id="tx-flow-graph"
            phx-hook="TxFlowGraph"
            data-txdata={@tx_flow_json}
            class="min-h-[280px] w-full overflow-auto"
          >
          </div>
        </section>

        <section class="rounded-2xl border border-zinc-800 bg-zinc-900 p-4">
          <h2 class="mb-3 text-lg font-medium">Inputs</h2>
          <div class="overflow-x-auto">
            <table class="w-full text-left text-xs">
              <thead class="text-zinc-500">
                <tr>
                  <th class="pb-2">Prev out</th>
                  <th class="pb-2">Value</th>
                  <th class="pb-2">Network</th>
                  <th class="pb-2">Type</th>
                  <th class="pb-2">Witness ver.</th>
                  <th class="pb-2">Program / payload</th>
                </tr>
              </thead>
              <tbody class="font-mono text-zinc-300">
                <%= for row <- @tx_enriched_vin do %>
                  <tr class="border-t border-zinc-800 align-top">
                    <td class="py-2">
                      <%= if row["bx_prev_address"] != "" do %>
                        <button
                          type="button"
                          phx-click="goto_address"
                          phx-value-address={row["bx_prev_address"]}
                          class="cursor-pointer text-left text-[#f7931a] hover:underline"
                          title={row["bx_prev_address"]}
                        >
                          <%= truncate_middle(row["bx_prev_address"], 16) %>
                        </button>
                      <% else %>
                        <%= row["kind"] %>
                      <% end %>
                    </td>
                    <td class="py-2"><%= row["bx_prev_value_sats"] %></td>
                    <td class="py-2"><%= row["bx_network"] %></td>
                    <td class="py-2"><%= row["bx_address_type"] %></td>
                    <td class="py-2"><%= row["bx_witness_version"] %></td>
                    <td class="py-2 break-all">
                      <%= row["bx_witness_program_hex"] || row["bx_payload_hex"] %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </section>

        <section class="rounded-2xl border border-zinc-800 bg-zinc-900 p-4">
          <h2 class="mb-3 text-lg font-medium">Outputs</h2>
          <div class="overflow-x-auto">
            <table class="w-full text-left text-xs">
              <thead class="text-zinc-500">
                <tr>
                  <th class="pb-2">Address</th>
                  <th class="pb-2">Value</th>
                  <th class="pb-2">Network</th>
                  <th class="pb-2">Type</th>
                  <th class="pb-2">Witness ver.</th>
                  <th class="pb-2">Program / payload</th>
                </tr>
              </thead>
              <tbody class="font-mono text-zinc-300">
                <%= for row <- @tx_enriched_vout do %>
                  <tr class="border-t border-zinc-800 align-top">
                    <td class="py-2">
                      <button
                        type="button"
                        phx-click="goto_address"
                        phx-value-address={row["scriptpubkey_address"]}
                        class="cursor-pointer text-left text-[#f7931a] hover:underline"
                        title={row["scriptpubkey_address"]}
                      >
                        <%= truncate_middle(row["scriptpubkey_address"] || "—", 16) %>
                      </button>
                    </td>
                    <td class="py-2"><%= row["value"] %></td>
                    <td class="py-2"><%= row["bx_network"] %></td>
                    <td class="py-2"><%= row["bx_address_type"] %></td>
                    <td class="py-2"><%= row["bx_witness_version"] %></td>
                    <td class="py-2 break-all">
                      <%= row["bx_witness_program_hex"] || row["bx_payload_hex"] %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </section>
      <% end %>
    </div>
    """
  end

  defp address_view(assigns) do
    ~H"""
    <div class="space-y-6">
      <p
        :if={@addr_error}
        class="rounded border border-orange-500/40 bg-orange-500/10 p-3 text-sm text-orange-300"
      >
        <%= @addr_error %>
      </p>

      <%= if @addr_info do %>
        <% info = @addr_info %>
        <% cs = Map.get(info, "chain_stats", %{}) %>
        <% ms = Map.get(info, "mempool_stats", %{}) %>
        <section class="rounded-2xl border border-zinc-800 bg-zinc-900 p-4 md:p-6">
          <div class="flex flex-col gap-4 md:flex-row md:items-start">
            <div class="flex-1">
              <h1 class="mb-2 break-all font-mono text-lg text-[#f7931a]"><%= @addr_string %></h1>
              <%= if @addr_decode do %>
                <dl class="mt-2 grid gap-2 text-sm md:grid-cols-2">
                  <.meta_row label="Network" value={@addr_decode.network} mono={false} link={nil} />
                  <.meta_row
                    label="Address type"
                    value={@addr_decode.address_type}
                    mono={false}
                    link={nil}
                  />
                  <.meta_row
                    label="Witness version"
                    value={to_string(@addr_decode.witness_version)}
                    mono={false}
                    link={nil}
                  />
                  <.meta_row
                    label="Witness program"
                    value={@addr_decode.witness_program_hex}
                    mono={true}
                    link={nil}
                  />
                </dl>
              <% end %>
            </div>
            <div
              id={"addr-qr-#{:erlang.phash2(@addr_string)}"}
              phx-hook="AddressQr"
              data-address={@addr_string}
              class="flex justify-center"
            >
            </div>
          </div>

          <dl class="mt-6 grid gap-3 border-t border-zinc-800 pt-4 text-sm md:grid-cols-2">
            <.meta_row
              label="Confirmed balance (sat)"
              value={balance_sat(cs)}
              mono={false}
              link={nil}
            />
            <.meta_row label="Unconfirmed (sat)" value={balance_sat(ms)} mono={false} link={nil} />
            <.meta_row
              label="Total received (sat)"
              value={to_string(Map.get(cs, "funded_txo_sum", 0))}
              mono={false}
              link={nil}
            />
            <.meta_row
              label="Total sent (sat)"
              value={to_string(Map.get(cs, "spent_txo_sum", 0))}
              mono={false}
              link={nil}
            />
            <.meta_row
              label="Tx count"
              value={to_string(Map.get(cs, "tx_count", 0))}
              mono={false}
              link={nil}
            />
          </dl>
        </section>

        <section class="rounded-2xl border border-zinc-800 bg-zinc-900 p-4">
          <h2 class="mb-3 text-lg font-medium">History</h2>
          <div class="overflow-x-auto">
            <table class="w-full text-left text-sm">
              <thead class="text-xs uppercase text-zinc-500">
                <tr>
                  <th class="pb-2">Tx</th>
                  <th class="pb-2">Height</th>
                  <th class="pb-2">Δ (sat)</th>
                  <th class="pb-2">Status</th>
                </tr>
              </thead>
              <tbody class="font-mono text-xs">
                <%= for tx <- @addr_txs do %>
                  <% st = Map.get(tx, "status", %{}) %>
                  <% net = address_net(tx, @addr_string) %>
                  <tr class="border-t border-zinc-800">
                    <td class="py-2">
                      <.link
                        navigate={~p"/tx/#{tx["txid"]}"}
                        class="text-[#f7931a]"
                        title={tx["txid"]}
                      >
                        <%= truncate_middle(tx["txid"], 14) %>
                      </.link>
                    </td>
                    <td class="py-2">
                      <%= if st["block_height"] do %>
                        <.link
                          navigate={~p"/block/#{st["block_hash"]}"}
                          class="text-zinc-300 hover:underline"
                        >
                          <%= st["block_height"] %>
                        </.link>
                      <% else %>
                        mempool
                      <% end %>
                    </td>
                    <td class={"py-2 #{if net >= 0, do: "text-emerald-400", else: "text-red-400"}"}>
                      <%= net %>
                    </td>
                    <td class="py-2">
                      <%= if(st["confirmed"], do: "confirmed", else: "unconfirmed") %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>

          <button
            :if={@addr_txs_has_more}
            type="button"
            phx-click="load_more_addr_txs"
            class="mt-4 rounded-lg border border-zinc-600 px-4 py-2 text-sm text-zinc-200 hover:bg-zinc-800"
          >
            Load more
          </button>
        </section>
      <% end %>
    </div>
    """
  end

  defp balance_sat(stats) do
    funded = Map.get(stats, "funded_txo_sum", 0)
    spent = Map.get(stats, "spent_txo_sum", 0)
    to_string(funded - spent)
  end

  defp address_net(tx, address) do
    vouts = Map.get(tx, "vout", []) || []

    recv =
      vouts
      |> Enum.filter(&(Map.get(&1, "scriptpubkey_address") == address))
      |> Enum.map(&Map.get(&1, "value", 0))
      |> Enum.sum()

    spent =
      (Map.get(tx, "vin", []) || [])
      |> Enum.map(&Map.get(&1, "prevout"))
      |> Enum.filter(&is_map/1)
      |> Enum.filter(&(Map.get(&1, "scriptpubkey_address") == address))
      |> Enum.map(&Map.get(&1, "value", 0))
      |> Enum.sum()

    recv - spent
  end

  defp sum_outputs(tx) do
    (Map.get(tx, "vout", []) || [])
    |> Enum.map(&Map.get(&1, "value", 0))
    |> Enum.sum()
  end

  defp fmt_btc(sats) when is_integer(sats) do
    :erlang.float_to_binary(sats / 100_000_000.0, decimals: 8)
  end

  defp fee_rate(tx) do
    fee = Map.get(tx, "fee", 0)
    vsize = Map.get(tx, "vsize") || max(div(Map.get(tx, "weight", 0) + 3, 4), 1)
    if vsize > 0, do: Float.round(fee / vsize, 2), else: 0.0
  end

  defp fee_at(fees, target) when is_map(fees) do
    key = Integer.to_string(target)
    Map.get(fees, key) || Map.get(fees, target)
  end

  defp fee_at(_, _), do: nil

  defp fmt_fee(nil), do: "—"
  defp fmt_fee(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 2)
  defp fmt_fee(n) when is_integer(n), do: Integer.to_string(n)

  defp fee_class(fee) when fee == nil, do: "text-zinc-400"
  defp fee_class(fee) when is_float(fee) and fee < 5.0, do: "text-emerald-400"
  defp fee_class(fee) when is_float(fee) and fee <= 50.0, do: "text-yellow-300"
  defp fee_class(fee) when is_float(fee), do: "text-red-400"
  defp fee_class(_), do: "text-zinc-300"

  defp format_kb(size) when is_integer(size), do: "#{Float.round(size / 1000, 2)} KB"
  defp format_kb(_), do: "—"

  defp format_vsize(v) when is_integer(v), do: "#{div(v, 1000)}k vB (approx)"
  defp format_vsize(_), do: "—"

  defp format_float(f) when is_float(f), do: :erlang.float_to_binary(f, decimals: 2)
  defp format_float(_), do: "—"

  defp truncate_middle(str, max) when is_binary(str) and byte_size(str) <= max, do: str

  defp truncate_middle(str, max) when is_binary(str) do
    left = div(max * 2, 3)
    right = max - left - 1
    String.slice(str, 0, left) <> "…" <> String.slice(str, -right, right)
  end

  defp fmt_rel(nil), do: "—"
  defp fmt_rel(ts), do: fmt_unix(ts)

  defp fmt_unix(ts) when is_integer(ts) do
    case DateTime.from_unix(ts) do
      {:ok, dt} -> Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
      _ -> Integer.to_string(ts)
    end
  end

  defp fmt_unix(_), do: "—"
end
