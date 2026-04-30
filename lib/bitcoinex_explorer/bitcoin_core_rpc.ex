defmodule BitcoinexExplorer.BitcoinCoreRpc do
  @moduledoc false

  alias Tesla.Env

  @req_timeout 60_000

  defp client do
    url = Application.fetch_env!(:bitcoinex_explorer, :bitcoin_rpc_url)
    user = Application.fetch_env!(:bitcoinex_explorer, :bitcoin_rpc_user)
    pass = Application.fetch_env!(:bitcoinex_explorer, :bitcoin_rpc_pass)

    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, String.trim_trailing(url, "/")},
        {Tesla.Middleware.BasicAuth, %{username: user, password: pass}},
        {Tesla.Middleware.Headers, [{"content-type", "application/json"}]},
        {Tesla.Middleware.Timeout, timeout: @req_timeout},
        Tesla.Middleware.JSON
      ],
      Tesla.Adapter.Hackney
    )
  end

  @spec call(String.t(), list()) :: {:ok, term()} | {:error, term()}
  def call(method, params \\ []) when is_binary(method) and is_list(params) do
    body = %{
      "jsonrpc" => "2.0",
      "method" => method,
      "params" => params,
      "id" => System.unique_integer([:positive])
    }

    case Tesla.post(client(), "/", body) do
      {:ok, %Env{status: 200, body: raw_body}} ->
        case normalize_json_body(raw_body) do
          {:ok, %{"error" => %{"code" => code, "message" => msg}}} ->
            {:error, {:rpc_error, code, msg}}

          {:ok, %{"result" => result}} ->
            {:ok, result}

          {:ok, other} ->
            {:error, {:invalid_rpc_body, other}}

          {:error, _} = err ->
            err
        end

      {:ok, %Env{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  defp normalize_json_body(body) when is_map(body), do: {:ok, body}

  defp normalize_json_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, map} when is_map(map) -> {:ok, map}
      {:ok, _} -> {:error, :invalid_jsonrpc_shape}
      {:error, _} -> {:error, :invalid_json}
    end
  end

  defp normalize_json_body(_), do: {:error, :invalid_body}
end
