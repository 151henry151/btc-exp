defmodule BitcoinexExplorer.EsploraHttpGate do
  @moduledoc false

  # Serializes Esplora HTTP through one process and sleeps so consecutive requests
  # are spaced by at least `:esplora_min_request_interval_ms` (wall clock between
  # end of one request and start of the next). Public APIs often return 429 when
  # requests overlap or arrive too quickly.

  use GenServer

  @doc """
  Minimum milliseconds to wait before starting the next Esplora HTTP call after
  the previous one finished. Used by the gate and for tests.
  """
  def compute_wait_ms(_now_ms, _last_completed_ms, gap_ms) when gap_ms <= 0, do: 0

  def compute_wait_ms(_now_ms, nil, gap_ms) when gap_ms > 0, do: 0

  def compute_wait_ms(now_ms, last_completed_ms, gap_ms)
      when is_integer(now_ms) and is_integer(last_completed_ms) and is_integer(gap_ms) and
             gap_ms > 0 do
    max(0, gap_ms - (now_ms - last_completed_ms))
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
    {:ok, %{last_completed_ms: nil}}
  end

  @impl true
  def handle_call({:run, fun}, _from, %{last_completed_ms: last} = state) do
    gap_ms = Application.get_env(:bitcoinex_explorer, :esplora_min_request_interval_ms, 0)
    now_ms = System.monotonic_time(:millisecond)
    wait_ms = compute_wait_ms(now_ms, last, gap_ms)
    if wait_ms > 0, do: Process.sleep(wait_ms)

    result = fun.()
    done_ms = System.monotonic_time(:millisecond)
    {:reply, result, %{state | last_completed_ms: done_ms}}
  end
end
