defmodule BitcoinexExplorer.LightningSnapshotTest do
  use ExUnit.Case, async: false

  alias BitcoinexExplorer.LightningSnapshot

  setup do
    dir = Path.join(System.tmp_dir!(), "lg-snap-#{System.unique_integer([:positive])}")
    Application.put_env(:bitcoinex_explorer, :lightning_snapshot_dir, {:absolute, dir})

    on_exit(fn ->
      _ = File.rm_rf(dir)
      Application.put_env(:bitcoinex_explorer, :lightning_snapshot_dir, :disabled)
    end)

    %{dir: dir}
  end

  test "writes daily JSON with graph_for_client", %{dir: dir} do
    stats = %{"latest" => %{"nodeCount" => 1, "channelCount" => 2, "totalCapacity" => 3}}

    nodes = [
      %{"publicKey" => "abc", "alias" => "A", "capacity" => 1_000_000},
      %{"publicKey" => "def", "alias" => "B", "capacity" => 500_000}
    ]

    edges = [
      %{source: "abc", target: "def", capacity: 100_000}
    ]

    assert :ok = LightningSnapshot.maybe_write(%{stats: stats, nodes: nodes, edges: edges})

    day = Date.utc_today() |> Date.to_iso8601()
    path = Path.join(dir, "snapshot-#{day}.json")
    assert File.exists?(path)

    decoded = path |> File.read!() |> Jason.decode!()
    assert decoded["schema_version"] == 1
    assert is_map(decoded["graph_for_client"])
    assert is_list(decoded["graph_for_client"]["nodes"])
  end
end
