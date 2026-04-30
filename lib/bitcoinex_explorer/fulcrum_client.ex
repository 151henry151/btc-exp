defmodule BitcoinexExplorer.FulcrumClient do
  @moduledoc false

  use GenServer

  require Logger

  @default_timeout 15_000
  @initial_backoff_ms 300
  @max_backoff_ms 30_000

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end

  def start_link(opts \\ []) do
    {name, init_opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, init_opts, name: name)
  end

  @spec call(GenServer.server(), String.t(), list()) :: {:ok, term()} | {:error, term()}
  def call(server, method, params)
      when (is_atom(server) or is_pid(server)) and is_binary(method) and is_list(params) do
    timeout = Application.get_env(:bitcoinex_explorer, :fulcrum_request_timeout, @default_timeout)

    try do
      GenServer.call(server, {:call, method, params}, timeout + 2000)
    catch
      :exit, {:timeout, {GenServer, :call, _}} ->
        {:error, :timeout}

      :exit, reason ->
        {:error, {:exit, reason}}
    end
  end

  @spec call(String.t(), list()) :: {:ok, term()} | {:error, term()}
  def call(method, params \\ []) when is_binary(method) and is_list(params) do
    call(__MODULE__, method, params)
  end

  @impl true
  def init(_opts) do
    ssl? = Application.fetch_env!(:bitcoinex_explorer, :fulcrum_ssl)

    host =
      Application.fetch_env!(:bitcoinex_explorer, :fulcrum_host)
      |> String.to_charlist()

    port = Application.fetch_env!(:bitcoinex_explorer, :fulcrum_port)

    ssl_opts =
      Application.get_env(:bitcoinex_explorer, :fulcrum_ssl_opts, [
        verify: :verify_none,
        server_name_indication: :disable
      ])

    {:ok,
     %{
       host: host,
       port: port,
       ssl?: ssl?,
       ssl_opts: ssl_opts,
       socket: nil,
       buffer: "",
       pending: %{},
       next_id: 1,
       backoff_ms: @initial_backoff_ms,
       transport: if(ssl?, do: :ssl, else: :gen_tcp)
     }, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case establish_connection(state) do
      {:ok, sock, transport} ->
        setopts(transport, sock, active: :once)
        {:noreply, %{state | socket: sock, transport: transport, backoff_ms: @initial_backoff_ms}}

      {:error, reason} ->
        Logger.warning("FulcrumClient: connect failed #{inspect(reason)}, backing off #{state.backoff_ms}ms")
        schedule_reconnect(state.backoff_ms)
        next_backoff = min(state.backoff_ms * 2, @max_backoff_ms)
        {:noreply, %{state | backoff_ms: next_backoff}}
    end
  end

  @impl true
  def handle_call({:call, _method, _params}, _from, %{socket: nil} = state) do
    {:reply, {:error, :disconnected}, state}
  end

  def handle_call({:call, method, params}, from, state) do
    id = state.next_id
    line = Jason.encode!(%{method: method, params: params, id: id}) <> "\n"

    send_fn =
      case state.transport do
        :ssl -> &:ssl.send/2
        :gen_tcp -> &:gen_tcp.send/2
      end

    case send_fn.(state.socket, line) do
      :ok ->
        {:noreply,
         %{state | pending: Map.put(state.pending, id, {from, method}), next_id: id + 1}}

      {:error, reason} ->
        Logger.warning("FulcrumClient: send failed #{inspect(reason)}")
        st = disconnect_for_retry(state)
        {:reply, {:error, {:send_failed, reason}}, st}
    end
  end

  @impl true
  def handle_info(:reconnect_tick, state) do
    {:noreply, state, {:continue, :connect}}
  end

  def handle_info({:tcp, socket, data}, %{socket: socket, transport: :gen_tcp} = state) do
    handle_data(data, state)
  end

  def handle_info({:ssl, socket, data}, %{socket: socket, transport: :ssl} = state) do
    handle_data(data, state)
  end

  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    Logger.warning("FulcrumClient: TCP closed")
    {:noreply, disconnect!(state, :connection_lost)}
  end

  def handle_info({:ssl_closed, socket}, %{socket: socket} = state) do
    Logger.warning("FulcrumClient: SSL closed")
    {:noreply, disconnect!(state, :connection_lost)}
  end

  def handle_info({:tcp_error, socket, reason}, %{socket: socket} = state) do
    Logger.warning("FulcrumClient: TCP error #{inspect(reason)}")
    {:noreply, disconnect!(state, :connection_lost)}
  end

  def handle_info({:ssl_error, socket, reason}, %{socket: socket} = state) do
    Logger.warning("FulcrumClient: SSL error #{inspect(reason)}")
    {:noreply, disconnect!(state, :connection_lost)}
  end

  def handle_info(_, state), do: {:noreply, state}

  defp disconnect!(state, reason) do
    err =
      case reason do
        :connection_lost -> {:error, :connection_lost}
        other -> {:error, other}
      end

    Enum.each(state.pending, fn {_id, {from, _meth}} -> GenServer.reply(from, err) end)

    _ = close_socket(state)
    schedule_reconnect(state.backoff_ms)
    next_backoff = min(state.backoff_ms * 2, @max_backoff_ms)

    %{
      state
      | socket: nil,
        buffer: "",
        pending: %{},
        backoff_ms: next_backoff
    }
  end

  defp disconnect_for_retry(state) do
    _ = close_socket(state)
    schedule_reconnect(state.backoff_ms)
    next_backoff = min(state.backoff_ms * 2, @max_backoff_ms)

    %{
      state
      | socket: nil,
        buffer: "",
        backoff_ms: next_backoff
    }
  end

  defp handle_data(data, state) do
    buffer = state.buffer <> data
    {lines, rest} = split_lines(buffer)

    state =
      Enum.reduce(lines, state, fn line, st ->
        decode_and_dispatch(line, st)
      end)

    if state.socket do
      setopts(state.transport, state.socket, active: :once)
    end

    {:noreply, %{state | buffer: rest}}
  end

  defp split_lines(buffer), do: split_lines(buffer, [])

  defp split_lines(buffer, acc) do
    case :binary.split(buffer, "\n") do
      [rest] ->
        {Enum.reverse(acc), rest}

      [line, rest] ->
        split_lines(rest, [line | acc])
    end
  end

  defp decode_and_dispatch("", state), do: state

  defp decode_and_dispatch(line, state) do
    case Jason.decode(line) do
      {:ok, %{"method" => _} = _notification} ->
        state

      {:ok, %{"id" => id} = resp} ->
        case Map.pop(state.pending, id) do
          {nil, _} ->
            state

          {{from, _method}, pending} ->
            reply =
              case resp do
                %{"result" => result} ->
                  {:ok, result}

                %{"error" => err} when is_map(err) ->
                  {:error, {:fulcrum_error, err}}

                _ ->
                  {:error, {:invalid_response, resp}}
              end

            GenServer.reply(from, reply)
            %{state | pending: pending}
        end

      {:ok, _} ->
        state

      {:error, _} ->
        state
    end
  end

  defp establish_connection(%{ssl?: false} = state) do
    opts = [:binary, active: false]

    case :gen_tcp.connect(state.host, state.port, opts, @default_timeout) do
      {:ok, sock} -> {:ok, sock, :gen_tcp}
      err -> err
    end
  end

  defp establish_connection(%{ssl?: true} = state) do
    tcp_opts = [:binary, active: false]

    with {:ok, tcp} <- :gen_tcp.connect(state.host, state.port, tcp_opts, @default_timeout),
         {:ok, ssl_sock} <- :ssl.connect(tcp, state.ssl_opts, @default_timeout) do
      {:ok, ssl_sock, :ssl}
    else
      {:error, _} = err ->
        err
    end
  end

  defp setopts(:gen_tcp, sock, opts), do: :inet.setopts(sock, opts)
  defp setopts(:ssl, sock, opts), do: :ssl.setopts(sock, opts)

  defp close_socket(%{socket: nil}), do: :ok

  defp close_socket(%{socket: sock, transport: :gen_tcp}) do
    _ = :gen_tcp.close(sock)
    :ok
  end

  defp close_socket(%{socket: sock, transport: :ssl}) do
    _ = :ssl.close(sock)
    :ok
  end

  defp schedule_reconnect(ms) do
    Process.send_after(self(), :reconnect_tick, ms)
  end
end
