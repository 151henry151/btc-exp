defmodule BitcoinexExplorer.Esplora do
  @moduledoc """
  Esplora-compatible HTTP API (defaults to Blockstream public API).
  All functions return `{:ok, term()} | {:error, term()}`.

  Implements `BitcoinexExplorer.DataSource`; LiveView should call `DataSource.impl()` rather than this module directly.
  """

  @behaviour BitcoinexExplorer.DataSource

  alias Tesla.Env

  @timeout 5_000

  defp client_json do
    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, base_url()},
        {Tesla.Middleware.Timeout, timeout: @timeout},
        Tesla.Middleware.JSON
      ],
      Tesla.Adapter.Hackney
    )
  end

  defp client_raw do
    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, base_url()},
        {Tesla.Middleware.Timeout, timeout: @timeout}
      ],
      Tesla.Adapter.Hackney
    )
  end

  defp base_url do
    Application.fetch_env!(:bitcoinex_explorer, :esplora_base_url)
  end

  defp run_esplora_http(fun) when is_function(fun, 0) do
    BitcoinexExplorer.EsploraHttpGate.run(fun)
  end

  defp esplora_http_max_attempts do
    Application.get_env(:bitcoinex_explorer, :esplora_http_max_attempts, 2)
  end

  defp esplora_429_retry_delay_ms do
    Application.get_env(:bitcoinex_explorer, :esplora_429_retry_delay_ms, 2_000)
  end

  defp get_json(path) do
    run_esplora_http(fn -> fetch_json_with_retries(path, 1) end)
  end

  defp get_raw(path) do
    run_esplora_http(fn -> fetch_raw_with_retries(path, 1) end)
  end

  defp fetch_json_with_retries(path, attempt) do
    case do_get_json_once(path) do
      {:error, {:http_error, 429, _body}} = err ->
        if attempt < esplora_http_max_attempts() do
          Process.sleep(esplora_429_retry_delay_ms())
          fetch_json_with_retries(path, attempt + 1)
        else
          err
        end

      other ->
        other
    end
  end

  defp fetch_raw_with_retries(path, attempt) do
    case do_get_raw_once(path) do
      {:error, {:http_error, 429, _body}} = err ->
        if attempt < esplora_http_max_attempts() do
          Process.sleep(esplora_429_retry_delay_ms())
          fetch_raw_with_retries(path, attempt + 1)
        else
          err
        end

      other ->
        other
    end
  end

  defp do_get_json_once(path) do
    case Tesla.get(client_json(), path) do
      {:ok, %Env{status: 200, body: body}} when is_map(body) or is_list(body) ->
        {:ok, body}

      {:ok, %Env{status: 404}} ->
        {:error, :not_found}

      {:ok, %Env{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  defp do_get_raw_once(path) do
    case Tesla.get(client_raw(), path) do
      {:ok, %Env{status: 200, body: body}} when is_binary(body) ->
        {:ok, body}

      {:ok, %Env{status: 404}} ->
        {:error, :not_found}

      {:ok, %Env{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  @spec blocks() :: {:ok, list()} | {:error, term()}
  def blocks, do: get_json("/blocks")

  @doc """
  Fetches up to `limit` recent blocks by paging `GET /blocks` then `GET /blocks/<height>` (Esplora returns 10 per page).
  On a partial failure after some pages succeeded, returns `{:ok, accumulated}`.
  """
  @spec recent_blocks(pos_integer()) :: {:ok, list()} | {:error, term()}
  def recent_blocks(limit \\ 100) when is_integer(limit) and limit > 0 do
    BitcoinexExplorer.EsploraCache.get_or_fetch({:recent_blocks, limit}, fn ->
      recent_blocks_uncached(limit)
    end)
  end

  defp recent_blocks_uncached(limit) do
    case blocks() do
      {:ok, batch} when is_list(batch) and batch != [] ->
        fetch_more_recent_batches(batch, limit, 0)

      {:ok, []} ->
        {:ok, []}

      err ->
        err
    end
  end

  defp fetch_more_recent_batches(acc, limit, _depth) when length(acc) >= limit do
    {:ok, Enum.take(acc, limit)}
  end

  defp fetch_more_recent_batches(acc, _limit, depth) when depth >= 30 do
    {:ok, acc}
  end

  defp fetch_more_recent_batches(acc, limit, depth) do
    last = List.last(acc)
    next_start = Map.get(last, "height", 0) - 1

    if next_start < 0 do
      {:ok, acc}
    else
      case get_json("/blocks/#{next_start}") do
        {:ok, batch} when is_list(batch) and batch != [] ->
          fetch_more_recent_batches(acc ++ batch, limit, depth + 1)

        {:ok, _} ->
          {:ok, acc}

        {:error, _} ->
          if acc == [], do: {:error, :not_found}, else: {:ok, acc}
      end
    end
  end

  @spec block(binary()) :: {:ok, map()} | {:error, term()}
  def block(hash) when is_binary(hash), do: get_json("/block/#{hash}")

  @spec block_txs(binary(), non_neg_integer()) :: {:ok, list()} | {:error, term()}
  def block_txs(hash, start_index \\ 0)
      when is_binary(hash) and is_integer(start_index) and start_index >= 0 do
    path =
      if start_index == 0 do
        "/block/#{hash}/txs"
      else
        "/block/#{hash}/txs/#{start_index}"
      end

    get_json(path)
  end

  @spec block_hash_at_height(integer()) :: {:ok, binary()} | {:error, term()}
  def block_hash_at_height(height) when is_integer(height) and height >= 0 do
    case get_raw("/block-height/#{height}") do
      {:ok, body} ->
        hash = String.trim(body)

        if Regex.match?(~r/^[0-9a-f]{64}$/i, hash) do
          {:ok, String.downcase(hash)}
        else
          {:error, :invalid_response}
        end

      err ->
        err
    end
  end

  @spec transaction(binary()) :: {:ok, map()} | {:error, term()}
  def transaction(txid) when is_binary(txid), do: get_json("/tx/#{txid}")

  @spec address(binary()) :: {:ok, map()} | {:error, term()}
  def address(addr) when is_binary(addr), do: get_json("/address/#{addr}")

  @spec address_txs(binary(), binary() | nil) :: {:ok, list()} | {:error, term()}
  def address_txs(addr, last_seen_txid \\ nil)

  def address_txs(addr, nil) when is_binary(addr) do
    get_json("/address/#{addr}/txs")
  end

  def address_txs(addr, last_seen_txid) when is_binary(addr) and is_binary(last_seen_txid) do
    get_json("/address/#{addr}/txs/chain/#{last_seen_txid}")
  end

  @spec mempool() :: {:ok, map()} | {:error, term()}
  def mempool do
    BitcoinexExplorer.EsploraCache.get_or_fetch(:mempool, fn -> get_json("/mempool") end)
  end

  @spec fee_estimates() :: {:ok, map()} | {:error, term()}
  def fee_estimates do
    BitcoinexExplorer.EsploraCache.get_or_fetch(:fee_estimates, fn ->
      get_json("/fee-estimates")
    end)
  end

  # ——— DataSource callbacks ———

  @impl true
  def get_recent_blocks(count), do: recent_blocks(count)

  @impl true
  def get_block(hash), do: block(hash)

  @impl true
  def get_block_by_height(height) when is_integer(height) and height >= 0 do
    case block_hash_at_height(height) do
      {:ok, hash} -> block(hash)
      err -> err
    end
  end

  @impl true
  def get_block_hash_at_height(height), do: block_hash_at_height(height)

  @impl true
  def get_block_txs(hash, start_index), do: block_txs(hash, start_index)

  @impl true
  def get_tx(txid), do: transaction(txid)

  @impl true
  def get_address(addr), do: address(addr)

  @impl true
  def get_address_txs(addr, last_seen_txid), do: address_txs(addr, last_seen_txid)

  @impl true
  def get_mempool(), do: mempool()

  @impl true
  def get_fee_estimates(), do: fee_estimates()

  @impl true
  def mempool_recent(), do: get_json("/mempool/recent")

  @impl true
  def address_utxos(addr) when is_binary(addr) do
    enc = URI.encode(addr, &URI.char_unreserved?/1)
    # Bypass EsploraHttpGate — called from assign_async, not the dashboard pipeline.
    fetch_json_with_retries("/address/#{enc}/utxo", 1)
  end
end
