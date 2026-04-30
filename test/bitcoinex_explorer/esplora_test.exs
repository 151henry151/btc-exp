defmodule BitcoinexExplorer.EsploraTest do
  use ExUnit.Case, async: false

  setup do
    bypass = Bypass.open()
    prev = Application.get_env(:bitcoinex_explorer, :esplora_base_url)
    Application.put_env(:bitcoinex_explorer, :esplora_base_url, "http://localhost:#{bypass.port}")

    on_exit(fn ->
      Application.put_env(:bitcoinex_explorer, :esplora_base_url, prev)
    end)

    {:ok, bypass: bypass}
  end

  test "blocks returns decoded JSON list", %{bypass: bypass} do
    Bypass.expect(bypass, "GET", "/blocks", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!([%{"id" => "abc", "height" => 1}]))
    end)

    assert {:ok, [%{"id" => "abc"}]} = BitcoinexExplorer.Esplora.blocks()
  end

  test "recent_blocks follows /blocks then /blocks/<height> until limit", %{bypass: bypass} do
    batch1 =
      for h <- 20..11//-1,
          do: %{"id" => String.pad_leading(Integer.to_string(h), 64, "a"), "height" => h}

    batch2 =
      for h <- 10..6//-1,
          do: %{"id" => String.pad_leading(Integer.to_string(h), 64, "b"), "height" => h}

    Bypass.expect(bypass, fn conn ->
      conn = Plug.Conn.put_resp_content_type(conn, "application/json")

      case conn.request_path do
        "/blocks" ->
          Plug.Conn.resp(conn, 200, Jason.encode!(batch1))

        "/blocks/10" ->
          Plug.Conn.resp(conn, 200, Jason.encode!(batch2))

        other ->
          Plug.Conn.resp(conn, 404, "unexpected #{other}")
      end
    end)

    assert {:ok, merged} = BitcoinexExplorer.Esplora.recent_blocks(15)
    assert length(merged) == 15
    assert List.first(merged)["height"] == 20
    assert List.last(merged)["height"] == 6

    assert {:ok, twelve} = BitcoinexExplorer.Esplora.recent_blocks(12)
    assert length(twelve) == 12
    assert List.last(twelve)["height"] == 9
  end

  test "mempool uses dashboard cache when ttl > 0", %{bypass: bypass} do
    prev_ttl = Application.get_env(:bitcoinex_explorer, :esplora_cache_ttl_ms)
    BitcoinexExplorer.EsploraCache.flush()
    Application.put_env(:bitcoinex_explorer, :esplora_cache_ttl_ms, 60_000)

    on_exit(fn ->
      Application.put_env(:bitcoinex_explorer, :esplora_cache_ttl_ms, prev_ttl)
      BitcoinexExplorer.EsploraCache.flush()
    end)

    Bypass.expect(bypass, "GET", "/mempool", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(%{"count" => 42}))
    end)

    assert {:ok, %{"count" => 42}} = BitcoinexExplorer.Esplora.mempool()
    assert {:ok, %{"count" => 42}} = BitcoinexExplorer.Esplora.mempool()
  end

  test "404 maps to not_found", %{bypass: bypass} do
    Bypass.expect(bypass, "GET", "/tx/nope", fn conn ->
      Plug.Conn.resp(conn, 404, "")
    end)

    assert {:error, :not_found} = BitcoinexExplorer.Esplora.transaction("nope")
  end

  test "block_height returns trimmed hash", %{bypass: bypass} do
    hash = String.duplicate("ab", 32)

    Bypass.expect(bypass, "GET", "/block-height/800000", fn conn ->
      Plug.Conn.resp(conn, 200, hash <> "\n")
    end)

    assert {:ok, ^hash} = BitcoinexExplorer.Esplora.block_hash_at_height(800_000)
  end
end
