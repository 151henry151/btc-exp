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
