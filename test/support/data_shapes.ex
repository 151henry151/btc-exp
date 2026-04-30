defmodule BitcoinexExplorerTest.DataShapes do
  @moduledoc """
  Shared shape assertions so Esplora maps and RPC-normalized maps stay interchangeable.
  """

  import ExUnit.Assertions

  @tx_keys ~w(txid version locktime size weight fee vin vout status)
  @block_keys ~w(id height timestamp tx_count size weight)
  @addr_keys ~w(chain_stats mempool_stats)
  @mempool_keys ~w(count vsize total_fee)

  def assert_tx_shape(tx) when is_map(tx) do
    for k <- @tx_keys do
      assert Map.has_key?(tx, k), "tx missing #{k}, got #{inspect(Map.keys(tx))}"
    end
  end

  def assert_block_summary_shape(b) when is_map(b) do
    for k <- @block_keys do
      assert Map.has_key?(b, k), "block summary missing #{k}"
    end
  end

  def assert_address_info_shape(a) when is_map(a) do
    for k <- @addr_keys do
      assert Map.has_key?(a, k), "address info missing #{k}"
    end

    cs = a["chain_stats"]
    assert is_map(cs)
    assert Map.has_key?(cs, "funded_txo_sum")
    assert Map.has_key?(cs, "spent_txo_sum")
    assert Map.has_key?(cs, "tx_count")
  end

  def assert_mempool_shape(m) when is_map(m) do
    for k <- @mempool_keys do
      assert Map.has_key?(m, k), "mempool missing #{k}"
    end
  end

  @doc """
  Assert both maps have identical key sets (top-level); nested keys checked separately where needed.
  """
  def assert_same_keys(a, b) when is_map(a) and is_map(b) do
    ka = a |> Map.keys() |> MapSet.new()
    kb = b |> Map.keys() |> MapSet.new()

    assert ka == kb,
           "key mismatch: only a #{inspect(MapSet.difference(ka, kb))} only b #{inspect(MapSet.difference(kb, ka))}"
  end
end
