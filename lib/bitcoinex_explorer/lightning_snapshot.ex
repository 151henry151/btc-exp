defmodule BitcoinexExplorer.LightningSnapshot do
  @moduledoc """
  Persists daily JSON snapshots of Lightning graph inputs for a future “past → present”
  animation (see `docs/lightning-graph-history.md`). Writes are best-effort and never
  fail the caller.
  """

  require Logger

  alias BitcoinexExplorer.LightningGraph

  @schema_version 1
  @retention_days 120

  @doc """
  Writes `snapshot-YYYY-MM-DD.json` when `:lightning_snapshot_dir` is configured.
  """
  @spec maybe_write(%{stats: term(), nodes: list(), edges: list()}) :: :ok
  def maybe_write(%{stats: stats, nodes: nodes, edges: edges}) do
    case Application.get_env(:bitcoinex_explorer, :lightning_snapshot_dir, :disabled) do
      :disabled ->
        :ok

      {:app_priv, parts} when is_list(parts) ->
        dir = Path.join([Application.app_dir(:bitcoinex_explorer) | parts])
        write_file(dir, stats, nodes, edges)

      {:absolute, path} when is_binary(path) ->
        write_file(path, stats, nodes, edges)

      path when is_binary(path) ->
        write_file(path, stats, nodes, edges)

      _ ->
        :ok
    end
  end

  defp write_file(dir, stats, nodes, edges) do
    File.mkdir_p!(dir)

    graph = LightningGraph.from_data(nodes, edges)

    utc_now = DateTime.utc_now() |> DateTime.truncate(:second)
    day = DateTime.to_date(utc_now)
    filename = "snapshot-#{Date.to_iso8601(day)}.json"
    path = Path.join(dir, filename)

    payload = %{
      schema_version: @schema_version,
      captured_at_utc: DateTime.to_iso8601(utc_now),
      stats_latest: stats,
      mempool_rankings_nodes: nodes,
      subgraph_edges: edges,
      graph_for_client: graph
    }

    File.write!(path, Jason.encode!(payload, pretty: true))
    prune_old(dir, @retention_days)
    :ok
  rescue
    e ->
      Logger.warning("LightningSnapshot: write skipped (#{Exception.message(e)})")
      :ok
  end

  defp prune_old(dir, keep_days) do
    cutoff = Date.add(Date.utc_today(), -keep_days)

    case File.ls(dir) do
      {:ok, names} ->
        Enum.each(names, fn name ->
          with [_, ymd] <- Regex.run(~r/^snapshot-(\d{4}-\d{2}-\d{2})\.json$/, name),
               {:ok, d} <- Date.from_iso8601(ymd),
               :lt <- Date.compare(d, cutoff) do
            _ = File.rm(Path.join(dir, name))
          else
            _ -> :ok
          end
        end)

      _ ->
        :ok
    end
  end
end
