defmodule BitcoinexExplorer.BitcoinRPCTest do
  use ExUnit.Case, async: false

  alias BitcoinexExplorer.BitcoinRPC
  alias BitcoinexExplorerTest.{DataShapes, Fixtures}

  setup do
    bypass = Bypass.open()
    port = bypass.port

    prev =
      Enum.map(
        [:bitcoin_rpc_url, :bitcoin_rpc_user, :bitcoin_rpc_pass],
        fn k -> {k, Application.get_env(:bitcoinex_explorer, k)} end
      )

    Application.put_env(:bitcoinex_explorer, :bitcoin_rpc_url, "http://localhost:#{port}")
    Application.put_env(:bitcoinex_explorer, :bitcoin_rpc_user, "rpc")
    Application.put_env(:bitcoinex_explorer, :bitcoin_rpc_pass, "pw")

    on_exit(fn ->
      Enum.each(prev, fn {k, v} -> Application.put_env(:bitcoinex_explorer, k, v) end)
      Bypass.down(bypass)
    end)

    {:ok, bypass: bypass}
  end

  test "get_recent_blocks/1 chains info + hash + block metadata", %{bypass: bypass} do
    chain = Fixtures.read_json!("rpc/getblockchaininfo.json")
    block = Fixtures.read_json!("rpc/getblock_v1.json")
    hash = Fixtures.read_json!("rpc/getblockhash.json")

    Bypass.stub(bypass, "POST", "/", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      req = Jason.decode!(body)
      rid = req["id"]

      resp =
        case req["method"] do
          "getblockchaininfo" ->
            %{"result" => chain, "error" => nil, "id" => rid}

          "getblockhash" ->
            assert req["params"] == [860_000]
            %{"result" => hash, "error" => nil, "id" => rid}

          "getblock" ->
            assert req["params"] == [hash, 1]
            %{"result" => block, "error" => nil, "id" => rid}

          other ->
            flunk("unexpected RPC #{inspect(other)}")
        end

      Plug.Conn.resp(conn, 200, Jason.encode!(resp))
    end)

    assert {:ok, [summary]} = BitcoinRPC.get_recent_blocks(1)
    DataShapes.assert_block_summary_shape(summary)
    assert summary["height"] == 860_000
  end

  test "get_recent_blocks stops on RPC failure", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 500, "error")
    end)

    assert {:error, {:http_error, 500, _}} = BitcoinRPC.get_recent_blocks(3)
  end

  test "get_block_hash_at_height maps unknown height to error", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      req = Jason.decode!(body)

      resp =
        Jason.encode!(%{
          "result" => nil,
          "error" => %{"code" => -8, "message" => "Block height out of range"},
          "id" => req["id"]
        })

      Plug.Conn.resp(conn, 200, resp)
    end)

    assert {:error, :not_found} = BitcoinRPC.get_block_hash_at_height(999_999_999)
  end

  test "get_mempool normalizes to Esplora mempool keys", %{bypass: bypass} do
    raw = Fixtures.read_json!("rpc/getmempoolinfo.json")

    Bypass.expect(bypass, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      req = Jason.decode!(body)

      Plug.Conn.resp(
        conn,
        200,
        Jason.encode!(%{"result" => raw, "error" => nil, "id" => req["id"]})
      )
    end)

    assert {:ok, m} = BitcoinRPC.get_mempool()
    DataShapes.assert_mempool_shape(m)
  end

  test "get_fee_estimates calls estimatesmartfee per target", %{bypass: bypass} do
    fee_json = Fixtures.read_json!("rpc/estimatesmartfee.json")

    {:ok, agent} = Agent.start_link(fn -> 0 end)

    Bypass.stub(bypass, "POST", "/", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      req = Jason.decode!(body)
      assert req["method"] == "estimatesmartfee"
      Agent.update(agent, &(&1 + 1))

      Plug.Conn.resp(
        conn,
        200,
        Jason.encode!(%{"result" => fee_json, "error" => nil, "id" => req["id"]})
      )
    end)

    assert {:ok, fees} = BitcoinRPC.get_fee_estimates()
    assert is_map(fees)
    assert Agent.get(agent, & &1) == 6
    assert Map.has_key?(fees, "1")
  end
end
