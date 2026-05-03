defmodule BitcoinexExplorer.UtxoEnrichment do
  @moduledoc """
  Annotates raw Esplora UTXO maps with Bitcoinex-derived script type and
  formatted BTC values. Pure functions — no HTTP calls.
  """

  alias BitcoinexExplorer.Decode
  alias Decimal, as: D

  @spec enrich([map()], String.t()) :: [map()]
  def enrich(utxos, address) when is_list(utxos) do
    st = script_type_from_address(address)

    Enum.map(utxos, fn u ->
      enrich_one(u, st)
    end)
  end

  defp enrich_one(%{} = utxo, script_type) do
    val = value_to_sats_int(Map.get(utxo, "value"))
    status = Map.get(utxo, "status") || %{}

    btc_str =
      val
      |> D.new()
      |> D.div(D.new(100_000_000))
      |> D.round(8)
      |> D.to_string(:normal)

    utxo
    |> Map.put(:script_type, script_type)
    |> Map.put(:confirmed, Map.get(status, "confirmed") == true)
    |> Map.put(:block_height, Map.get(status, "block_height"))
    |> Map.put(:value_btc, btc_str)
    |> Map.put("value", val)
  end

  defp value_to_sats_int(v) when is_integer(v) and v >= 0, do: v

  defp value_to_sats_int(v) when is_float(v) and v >= 0 do
    v |> Float.round() |> trunc() |> max(0)
  end

  defp value_to_sats_int(v) when is_binary(v) do
    case Integer.parse(String.trim(v)) do
      {i, _} when i >= 0 -> i
      _ -> 0
    end
  end

  defp value_to_sats_int(_), do: 0

  defp script_type_from_address(addr) when is_binary(addr) do
    case Decode.decode_address(addr) do
      {:ok, %{address_type: at}} ->
        cond do
          String.contains?(at, "p2wpkh") -> :p2wpkh
          String.contains?(at, "p2wsh") -> :p2wsh
          String.contains?(at, "p2tr") -> :p2tr
          String.contains?(at, "p2pkh") -> :p2pkh
          String.contains?(at, "p2sh") -> :p2sh
          true -> :unknown
        end

      _ ->
        :unknown
    end
  end

  @spec total_value_sats([map()]) :: non_neg_integer()
  def total_value_sats(utxos) when is_list(utxos) do
    utxos
    |> Enum.map(fn u -> value_to_sats_int(Map.get(u, "value")) end)
    |> Enum.sum()
  end
end
