defmodule BitcoinexExplorer.EsploraCacheTest do
  use ExUnit.Case, async: false

  setup do
    prev = Application.get_env(:bitcoinex_explorer, :esplora_cache_ttl_ms)
    BitcoinexExplorer.EsploraCache.init_table()
    BitcoinexExplorer.EsploraCache.flush()

    on_exit(fn ->
      Application.put_env(:bitcoinex_explorer, :esplora_cache_ttl_ms, prev)
      BitcoinexExplorer.EsploraCache.flush()
    end)

    :ok
  end

  test "get_or_fetch invokes fun each time when ttl is 0" do
    Application.put_env(:bitcoinex_explorer, :esplora_cache_ttl_ms, 0)
    pid = self()

    assert {:ok, 1} =
             BitcoinexExplorer.EsploraCache.get_or_fetch(:x, fn ->
               send(pid, :once)
               {:ok, 1}
             end)

    assert_receive :once

    assert {:ok, 2} =
             BitcoinexExplorer.EsploraCache.get_or_fetch(:x, fn ->
               send(pid, :twice)
               {:ok, 2}
             end)

    assert_receive :twice
  end

  test "get_or_fetch returns cached ok within ttl" do
    Application.put_env(:bitcoinex_explorer, :esplora_cache_ttl_ms, 60_000)
    pid = self()

    assert {:ok, :a} =
             BitcoinexExplorer.EsploraCache.get_or_fetch(:key1, fn ->
               send(pid, :computed)
               {:ok, :a}
             end)

    assert_receive :computed

    assert {:ok, :a} =
             BitcoinexExplorer.EsploraCache.get_or_fetch(:key1, fn ->
               send(pid, :should_not_run)
               {:ok, :b}
             end)

    refute_receive :should_not_run
  end

  test "get_or_fetch does not cache errors" do
    Application.put_env(:bitcoinex_explorer, :esplora_cache_ttl_ms, 60_000)
    pid = self()

    assert {:error, :nope} =
             BitcoinexExplorer.EsploraCache.get_or_fetch(:err, fn ->
               send(pid, :first)
               {:error, :nope}
             end)

    assert_receive :first

    assert {:error, :nope} =
             BitcoinexExplorer.EsploraCache.get_or_fetch(:err, fn ->
               send(pid, :second)
               {:error, :nope}
             end)

    assert_receive :second
  end
end
