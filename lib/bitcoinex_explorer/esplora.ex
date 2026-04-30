defmodule BitcoinexExplorer.Esplora do
  @moduledoc """
  Esplora-compatible HTTP API (defaults to Blockstream public API).
  All functions return `{:ok, term()} | {:error, term()}`.
  """

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

  defp get_json(path) do
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

  defp get_raw(path) do
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
  def mempool, do: get_json("/mempool")

  @spec fee_estimates() :: {:ok, map()} | {:error, term()}
  def fee_estimates, do: get_json("/fee-estimates")

  @spec mempool_recent() :: {:ok, list()} | {:error, term()}
  def mempool_recent, do: get_json("/mempool/recent")
end
