defmodule BitcoinexExplorer.EsploraCache do
  @moduledoc """
  Short TTL cache for public Esplora HTTP responses used by the LiveView dashboard.

  Shared across processes so multiple visitors do not each trigger full `recent_blocks`
  pagination against the same API. Only successful `{:ok, _}` results are stored.

  Concurrent cache misses for the same key **single-flight**: only one process runs `fun/0`;
  others wait for the cached result so bursts (many LiveViews mounting together) do not
  multiply Esplora pagination traffic against anonymous rate limits.
  """

  @table :bitcoinex_esplora_dashboard_cache

  # Drop orphaned inflight rows if the holder crashed without deleting the lock.
  @inflight_stale_ms 120_000
  @waiter_deadline_ms 30_000
  @wait_slice_ms 45

  @doc false
  def table_name, do: @table

  @doc """
  Ensures the ETS table exists (idempotent).
  """
  def init_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set])
      _ -> :ok
    end
  end

  @doc """
  Clears all cached entries (e.g. in tests).
  """
  def flush do
    case :ets.whereis(@table) do
      :undefined -> :ok
      _ -> :ets.delete_all_objects(@table)
    end
  end

  @spec get_or_fetch(term(), (() -> term())) :: term()
  def get_or_fetch(key, fun) when is_function(fun, 0) do
    ttl_ms = Application.get_env(:bitcoinex_explorer, :esplora_cache_ttl_ms, 0)

    if ttl_ms <= 0 do
      fun.()
    else
      now_ms = System.monotonic_time(:millisecond)

      case read_fresh_ok(key, now_ms) do
        {:hit, ok} ->
          ok

        :miss ->
          acquire_or_wait(key, fun, ttl_ms, now_ms)
      end
    end
  end

  defp inflight_key(key), do: {:__inflight__, key}

  defp read_fresh_ok(key, now_ms) do
    case :ets.lookup(@table, key) do
      [{^key, {:ok, _} = ok, exp}] when exp > now_ms -> {:hit, ok}
      _ -> :miss
    end
  end

  defp maybe_clear_stale_inflight(key, now_ms) do
    lk = inflight_key(key)

    case :ets.lookup(@table, lk) do
      [{^lk, {pid, lock_started_ms}}] ->
        cond do
          not Process.alive?(pid) ->
            :ets.delete(@table, lk)

          now_ms - lock_started_ms > @inflight_stale_ms ->
            :ets.delete(@table, lk)

          true ->
            :ok
        end

      _ ->
        :ok
    end
  end

  defp acquire_or_wait(key, fun, ttl_ms, started_ms) do
    now_ms = System.monotonic_time(:millisecond)
    maybe_clear_stale_inflight(key, now_ms)

    case read_fresh_ok(key, now_ms) do
      {:hit, ok} ->
        ok

      :miss ->
        lk = inflight_key(key)

        if :ets.insert_new(@table, {lk, {self(), now_ms}}) do
          try do
            case fun.() do
              {:ok, _} = ok ->
                wrote_ms = System.monotonic_time(:millisecond)
                :ets.insert(@table, {key, ok, wrote_ms + ttl_ms})
                ok

              other ->
                other
            end
          after
            :ets.delete(@table, lk)
          end
        else
          wait_for_peer_or_retry(key, fun, ttl_ms, started_ms)
        end
    end
  end

  defp wait_for_peer_or_retry(key, fun, ttl_ms, started_waiting_ms) do
    deadline = started_waiting_ms + @waiter_deadline_ms
    wait_loop(key, fun, ttl_ms, deadline)
  end

  defp wait_loop(key, fun, ttl_ms, deadline_ms) do
    now_ms = System.monotonic_time(:millisecond)

    cond do
      now_ms > deadline_ms ->
        acquire_or_wait(key, fun, ttl_ms, now_ms)

      true ->
        case read_fresh_ok(key, now_ms) do
          {:hit, ok} ->
            ok

          :miss ->
            lk = inflight_key(key)

            case :ets.lookup(@table, lk) do
              [{^lk, {pid, _}}] ->
                cond do
                  not Process.alive?(pid) ->
                    :ets.delete(@table, lk)
                    acquire_or_wait(key, fun, ttl_ms, now_ms)

                  true ->
                    Process.sleep(@wait_slice_ms)
                    wait_loop(key, fun, ttl_ms, deadline_ms)
                end

              [] ->
                Process.sleep(min(@wait_slice_ms, 25))
                acquire_or_wait(key, fun, ttl_ms, System.monotonic_time(:millisecond))
            end
        end
    end
  end
end
