defmodule BitcoinexExplorer.OutputClassifierTest do
  use ExUnit.Case, async: true

  alias BitcoinexExplorer.OutputClassifier

  test "bucket_from_vout maps Esplora op_return when there is no address" do
    vout = %{"scriptpubkey_type" => "op_return", "value" => 0}
    assert OutputClassifier.bucket_from_vout(vout) == :op_return
  end

  test "empty_counts_map includes op_return" do
    m = OutputClassifier.empty_counts_map()
    assert Map.has_key?(m, :op_return)
    assert Map.get(m, :op_return) == 0
  end

  test "counts_from_vouts increments op_return bucket" do
    vouts = [
      %{"scriptpubkey_type" => "op_return", "value" => 0},
      %{"scriptpubkey_type" => "op_return", "value" => 0},
      %{"scriptpubkey_address" => "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4", "value" => 1000}
    ]

    counts = OutputClassifier.counts_from_vouts(vouts)

    assert counts[:op_return] == 2
    assert counts[:p2wpkh] == 1
  end

  test "counts_to_chart_data labels op_return" do
    counts =
      OutputClassifier.empty_counts_map()
      |> Map.put(:op_return, 1)

    data = OutputClassifier.counts_to_chart_data(counts)

    assert [%{"key" => "op_return", "type" => "OP_RETURN", "count" => 1}] == data
  end
end
