defmodule BitcoinexExplorer.SearchTest do
  use ExUnit.Case, async: true

  alias BitcoinexExplorer.Search

  test "classifies BOLT11 prefix" do
    assert {:bolt11, "lnbc1pw"} = Search.classify(" lnbc1pw")
  end

  test "classifies PSBT base64 magic line" do
    {:psbt, s} = Search.classify(" cHNidP8BA ")
    assert String.replace(s, ~r/\s+/, "") =~ ~r/^cHNid/i
  end

  test "classifies height as integer string" do
    assert {:block_height, 820_000} = Search.classify("820000")
  end

  test "classifies 64-char hex" do
    h = String.duplicate("a", 64)
    assert {:hex64, _} = Search.classify(h)
  end

  test "classifies valid bc1 address" do
    addr = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"
    assert {:address, ^addr} = Search.classify(addr)
  end
end
