defmodule BitcoinexExplorer.ChannelsCache do
  @moduledoc """
  Short-lived cache for mempool.space Lightning JSON (topology page).
  """

  use GenServer

  alias Tesla.Env

  alias BitcoinexExplorer.LightningGraph
  alias BitcoinexExplorer.LightningSnapshot

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
        :ok = LightningSnapshot.maybe_write(data)
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
        :ok = LightningSnapshot.maybe_write(data)
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
        |> Enum.map(&LightningGraph.normalize_public_key(Map.get(&1, "publicKey") || ""))
        |> Enum.reject(&(&1 == ""))
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
        pk = LightningGraph.normalize_public_key(Map.get(node, "publicKey") || "")

        if pk == "" do
          []
        else
          # mempool.space: GET /api/v1/lightning/channels?public_key=...&status=open
          # (path /nodes/{pubkey}/channels returns 404). Response is a JSON array; each
          # item has "node" => %{"public_key" => peer} (counterparty). Paginate with index.
          channels = fetch_open_channels_pages(client, pk, 5)

          __MODULE__.MempoolChannelRows.edges_between_top_nodes(channels, pk, top_pubkeys)
        end
      end,
      max_concurrency: 10,
      timeout: 30_000,
      on_timeout: :kill_task
    )
    |> Enum.flat_map(fn
      {:ok, edges} -> edges
      _ -> []
    end)
    |> deduplicate_edges()
  end

  defp fetch_open_channels_pages(client, pubkey, max_pages) do
    0..(max_pages - 1)
    |> Enum.reduce_while([], fn page, acc ->
      query =
        [public_key: pubkey, status: "open"] ++
          if(page == 0, do: [], else: [index: page * 10])

      case Tesla.get(client, "/api/v1/lightning/channels", query: query) do
        {:ok, %Env{status: 200, body: body}} when is_list(body) ->
          if body == [] do
            {:halt, acc}
          else
            new_acc = acc ++ body

            if length(body) < 10 or page == max_pages - 1 do
              {:halt, new_acc}
            else
              {:cont, new_acc}
            end
          end

        _ ->
          {:halt, acc}
      end
    end)
  end

  defp deduplicate_edges(edges) do
    edges
    |> Enum.uniq_by(fn e -> {e.source, e.target} end)
    |> Enum.sort_by(& &1.capacity, :desc)
    |> Enum.take(400)
  end

  defmodule MempoolChannelRows do
    @moduledoc false

    alias BitcoinexExplorer.LightningGraph

    @spec edges_between_top_nodes(list(), String.t(), MapSet.t()) ::
            list(%{source: String.t(), target: String.t(), capacity: term()})
    def edges_between_top_nodes(channels, local_pk, top_pubkeys) when is_list(channels) do
      Enum.flat_map(channels, fn ch ->
        {n1, n2, cap} = channel_endpoints(ch, local_pk)

        if MapSet.member?(top_pubkeys, n1) and MapSet.member?(top_pubkeys, n2) and n1 != n2 do
          [a, b] = Enum.sort([n1, n2])
          [%{source: a, target: b, capacity: cap}]
        else
          []
        end
      end)
    end

    def edges_between_top_nodes(_, _, _), do: []

    defp channel_endpoints(ch, local_pk) do
      cap = Map.get(ch, "capacity") || 0

      case Map.get(ch, "node") do
        %{"public_key" => peer} when is_binary(peer) ->
          a = LightningGraph.normalize_public_key(local_pk)
          b = LightningGraph.normalize_public_key(peer)
          {a, b, cap}

        %{public_key: peer} when is_binary(peer) ->
          a = LightningGraph.normalize_public_key(local_pk)
          b = LightningGraph.normalize_public_key(peer)
          {a, b, cap}

        _ ->
          n1 =
            LightningGraph.normalize_public_key(
              Map.get(ch, "node1_public_key") || Map.get(ch, "node1PublicKey") || ""
            )

          n2 =
            LightningGraph.normalize_public_key(
              Map.get(ch, "node2_public_key") || Map.get(ch, "node2PublicKey") || ""
            )

          {n1, n2, cap}
      end
    end
  end
end
