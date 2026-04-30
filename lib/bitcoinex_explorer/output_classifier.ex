defmodule BitcoinexExplorer.OutputClassifier do
  @moduledoc """
  Maps Esplora vout data + optional Bitcoinex decode into chart buckets.
  Chart keys: `p2pkh`, `p2sh`, `p2wpkh`, `p2wsh`, `p2tr`, `unknown`.
  """

  alias BitcoinexExplorer.Decode

  @chart_keys ~w(p2pkh p2sh p2wpkh p2wsh p2tr unknown)a

  def chart_keys, do: @chart_keys

  @spec bucket_from_vout(map()) :: atom()
  def bucket_from_vout(vout) when is_map(vout) do
    addr = Map.get(vout, "scriptpubkey_address")
    sp_type = Map.get(vout, "scriptpubkey_type")

    cond do
      is_binary(addr) and addr != "" ->
        case Decode.decode_address(addr) do
          {:ok, %{address_type: at}} ->
            bucket_from_address_type(at)

          _ ->
            from_esplora_type(sp_type)
        end

      true ->
        from_esplora_type(sp_type)
    end
  end

  defp from_esplora_type(t) when is_binary(t) do
    case t do
      "p2pkh" -> :p2pkh
      "p2sh" -> :p2sh
      "v0_p2wpkh" -> :p2wpkh
      "v0_p2wsh" -> :p2wsh
      "v1_p2tr" -> :p2tr
      _ -> :unknown
    end
  end

  defp from_esplora_type(_), do: :unknown

  defp bucket_from_address_type(at) when is_binary(at) do
    cond do
      String.contains?(at, "p2pkh") -> :p2pkh
      String.contains?(at, "p2sh") and not String.contains?(at, "p2w") -> :p2sh
      String.contains?(at, "p2wpkh") -> :p2wpkh
      String.contains?(at, "p2wsh") -> :p2wsh
      String.contains?(at, "p2tr") -> :p2tr
      true -> :unknown
    end
  end

  @doc "Zero counts map for all chart buckets (for assigns)."
  def empty_counts_map do
    Enum.reduce(@chart_keys, %{}, fn k, m -> Map.put(m, k, 0) end)
  end

  @spec counts_from_vouts(list()) :: %{atom() => non_neg_integer()}
  def counts_from_vouts(vouts) when is_list(vouts) do
    Enum.reduce(vouts, empty_counts_map(), fn vout, acc ->
      b = bucket_from_vout(vout)
      Map.update!(acc, b, &(&1 + 1))
    end)
  end

  @spec counts_to_chart_data(%{atom() => non_neg_integer()}) :: list(%{String.t() => term()})
  def counts_to_chart_data(counts) when is_map(counts) do
    labels = %{
      p2pkh: "P2PKH",
      p2sh: "P2SH",
      p2wpkh: "P2WPKH",
      p2wsh: "P2WSH",
      p2tr: "P2TR",
      unknown: "Unknown"
    }

    @chart_keys
    |> Enum.map(fn key ->
      %{
        "type" => Map.fetch!(labels, key),
        "key" => Atom.to_string(key),
        "count" => Map.get(counts, key, 0)
      }
    end)
    |> Enum.filter(fn %{"count" => c} -> c > 0 end)
  end
end
