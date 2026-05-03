defmodule BitcoinexExplorer.LightningGraphTest do
  use ExUnit.Case, async: true

  alias BitcoinexExplorer.LightningGraph

  @nodes [
    %{"publicKey" => String.duplicate("a", 66), "alias" => "ACINQ", "capacity" => 500_000_000},
    %{"publicKey" => String.duplicate("b", 66), "alias" => "", "capacity" => 100_000_000},
    %{
      "publicKey" => String.duplicate("c", 66),
      "alias" => String.duplicate("x", 30),
      "capacity" => 10_000_000
    }
  ]

  @stats %{"nodeCount" => 15000, "channelCount" => 60000, "totalCapacity" => 5_000_000_000}

  test "from_nodes/1 returns a map with :nodes key" do
    result = LightningGraph.from_nodes(@nodes)
    assert is_map(result)
    assert Map.has_key?(result, :nodes)
  end

  test "from_nodes/1 each node has :id, :label, :capacity_sats" do
    %{nodes: nodes} = LightningGraph.from_nodes(@nodes)

    for node <- nodes do
      assert Map.has_key?(node, :id)
      assert Map.has_key?(node, :label)
      assert Map.has_key?(node, :capacity_sats)
      assert is_binary(node.label)
      assert is_integer(node.capacity_sats)
    end
  end

  test "from_nodes/1 label is truncated to 20 chars" do
    %{nodes: nodes} = LightningGraph.from_nodes(@nodes)
    assert Enum.all?(nodes, &(String.length(&1.label) <= 20))
  end

  test "from_nodes/1 blank alias falls back to truncated pubkey with ellipsis" do
    %{nodes: nodes} = LightningGraph.from_nodes(@nodes)

    blank_alias_node = Enum.find(nodes, &String.starts_with?(&1.id, String.duplicate("b", 66)))

    assert blank_alias_node.label =~ "…"
    assert String.length(blank_alias_node.label) <= 10
  end

  test "from_nodes/1 nodes are sorted descending by capacity_sats" do
    %{nodes: nodes} = LightningGraph.from_nodes(@nodes)
    capacities = Enum.map(nodes, & &1.capacity_sats)
    assert capacities == Enum.sort(capacities, :desc)
  end

  test "summary_stats/1 returns node_count, channel_count, total_capacity_btc" do
    stats = LightningGraph.summary_stats(@stats)
    assert stats.node_count == 15000
    assert stats.channel_count == 60000
    assert is_binary(stats.total_capacity_btc)
    refute stats.total_capacity_btc =~ "e"
    assert stats.total_capacity_btc =~ "."
  end

  test "summary_stats/1 reads node_count, channel_count, and total_capacity from latest" do
    wrapped = %{
      "latest" => %{
        "node_count" => 17_372,
        "channel_count" => 42_027,
        "total_capacity" => 570_487_278_724
      }
    }

    s = LightningGraph.summary_stats(wrapped)
    assert s.node_count == 17_372
    assert s.channel_count == 42_027
    assert s.total_capacity_btc =~ "."
  end
end
