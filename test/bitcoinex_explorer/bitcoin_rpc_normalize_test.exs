defmodule BitcoinexExplorer.BitcoinRpcNormalizeTest do
  use ExUnit.Case, async: true

  alias BitcoinexExplorer.BitcoinRpcNormalize

  test "btc_to_sats converts float BTC to integer satoshis" do
    assert BitcoinRpcNormalize.btc_to_sats(1.0) == 100_000_000
    assert BitcoinRpcNormalize.btc_to_sats(0.00000001) == 1
  end

  test "mempool_from_core maps Core getmempoolinfo fields to Esplora-like keys" do
    raw = BitcoinexExplorerTest.Fixtures.read_json!("rpc/getmempoolinfo.json")
    m = BitcoinRpcNormalize.mempool_from_core(raw)
    assert m["count"] == 14208
    assert m["vsize"] == 8_837_058
    assert is_integer(m["total_fee"])
    assert m["total_fee"] == round(0.14283676 * 100_000_000)
  end

  test "fee_estimates_from_core converts BTC/kB to sat/vB" do
    raw = BitcoinexExplorerTest.Fixtures.read_json!("rpc/estimatesmartfee.json")
    out = BitcoinRpcNormalize.fee_estimates_from_core(%{"6" => raw})
    assert_in_delta Map.fetch!(out, "6"), 10.0, 0.001
  end

  test "fee_estimates_from_core drops non-positive feerate" do
    assert %{} ==
             BitcoinRpcNormalize.fee_estimates_from_core(%{"6" => %{"feerate" => -1}})
  end

  test "block_summary maps Core getblock verbosity 1 fields" do
    raw = BitcoinexExplorerTest.Fixtures.read_json!("rpc/getblock_v1.json")
    s = BitcoinRpcNormalize.block_summary(raw)
    assert s["id"] == raw["hash"]
    assert s["height"] == raw["height"]
    assert s["timestamp"] == raw["time"]
    assert s["tx_count"] == raw["nTx"]
    assert s["size"] == raw["size"]
    assert s["weight"] == raw["weight"]
  end

  test "tx_from_core builds Esplora-shaped vin/vout for coinbase + fee field" do
    decoded = %{
      "txid" => "aa" <> String.duplicate("0", 62),
      "version" => 2,
      "locktime" => 0,
      "size" => 220,
      "weight" => 880,
      "vsize" => 220,
      "fee" => 1.2e-6,
      "vin" => [
        %{
          "coinbase" => "030fff",
          "sequence" => 4_294_967_295
        }
      ],
      "vout" => [
        %{
          "value" => 6.25,
          "n" => 0,
          "scriptPubKey" => %{
            "hex" => "76a914",
            "type" => "pubkeyhash",
            "address" => "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
          }
        }
      ],
      "confirmations" => 1,
      "blockheight" => 900_000,
      "blockhash" => "bb" <> String.duplicate("0", 62)
    }

    tx = BitcoinRpcNormalize.tx_from_core(decoded, %{}, %{})
    assert tx["fee"] == BitcoinRpcNormalize.btc_to_sats(1.2e-6)
    assert [vin] = tx["vin"]
    assert vin["is_coinbase"] == true
    assert [vout] = tx["vout"]
    assert vout["scriptpubkey_type"] == "p2pkh"
    assert vout["value"] == BitcoinRpcNormalize.btc_to_sats(6.25)
    BitcoinexExplorerTest.DataShapes.assert_tx_shape(tx)
  end
end
