defmodule BitcoinexExplorer.FulcrumClientTest do
  use ExUnit.Case, async: false

  alias BitcoinexExplorer.FulcrumClient

  @moduletag capture_log: true

  defp fulcrum_env_backup do
    [:fulcrum_host, :fulcrum_port, :fulcrum_ssl, :fulcrum_request_timeout]
    |> Enum.map(&{&1, Application.get_env(:bitcoinex_explorer, &1)})
  end

  defp restore_env!(pairs) do
    Enum.each(pairs, fn {k, v} -> Application.put_env(:bitcoinex_explorer, k, v) end)
  end

  defp mock_tcp_one_response!(result_fn) do
    {:ok, lsock} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(lsock)
    parent = self()
    ref = make_ref()

    Task.start(fn ->
      {:ok, client} = :gen_tcp.accept(lsock)
      :inet.close(lsock)
      :inet.setopts(client, packet: :line)
      send(parent, {:mock_accepted, ref})

      case :gen_tcp.recv(client, 0, 5000) do
        {:ok, line} ->
          req = Jason.decode!(String.trim(to_string(line)))
          body = result_fn.(req)
          :ok = :gen_tcp.send(client, Jason.encode!(body) <> "\n")

        {:error, _} ->
          :ok
      end
    end)

    {port, ref}
  end

  test "successful Electrum request/response cycle" do
    backup = fulcrum_env_backup()

    {port, ref} =
      mock_tcp_one_response!(fn req ->
        assert req["method"] == "server.version"
        assert is_integer(req["id"])
        %{"result" => %{"ok" => true}, "id" => req["id"]}
      end)

    Application.put_env(:bitcoinex_explorer, :fulcrum_host, "127.0.0.1")
    Application.put_env(:bitcoinex_explorer, :fulcrum_port, port)
    Application.put_env(:bitcoinex_explorer, :fulcrum_ssl, false)

    on_exit(fn -> restore_env!(backup) end)

    {:ok, pid} = start_supervised({FulcrumClient, name: FulcrumClientSingleShot})

    assert_receive {:mock_accepted, ^ref}, 3000
    assert sync_connected(pid)

    assert {:ok, %{"ok" => true}} =
             FulcrumClient.call(FulcrumClientSingleShot, "server.version", [["app", "1.4"]])
  end

  # Concurrent callers share one GenServer and serialize — ID reordering is still validated
  # by the Receive loop dispatch logic (see `decode_and_dispatch/2` in FulcrumClient).

  test "GenServer.call timeout surfaces as {:error, :timeout}" do
    backup = fulcrum_env_backup()

    {:ok, lsock} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(lsock)

    Task.start(fn ->
      {:ok, client} = :gen_tcp.accept(lsock)
      :inet.close(lsock)
      :inet.setopts(client, packet: :line)
      {:ok, _line} = :gen_tcp.recv(client, 0, 5000)
      Process.sleep(60_000)
    end)

    Process.sleep(80)

    Application.put_env(:bitcoinex_explorer, :fulcrum_host, "127.0.0.1")
    Application.put_env(:bitcoinex_explorer, :fulcrum_port, port)
    Application.put_env(:bitcoinex_explorer, :fulcrum_ssl, false)
    Application.put_env(:bitcoinex_explorer, :fulcrum_request_timeout, 150)

    on_exit(fn -> restore_env!(backup) end)

    {:ok, _} = start_supervised({FulcrumClient, name: FulcrumClientTimeout})

    assert sync_connected(FulcrumClientTimeout)
    assert {:error, :timeout} = FulcrumClient.call(FulcrumClientTimeout, "server.ping", [])
  end

  defp sync_connected(pid) do
    Enum.reduce_while(1..80, nil, fn _, _ ->
      state = :sys.get_state(pid)

      if state.socket != nil do
        {:halt, :ok}
      else
        Process.sleep(25)
        {:cont, nil}
      end
    end) == :ok
  end
end
