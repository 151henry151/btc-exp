defmodule BitcoinexExplorer.EsploraHttpGate do
  @moduledoc false

  # Serializes Esplora HTTP through one process. Reference Esplora/nginx configs
  # rate-limit by request arrival (e.g. Blockstream's sample nginx uses ~5 r/s for
  # `/api/`). We enforce a minimum gap between *starting* consecutive requests so
  # inter-arrival stays under that envelope even when responses are fast.

  use GenServer

  @doc """
  Milliseconds to sleep before issuing the next HTTP call so that at least `gap_ms`
  passes since `last_started_ms` (`nil` means no prior start). Used by the gate and tests.
  """
  def compute_wait_ms(_now_ms, _last_started_ms, gap_ms) when gap_ms <= 0, do: 0

  def compute_wait_ms(_now_ms, nil, gap_ms) when gap_ms > 0, do: 0

  def compute_wait_ms(now_ms, last_started_ms, gap_ms)
      when is_integer(now_ms) and is_integer(last_started_ms) and is_integer(gap_ms) and
             gap_ms > 0 do
    max(0, gap_ms - (now_ms - last_started_ms))
  end

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Runs `fun/0` (the HTTP call). When the configured gap is positive, execution is
  serialized and spaced; otherwise `fun` runs in the caller process.
  """
  def run(fun) when is_function(fun, 0) do
    gap_ms = Application.get_env(:bitcoinex_explorer, :esplora_min_request_interval_ms, 0)

    if gap_ms <= 0 do
      fun.()
    else
      GenServer.call(__MODULE__, {:run, fun}, 300_000)
    end
  end

  @impl true
  def init(_) do
    {:ok, %{last_started_ms: nil}}
  end

  @impl true
  def handle_call({:run, fun}, _from, %{last_started_ms: last} = state) do
    gap_ms = Application.get_env(:bitcoinex_explorer, :esplora_min_request_interval_ms, 0)
    now_ms = System.monotonic_time(:millisecond)
    wait_ms = compute_wait_ms(now_ms, last, gap_ms)
    if wait_ms > 0, do: Process.sleep(wait_ms)

    started_ms = System.monotonic_time(:millisecond)
    result = fun.()
    {:reply, result, %{state | last_started_ms: started_ms}}
  end
end
