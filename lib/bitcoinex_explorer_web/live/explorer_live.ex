defmodule BitcoinexExplorerWeb.ExplorerLive do
  use BitcoinexExplorerWeb, :live_view_root_only

  alias Bitcoinex.{Base58, PSBT, Segwit}
  alias Bitcoinex.LightningNetwork.Invoice
  alias Decimal

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, input: "", result: nil, error: nil)}
  end

  @impl true
  def handle_event("decode", %{"input" => input}, socket) do
    value = String.trim(input || "")

    if value == "" do
      {:noreply, assign(socket, input: "", result: nil, error: nil)}
    else
      case decode_auto(value) do
        {:ok, result} ->
          {:noreply, assign(socket, input: input, result: result, error: nil)}

        {:error, message} ->
          {:noreply, assign(socket, input: input, result: nil, error: message)}
      end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[#0f0f0f] text-zinc-100">
      <main class="mx-auto flex w-full max-w-5xl flex-col gap-6 px-4 py-8 md:px-6">
        <header class="space-y-2">
          <h1 class="text-3xl font-semibold tracking-tight text-[#f7931a]">Bitcoinex Explorer</h1>
        </header>

        <section class="rounded-2xl border border-zinc-800 bg-zinc-900 p-4 md:p-6">
          <form id="decode-form" phx-change="decode" class="space-y-3">
            <label class="text-sm font-medium text-zinc-300">Paste a Bitcoin address, BOLT11 Lightning invoice, or base64 PSBT</label>
            <textarea
              name="input"
              rows="5"
              phx-debounce="300"
              class="w-full rounded-xl border border-zinc-700 bg-zinc-950 p-3 font-mono text-sm leading-6 text-zinc-100 outline-none ring-[#f7931a] placeholder:text-zinc-500 focus:ring-1"
              placeholder="bc1q…, lnbc…, cHNidP8BA…"
            ><%= @input %></textarea>
          </form>

          <p :if={@error} class="mt-3 rounded-lg border border-orange-500/40 bg-orange-500/10 p-3 text-sm text-orange-300">
            <%= @error %>
          </p>

          <div :if={@result} class="mt-4 overflow-hidden rounded-xl border border-zinc-700">
            <dl class="divide-y divide-zinc-800">
              <%= for {key, value} <- rows_for_result(@result) do %>
                <div class="grid grid-cols-1 gap-1 p-3 md:grid-cols-[220px_1fr] md:gap-4">
                  <dt class="text-xs uppercase tracking-wide text-zinc-400"><%= key %></dt>
                  <dd class="break-all whitespace-pre-wrap font-mono text-sm text-zinc-100"><%= value %></dd>
                </div>
              <% end %>
            </dl>
          </div>
        </section>

        <footer class="mt-2 space-y-2 text-center text-xs text-zinc-500">
          <nav class="flex flex-wrap items-center justify-center gap-x-3 gap-y-1">
            <.link
              href="https://hromp.com/"
              class="text-zinc-400 underline-offset-2 hover:text-[#f7931a] hover:underline"
            >
              hromp.com
            </.link>
            <span class="text-zinc-600" aria-hidden="true">·</span>
            <.link
              href="https://hromp.com/bitcoinex-explorer/"
              class="text-zinc-400 underline-offset-2 hover:text-[#f7931a] hover:underline"
            >
              about
            </.link>
            <span class="text-zinc-600" aria-hidden="true">·</span>
            <.link
              href="https://github.com/151henry151/bitcoinex-explorer"
              class="text-zinc-400 underline-offset-2 hover:text-[#f7931a] hover:underline"
              target="_blank"
              rel="noopener noreferrer"
            >
              GitHub
            </.link>
          </nav>
          <p>
            Built with River Financial's Bitcoinex ·
            <a
              href="https://github.com/RiverFinancial/bitcoinex"
              class="text-zinc-400 underline-offset-2 hover:text-[#f7931a] hover:underline"
              target="_blank"
              rel="noopener noreferrer"
            >
              RiverFinancial/bitcoinex
            </a>
          </p>
        </footer>
      </main>
    </div>
    """
  end

  defp decode_auto(value) when is_binary(value) do
    trimmed = String.trim(value)
    compact_psbt = String.replace(trimmed, ~r/\s+/, "")

    cond do
      looks_like_bolt11?(trimmed) ->
        decode_invoice(trimmed)

      looks_like_psbt?(compact_psbt) ->
        decode_psbt(compact_psbt)

      true ->
        decode_address(trimmed)
    end
  end

  defp looks_like_bolt11?(s) when is_binary(s) do
    String.length(s) >= 6 and Regex.match?(~r/^ln[a-zA-Z0-9]/i, s)
  end

  defp looks_like_psbt?(compact) when is_binary(compact) do
    compact != "" and String.starts_with?(String.downcase(compact), "chnid")
  end

  defp decode_address(value) do
    case Segwit.decode_address(value) do
      {:ok, {network, witness_version, witness_program}} ->
        {:ok,
         %{
           tool: :address,
           input_type: "Bitcoin address",
           network: Atom.to_string(network),
           address_type: segwit_type(witness_version, witness_program),
           witness_version: witness_version,
           witness_program_hex: witness_program_hex(witness_program)
         }}

      {:error, reason} ->
        # Bech32/Bech32m (bc1… / tb1… / bcrt1…) never decode as Base58; surface Segwit errors clearly.
        if looks_like_bech32_address?(value) do
          {:error, segwit_error_message(reason)}
        else
          decode_legacy_address(value)
        end
    end
  end

  defp looks_like_bech32_address?(value) when is_binary(value) do
    v = String.downcase(value)
    String.starts_with?(v, "bc1") or String.starts_with?(v, "tb1") or String.starts_with?(v, "bcrt1")
  end

  defp segwit_error_message(:invalid_checksum) do
    "Not a valid Bech32 or Bech32m address: checksum verification failed. Check for typos, omitted characters, or a bad copy. Taproot mainnet addresses usually start with bc1p…"
  end

  defp segwit_error_message(:invalid_network) do
    "Unknown human-readable prefix for this Bech32 address (expected bc, tb, or bcrt for Bitcoin networks)."
  end

  defp segwit_error_message(:invalid_witness_version) do
    "Invalid witness version for this SegWit address encoding."
  end

  defp segwit_error_message(:invalid_program_length) do
    "Witness program length does not match rules for this witness version."
  end

  defp segwit_error_message(:empty_segwit_data) do
    "Decoded SegWit address data is empty or malformed."
  end

  defp segwit_error_message(other) do
    "Could not decode as a SegWit address: #{inspect(other)}"
  end

  defp decode_legacy_address(value) do
    case Base58.decode(value) do
      {:ok, <<prefix::8, payload::binary>>} ->
        {network, type} = legacy_prefix_info(prefix)

        {:ok,
         %{
           tool: :address,
           input_type: "Bitcoin address",
           network: network,
           address_type: type,
           witness_version: "n/a (legacy)",
           witness_program_hex: "n/a (legacy address detected)",
           payload_hex: Base.encode16(payload, case: :lower)
         }}

      _ ->
        {:error, "Unable to decode address. Check the address and try again."}
    end
  end

  defp decode_invoice(value) do
    case Invoice.decode(value) do
      {:ok, invoice} ->
        {:ok,
         %{
           tool: :invoice,
           input_type: "Lightning invoice (BOLT11)",
           network: Atom.to_string(invoice.network),
           amount_sat: format_invoice_sats(invoice.amount_msat),
           amount_btc: format_invoice_btc(invoice.amount_msat),
           description: invoice.description || "(none)",
           destination_pubkey: invoice.destination,
           expiry_seconds: invoice.expiry,
           timestamp: invoice.timestamp,
           payment_hash: invoice.payment_hash
         }}

      {:error, reason} ->
        {:error, "Unable to decode invoice: #{inspect(reason)}"}
    end
  end

  defp decode_psbt(value) do
    case PSBT.decode(value) do
      {:ok, psbt} ->
        inputs = psbt.global.unsigned_tx.inputs || []
        outputs = psbt.global.unsigned_tx.outputs || []

        {:ok,
         %{
           tool: :psbt,
           input_type: "PSBT",
           input_count: length(inputs),
           output_count: length(outputs),
           unsigned_tx_id:
             "Unsigned PSBTs don't have a valid txid until finalized",
           input_derivations: format_input_derivations(psbt.inputs || []),
           output_amounts: format_output_amounts(outputs)
         }}

      {:error, reason} ->
        {:error, "Unable to decode PSBT: #{inspect(reason)}"}
    end
  end

  defp rows_for_result(%{tool: :address} = result) do
    [
      {"Input type", Map.get(result, :input_type, "Bitcoin address")},
      {"Network", result.network},
      {"Address type", result.address_type},
      {"Witness version", result.witness_version},
      {"Witness program", result.witness_program_hex}
    ] ++ if(Map.has_key?(result, :payload_hex), do: [{"Payload", result.payload_hex}], else: [])
  end

  defp rows_for_result(%{tool: :invoice} = result) do
    [
      {"Input type", Map.get(result, :input_type, "Lightning invoice (BOLT11)")},
      {"Network", result.network},
      {"Amount (sats)", result.amount_sat},
      {"Amount (BTC)", result.amount_btc},
      {"Description", result.description},
      {"Destination pubkey", result.destination_pubkey},
      {"Expiry (seconds)", result.expiry_seconds},
      {"Timestamp", result.timestamp},
      {"Payment hash", result.payment_hash}
    ]
  end

  defp rows_for_result(%{tool: :psbt} = result) do
    [
      {"Input type", Map.get(result, :input_type, "PSBT")},
      {"Inputs", result.input_count},
      {"Outputs", result.output_count},
      {"Unsigned tx id", result.unsigned_tx_id},
      {"Input derivation paths", result.input_derivations},
      {"Output amounts (sats)", result.output_amounts}
    ]
  end

  defp segwit_type(0, program) when length(program) == 20, do: "p2wpkh"
  defp segwit_type(0, program) when length(program) == 32, do: "p2wsh"
  defp segwit_type(1, _), do: "p2tr"
  defp segwit_type(version, _), do: "segwit_v#{version}"

  defp witness_program_hex(program), do: program |> :binary.list_to_bin() |> Base.encode16(case: :lower)

  defp legacy_prefix_info(0x00), do: {"mainnet", "p2pkh (legacy address detected)"}
  defp legacy_prefix_info(0x05), do: {"mainnet", "p2sh (legacy address detected)"}
  defp legacy_prefix_info(0x6F), do: {"testnet/regtest", "p2pkh (legacy address detected)"}
  defp legacy_prefix_info(0xC4), do: {"testnet/regtest", "p2sh (legacy address detected)"}
  defp legacy_prefix_info(_), do: {"unknown", "base58 (legacy address detected)"}

  defp format_invoice_sats(nil), do: "n/a"

  defp format_invoice_sats(msat) when is_integer(msat) do
    whole = div(msat, 1000)
    rem_msat = rem(msat, 1000)

    if rem_msat == 0 do
      Integer.to_string(whole)
    else
      frac =
        rem_msat
        |> Integer.to_string()
        |> String.pad_leading(3, "0")
        |> String.trim_trailing("0")

      "#{whole}.#{frac}"
    end
  end

  defp format_invoice_btc(nil), do: "n/a"

  defp format_invoice_btc(msat) when is_integer(msat) do
    # BTC = msat / 100_000_000_000 (1000 msat/sat × 10^8 sat/BTC)
    msat
    |> Decimal.new()
    |> Decimal.div(Decimal.new(100_000_000_000))
    |> Decimal.round(11)
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
    |> trim_trailing_decimal_zeros()
  end

  defp trim_trailing_decimal_zeros(str) when is_binary(str) do
    if String.contains?(str, ".") do
      str
      |> String.trim_trailing("0")
      |> String.trim_trailing(".")
    else
      str
    end
  end

  defp format_input_derivations(inputs) do
    inputs
    |> Enum.with_index()
    |> Enum.map_join("\n", fn {input, idx} ->
      paths =
        (input.bip32_derivation || [])
        |> Enum.map_join(", ", fn derivation ->
          pubkey = Map.get(derivation, :public_key, "unknown_pubkey")
          path = Map.get(derivation, :derivation, []) |> format_derivation_path()
          "#{pubkey} -> #{path}"
        end)

      if paths == "", do: "input[#{idx}]: none", else: "input[#{idx}]: #{paths}"
    end)
  end

  defp format_derivation_path(path_indexes) do
    "m/" <>
      Enum.map_join(path_indexes, "/", fn idx ->
        if idx >= 0x80000000 do
          "#{idx - 0x80000000}'"
        else
          Integer.to_string(idx)
        end
      end)
  end

  defp format_output_amounts(outputs) do
    outputs
    |> Enum.with_index()
    |> Enum.map_join(", ", fn {output, idx} ->
      "out#{idx}=#{Map.get(output, :value, "unknown")}"
    end)
  end
end
