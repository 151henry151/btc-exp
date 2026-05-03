defmodule BitcoinexExplorer.ChannelsCache do
  @moduledoc """
  Short-lived cache for mempool.space Lightning JSON (topology page).
  """

  use GenServer

  alias Tesla.Env

  @ttl_ms 10 * 60 * 1000

  def start_link(opts),
    do: GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))

  def get, do: GenServer.call(__MODULE__, :get)

  @impl true
  def init(:ok), do: {:ok, %{data: nil, fetched_at: nil, error: nil}, {:continue, :fetch}}

  @impl true
  def handle_continue(:fetch, state) do
    case fetch_both() do
      {:ok, data} ->
        now = System.monotonic_time(:millisecond)
        {:noreply, %{state | data: data, fetched_at: now, error: nil}}

      {:error, reason} ->
        {:noreply, %{state | error: reason}}
    end
  end

  @impl true
  def handle_call(:get, _from, %{data: nil, error: err} = state) when not is_nil(err) do
    {:reply, {:error, err}, state}
  end

  def handle_call(:get, _from, %{data: nil} = state) do
    {:reply, :loading, state}
  end

  def handle_call(:get, _from, %{data: data, fetched_at: at} = state) when not is_nil(data) do
    now = System.monotonic_time(:millisecond)

    if at != nil and now - at > @ttl_ms do
      send(self(), :refresh)
    end

    {:reply, {:ok, data}, state}
  end

  @impl true
  def handle_info(:refresh, state) do
    case fetch_both() do
      {:ok, data} ->
        now = System.monotonic_time(:millisecond)
        {:noreply, %{state | data: data, fetched_at: now, error: nil}}

      {:error, reason} ->
        {:noreply, %{state | error: reason}}
    end
  end

  defp build_client(base) do
    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, base},
        Tesla.Middleware.JSON
      ],
      Tesla.Adapter.Hackney
    )
  end

  defp fetch_both do
    base = Application.fetch_env!(:bitcoinex_explorer, :mempool_base_url)
    client = build_client(base)

    with {:ok, %Env{status: 200, body: stats}} <-
           Tesla.get(client, "/api/v1/lightning/statistics/latest"),
         {:ok, %Env{status: 200, body: nodes_raw}} <-
           Tesla.get(client, "/api/v1/lightning/nodes/rankings/liquidity", query: [limit: 100]) do
      nodes = List.wrap(nodes_raw)

      top_pubkeys =
        nodes
        |> Enum.map(&(Map.get(&1, "publicKey") || ""))
        |> MapSet.new()

      edges = fetch_edges(nodes, client, top_pubkeys)

      {:ok, %{stats: stats, nodes: nodes, edges: edges}}
    else
      {:ok, %Env{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:transport, reason}}

      _ ->
        {:error, :unexpected}
    end
  end

  defp fetch_edges(nodes, client, top_pubkeys) do
    nodes
    |> Task.async_stream(
      fn node ->
        pk = Map.get(node, "publicKey") || ""

        case Tesla.get(client, "/api/v1/lightning/nodes/#{pk}/channels", query: [status: "open"]) do
          {:ok, %Env{status: 200, body: body}} ->
            channels = Map.get(body, "channels") || List.wrap(body)
            extract_edges(channels, top_pubkeys)

          _ ->
            []
        end
      end,
      max_concurrency: 10,
      timeout: 15_000,
      on_timeout: :kill_task
    )
    |> Enum.flat_map(fn
      {:ok, edges} -> edges
      _ -> []
    end)
    |> deduplicate_edges()
  end

  defp extract_edges(channels, top_pubkeys) when is_list(channels) do
    Enum.flat_map(channels, fn ch ->
      n1 = Map.get(ch, "node1_public_key") || Map.get(ch, "node1PublicKey") || ""
      n2 = Map.get(ch, "node2_public_key") || Map.get(ch, "node2PublicKey") || ""
      cap = Map.get(ch, "capacity") || 0

      if MapSet.member?(top_pubkeys, n1) and MapSet.member?(top_pubkeys, n2) and n1 != n2 do
        [a, b] = Enum.sort([n1, n2])
        [%{source: a, target: b, capacity: cap}]
      else
        []
      end
    end)
  end

  defp extract_edges(_, _), do: []

  defp deduplicate_edges(edges) do
    edges
    |> Enum.uniq_by(fn e -> {e.source, e.target} end)
    |> Enum.sort_by(& &1.capacity, :desc)
    |> Enum.take(400)
  end
end
