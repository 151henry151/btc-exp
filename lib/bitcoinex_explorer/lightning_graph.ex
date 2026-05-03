defmodule BitcoinexExplorer.LightningGraph do
  @moduledoc """
  Pure transforms for mempool.space Lightning liquidity rankings JSON.
  """

  alias Decimal, as: D

  @max_label_length 20

  @doc """
  Normalizes Lightning node pubkeys for stable matching (mempool APIs may mix case).
  """
  @spec normalize_public_key(String.t() | any()) :: String.t()
  def normalize_public_key(pk) when is_binary(pk), do: pk |> String.trim() |> String.downcase()
  def normalize_public_key(_), do: ""

  @spec from_nodes(list()) :: %{nodes: [map()]}
  def from_nodes(nodes) when is_list(nodes) do
    mapped =
      Enum.map(nodes, fn node ->
        pk = normalize_public_key(Map.get(node, "publicKey") || Map.get(node, :publicKey) || "")
        cap = Map.get(node, "capacity") || Map.get(node, :capacity) || 0

        label =
          case Map.get(node, "alias") || Map.get(node, :alias) do
            a when is_binary(a) ->
              a = String.trim(a)
              if a != "", do: truncate_label(a), else: pubkey_fallback(pk)

            _ ->
              pubkey_fallback(pk)
          end

        %{id: pk, label: label, capacity_sats: cap}
      end)

    sorted = Enum.sort_by(mapped, & &1.capacity_sats, :desc)
    %{nodes: sorted}
  end

  defp truncate_label(s) do
    if String.length(s) <= @max_label_length,
      do: s,
      else: String.slice(s, 0, @max_label_length)
  end

  defp pubkey_fallback(pk) when is_binary(pk) do
    if byte_size(pk) >= 8 do
      String.slice(pk, 0, 8) <> "…"
    else
      pk
    end
  end

  defp pubkey_fallback(_), do: "…"

  @spec from_data(list(), list()) :: %{nodes: [map()], edges: [map()]}
  def from_data(nodes, edges) when is_list(nodes) and is_list(edges) do
    %{nodes: sorted_nodes} = from_nodes(nodes)

    node_ids = MapSet.new(sorted_nodes, & &1.id)

    mapped_edges =
      edges
      |> Enum.map(&normalize_edge_endpoints/1)
      |> Enum.filter(fn e ->
        e.source != "" and e.target != "" and e.source != e.target and
          MapSet.member?(node_ids, e.source) and MapSet.member?(node_ids, e.target)
      end)

    %{nodes: sorted_nodes, edges: mapped_edges}
  end

  defp normalize_edge_endpoints(e) when is_map(e) do
    s =
      normalize_public_key(
        Map.get(e, :source) || Map.get(e, "source") || Map.get(e, :node1_public_key) ||
          Map.get(e, "node1_public_key") || ""
      )

    t =
      normalize_public_key(
        Map.get(e, :target) || Map.get(e, "target") || Map.get(e, :node2_public_key) ||
          Map.get(e, "node2_public_key") || ""
      )

    cap =
      Map.get(e, :capacity) || Map.get(e, "capacity") || Map.get(e, :capacity_sats) ||
        Map.get(e, "capacity_sats") || 0

    %{source: s, target: t, capacity_sats: cap}
  end

  @spec summary_stats(map()) :: %{
          node_count: integer(),
          channel_count: integer(),
          total_capacity_btc: String.t()
        }
  def summary_stats(stats) when is_map(stats) do
    row =
      case stats do
        %{"latest" => latest} when is_map(latest) -> latest
        %{latest: latest} when is_map(latest) -> latest
        other -> other
      end

    nodes = pick_int(row, ["nodeCount", "node_count", "nodes"])

    chans = pick_int(row, ["channelCount", "channel_count", "channels"])

    cap_sats = pick_int(row, ["totalCapacity", "total_capacity", "network_capacity"])

    btc_str =
      cap_sats
      |> D.new()
      |> D.div(D.new(100_000_000))
      |> D.round(2)
      |> D.to_string(:normal)

    %{node_count: nodes, channel_count: chans, total_capacity_btc: btc_str}
  end

  defp pick_int(m, keys) do
    Enum.find_value(keys, 0, fn k ->
      case Map.get(m, k) do
        n when is_integer(n) -> n
        _ -> nil
      end
    end)
  end
end
