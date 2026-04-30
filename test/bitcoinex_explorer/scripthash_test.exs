defmodule BitcoinexExplorer.ScripthashTest do
  use ExUnit.Case, async: true

  alias BitcoinexExplorer.Scripthash

  # Reference: SHA256(scriptPubKey) reversed — verified independently via `mix run`
  # (Electrum requires reversed byte order vs naive big-endian hex).
  @bc1q_xy2 "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
  @bc1q_xy2_expected "6200afd3fd0e459a3e2b92b0e4cf14bc7dbea02161fb8a76a4d44638b78e96ba"

  test "P2WPKH mainnet bc1q produces documented scripthash" do
    assert {:ok, sh} = Scripthash.from_address(@bc1q_xy2)
    assert sh == @bc1q_xy2_expected
    assert byte_size(sh) == 64
  end

  test "P2PKH mainnet, P2WSH mainnet, and taproot vectors decode (Bitcoinex-compatible)" do
    assert {:ok, p2pkh} = Scripthash.from_address("1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
    assert byte_size(p2pkh) == 64

    assert {:ok, p2wsh} =
             Scripthash.from_address(
               "bc1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3"
             )

    assert byte_size(p2wsh) == 64

    assert {:ok, p2tr} =
             Scripthash.from_address(
               "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0"
             )

    assert byte_size(p2tr) == 64
    assert p2pkh != p2wsh and p2wsh != p2tr
  end

  test "testnet P2WPKH returns hex scripthash" do
    assert {:ok, tb1} = Scripthash.from_address("tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx")
    assert byte_size(tb1) == 64
  end

  test "invalid address returns error" do
    assert {:error, _} = Scripthash.from_address("not_an_address")
  end
end
