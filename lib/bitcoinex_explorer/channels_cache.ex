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

  defp fetch_both do
    base = Application.fetch_env!(:bitcoinex_explorer, :mempool_base_url)

    client =
      Tesla.client(
        [
          {Tesla.Middleware.BaseUrl, base},
          Tesla.Middleware.JSON
        ],
        Tesla.Adapter.Hackney
      )

    with {:ok, %Env{status: 200, body: stats}} <-
           Tesla.get(client, "/api/v1/lightning/statistics/latest"),
         {:ok, %Env{status: 200, body: nodes}} <-
           Tesla.get(client, "/api/v1/lightning/nodes/rankings/liquidity", query: [limit: 100]) do
      {:ok, %{stats: stats, nodes: List.wrap(nodes)}}
    else
      {:ok, %Env{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:transport, reason}}

      _ ->
        {:error, :unexpected}
    end
  end
end
