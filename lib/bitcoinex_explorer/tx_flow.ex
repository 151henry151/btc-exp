defmodule BitcoinexExplorer.TxFlow do
  @moduledoc """
  Build JSON for the TxFlowGraph D3 hook from an Esplora tx map.
  """

  alias BitcoinexExplorer.OutputClassifier

  @spec encode(map()) :: String.t()
  def encode(tx) when is_map(tx) do
    %{inputs: input_nodes(tx), outputs: output_nodes(tx)}
    |> Jason.encode!()
  end

  defp input_nodes(tx) do
    Enum.map(Map.get(tx, "vin", []) || [], fn vin ->
      if Map.get(vin, "is_coinbase") == true do
        %{
          "address" => "Coinbase",
          "value_sats" => 0,
          "type" => "coinbase"
        }
      else
        prev = Map.get(vin, "prevout") || %{}
        addr = Map.get(prev, "scriptpubkey_address") || "non-standard"
        val = Map.get(prev, "value") || 0

        type =
          OutputClassifier.bucket_from_vout(%{
            "scriptpubkey_address" => addr,
            "scriptpubkey_type" => Map.get(prev, "scriptpubkey_type")
          })
          |> Atom.to_string()

        %{"address" => addr, "value_sats" => val, "type" => type}
      end
    end)
  end

  defp output_nodes(tx) do
    Enum.map(Map.get(tx, "vout", []) || [], fn vout ->
      addr = Map.get(vout, "scriptpubkey_address") || "non-standard"
      val = Map.get(vout, "value") || 0

      type =
        OutputClassifier.bucket_from_vout(vout)
        |> Atom.to_string()

      %{"address" => addr, "value_sats" => val, "type" => type}
    end)
  end
end
