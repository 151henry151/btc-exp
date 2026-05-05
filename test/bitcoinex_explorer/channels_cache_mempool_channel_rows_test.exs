defmodule BitcoinexExplorer.ChannelsCache.MempoolChannelRowsTest do
  use ExUnit.Case, async: true

  alias BitcoinexExplorer.ChannelsCache.MempoolChannelRows

  @pk_a String.duplicate("a", 66)
  @pk_b String.duplicate("b", 66)
  @pk_c String.duplicate("c", 66)

  test "edges_between_top_nodes uses node.public_key as peer for mempool channel rows" do
    top = MapSet.new([@pk_a, @pk_b])

    channels = [
      %{"capacity" => 1_000_000, "node" => %{"public_key" => @pk_b}}
    ]

    edges = MempoolChannelRows.edges_between_top_nodes(channels, @pk_a, top)
    assert length(edges) == 1
    e = hd(edges)
    assert e.source == @pk_a
    assert e.target == @pk_b
    assert e.capacity == 1_000_000
  end

  test "edges_between_top_nodes drops peer not in top set" do
    top = MapSet.new([@pk_a])

    channels = [
      %{"capacity" => 500, "node" => %{"public_key" => @pk_b}}
    ]

    assert MempoolChannelRows.edges_between_top_nodes(channels, @pk_a, top) == []
  end

  test "edges_between_top_nodes falls back to node1/node2 keys when node map absent" do
    top = MapSet.new([@pk_a, @pk_b])

    channels = [
      %{"capacity" => 99, "node1_public_key" => @pk_a, "node2_public_key" => @pk_b}
    ]

    edges = MempoolChannelRows.edges_between_top_nodes(channels, @pk_c, top)
    assert length(edges) == 1
    e = hd(edges)
    assert Enum.sort([e.source, e.target]) == Enum.sort([@pk_a, @pk_b])
  end
end
