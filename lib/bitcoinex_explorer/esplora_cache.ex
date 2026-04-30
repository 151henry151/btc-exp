defmodule BitcoinexExplorer.EsploraCache do
  @moduledoc """
  Short TTL cache for public Esplora HTTP responses used by the LiveView dashboard.

  Shared across processes so multiple visitors do not each trigger full `recent_blocks`
  pagination against the same API. Only successful `{:ok, _}` results are stored.
  """

  @table :bitcoinex_esplora_dashboard_cache

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

      case :ets.lookup(@table, key) do
        [{^key, {:ok, _} = ok, exp}] when exp > now_ms ->
          ok

        _ ->
          case fun.() do
            {:ok, _} = ok ->
              :ets.insert(@table, {key, ok, now_ms + ttl_ms})
              ok

            other ->
              other
          end
      end
    end
  end
end
