defmodule BitcoinexExplorer.BitcoinCoreRpcTest do
  use ExUnit.Case, async: false

  alias BitcoinexExplorer.BitcoinCoreRpc

  setup do
    bypass = Bypass.open()

    prev =
      Enum.map([:bitcoin_rpc_url, :bitcoin_rpc_user, :bitcoin_rpc_pass], fn k ->
        {k, Application.get_env(:bitcoinex_explorer, k)}
      end)

    Application.put_env(:bitcoinex_explorer, :bitcoin_rpc_url, "http://localhost:#{bypass.port}")
    Application.put_env(:bitcoinex_explorer, :bitcoin_rpc_user, "u")
    Application.put_env(:bitcoinex_explorer, :bitcoin_rpc_pass, "p")

    on_exit(fn ->
      Enum.each(prev, fn {k, v} -> Application.put_env(:bitcoinex_explorer, k, v) end)
      Bypass.down(bypass)
    end)

    {:ok, bypass: bypass}
  end

  test "call returns decoded result on success", %{bypass: bypass} do
    Bypass.expect(bypass, "POST", "/", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      req = Jason.decode!(body)

      resp =
        Jason.encode!(%{
          "result" => %{"blocks" => 123},
          "error" => nil,
          "id" => req["id"]
        })

      Plug.Conn.resp(conn, 200, resp)
    end)

    assert {:ok, %{"blocks" => 123}} = BitcoinCoreRpc.call("getblockchaininfo", [])
  end

  test "call maps JSON-RPC error to {:error, {:rpc_error, code, msg}}", %{bypass: bypass} do
    Bypass.expect(bypass, "POST", "/", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      req = Jason.decode!(body)

      err_body =
        Jason.encode!(%{
          "result" => nil,
          "error" => %{"code" => -32601, "message" => "Method not found"},
          "id" => req["id"]
        })

      Plug.Conn.resp(conn, 200, err_body)
    end)

    assert {:error, {:rpc_error, -32601, "Method not found"}} =
             BitcoinCoreRpc.call("nonexistent", [])
  end

  test "HTTP failure propagates as {:http_error, status, _}", %{bypass: bypass} do
    Bypass.expect(bypass, "POST", "/", fn conn ->
      Plug.Conn.resp(conn, 500, "oops")
    end)

    assert {:error, {:http_error, 500, _}} = BitcoinCoreRpc.call("getblockchaininfo", [])
  end
end
