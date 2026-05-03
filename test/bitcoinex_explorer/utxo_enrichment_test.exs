defmodule BitcoinexExplorer.UtxoEnrichmentTest do
  use ExUnit.Case, async: true

  alias BitcoinexExplorer.UtxoEnrichment

  @bc1q "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"

  @raw_utxos [
    %{
      "txid" => String.duplicate("a", 64),
      "vout" => 0,
      "status" => %{"confirmed" => true, "block_height" => 800_000},
      "value" => 100_000_000
    },
    %{
      "txid" => String.duplicate("b", 64),
      "vout" => 1,
      "status" => %{"confirmed" => false, "block_height" => nil},
      "value" => 546
    }
  ]

  test "enrich/2 annotates script_type for a P2WPKH address" do
    enriched = UtxoEnrichment.enrich(@raw_utxos, @bc1q)
    assert Enum.all?(enriched, &(&1[:script_type] == :p2wpkh))
  end

  test "enrich/2 sets :confirmed boolean from status" do
    [first, second] = UtxoEnrichment.enrich(@raw_utxos, @bc1q)
    assert first[:confirmed] == true
    assert second[:confirmed] == false
  end

  test "enrich/2 formats :value_btc to 8 decimal places with no scientific notation" do
    [first, _] = UtxoEnrichment.enrich(@raw_utxos, @bc1q)
    assert first[:value_btc] == "1.00000000"
  end

  test "enrich/2 with unknown address type yields :unknown without raising" do
    enriched = UtxoEnrichment.enrich(@raw_utxos, "not_an_address")
    assert Enum.all?(enriched, &(&1[:script_type] == :unknown))
  end

  test "total_value_sats/1 sums value fields" do
    assert UtxoEnrichment.total_value_sats(@raw_utxos) == 100_000_546
  end
end
