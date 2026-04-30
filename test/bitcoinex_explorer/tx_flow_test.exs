defmodule BitcoinexExplorer.TxFlowTest do
  use ExUnit.Case, async: true

  alias BitcoinexExplorer.TxFlow

  test "encode marks OP_RETURN outputs with label and type op_return" do
    tx = %{
      "vin" => [%{"is_coinbase" => true}],
      "vout" => [
        %{
          "scriptpubkey_address" => "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
          "scriptpubkey_type" => "v0_p2wpkh",
          "value" => 319_262_062
        },
        %{"scriptpubkey_type" => "op_return", "value" => 0},
        %{"scriptpubkey_type" => "op_return", "value" => 0}
      ]
    }

    assert {:ok, decoded} = Jason.decode(TxFlow.encode(tx))

    outs = decoded["outputs"]
    assert Enum.at(outs, 0)["address"] =~ "bc1"
    assert Enum.at(outs, 0)["type"] == "p2wpkh"

    assert Enum.at(outs, 1)["address"] == "OP_RETURN"
    assert Enum.at(outs, 1)["type"] == "op_return"
    assert Enum.at(outs, 1)["value_sats"] == 0

    assert Enum.at(outs, 2)["address"] == "OP_RETURN"
    assert Enum.at(outs, 2)["type"] == "op_return"
  end
end
