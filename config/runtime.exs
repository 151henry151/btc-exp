import Config

data_source_raw =
  System.get_env("DATA_SOURCE", "esplora")
  |> String.trim()
  |> String.downcase()

{data_source_module, start_fulcrum_client} =
  case data_source_raw do
    "esplora" ->
      {BitcoinexExplorer.Esplora, false}

    "rpc" ->
      {BitcoinexExplorer.BitcoinRPC, true}

    other ->
      raise ArgumentError,
            "Invalid DATA_SOURCE=#{inspect(other)}. Use \"esplora\" or \"rpc\"."
  end

rpc_url = System.get_env("BITCOIN_RPC_URL", "http://127.0.0.1:8332")
rpc_user = System.get_env("BITCOIN_RPC_USER", "")
rpc_pass = System.get_env("BITCOIN_RPC_PASS", "")

fulcrum_host = System.get_env("FULCRUM_HOST", "127.0.0.1")

fulcrum_port =
  System.get_env("FULCRUM_PORT", "50001")
  |> String.trim()
  |> case do
    "" -> 50001
    p -> String.to_integer(p)
  end

fulcrum_ssl =
  System.get_env("FULCRUM_SSL", "false")
  |> String.trim()
  |> String.downcase()
  |> Kernel.in(~w(1 true yes))

if data_source_module == BitcoinexExplorer.BitcoinRPC and config_env() == :prod do
  for {var, val} <- [
        {"BITCOIN_RPC_URL", rpc_url},
        {"BITCOIN_RPC_USER", rpc_user},
        {"BITCOIN_RPC_PASS", rpc_pass}
      ] do
    if val == nil or String.trim(to_string(val)) == "" do
      raise ArgumentError, "#{var} is required when DATA_SOURCE=rpc"
    end
  end
end

config :bitcoinex_explorer,
  data_source_module: data_source_module,
  start_fulcrum_client: start_fulcrum_client,
  bitcoin_rpc_url: rpc_url,
  bitcoin_rpc_user: rpc_user,
  bitcoin_rpc_pass: rpc_pass,
  fulcrum_host: fulcrum_host,
  fulcrum_port: fulcrum_port,
  fulcrum_ssl: fulcrum_ssl,
  fulcrum_ssl_opts: [
    verify: :verify_none,
    server_name_indication: :disable
  ]

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/bitcoinex_explorer start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :bitcoinex_explorer, BitcoinexExplorerWeb.Endpoint, server: true
end

esplora_cache_ttl_ms =
  case System.get_env("ESPLORA_CACHE_TTL_MS", "") |> String.trim() do
    "" ->
      if config_env() == :prod, do: 45_000, else: 0

    s ->
      case Integer.parse(s) do
        {n, _} when n >= 0 -> n
        _ -> 0
      end
  end

esplora_min_request_interval_ms =
  case System.get_env("ESPLORA_MIN_REQUEST_INTERVAL_MS", "") |> String.trim() do
    "" ->
      if config_env() == :prod, do: 250, else: 0

    s ->
      case Integer.parse(s) do
        {n, _} when n >= 0 -> n
        _ -> 0
      end
  end

config :bitcoinex_explorer,
  esplora_base_url: System.get_env("ESPLORA_BASE_URL", "https://blockstream.info/api"),
  esplora_cache_ttl_ms: esplora_cache_ttl_ms,
  esplora_min_request_interval_ms: esplora_min_request_interval_ms

# Note: data_source_module / Fulcrum / Bitcoin RPC env vars are applied earlier in this file.

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  # Public URL path when served behind nginx under a prefix (e.g. /btcexp).
  # Set PHX_PATH=btcexp (no leading slash) so assets and LiveView use the correct path.
  phx_path =
    case System.get_env("PHX_PATH") do
      nil -> nil
      "" -> nil
      p -> "/" <> String.trim(p, "/")
    end

  url_opts = [host: host, port: 443, scheme: "https"]

  url_opts =
    if phx_path do
      Keyword.put(url_opts, :path, phx_path)
    else
      url_opts
    end

  # Default to loopback in production; set PHX_BIND=all to listen on all interfaces.
  http_ip =
    if System.get_env("PHX_BIND") == "all" do
      {0, 0, 0, 0, 0, 0, 0, 0}
    else
      {127, 0, 0, 1}
    end

  config :bitcoinex_explorer, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :bitcoinex_explorer, BitcoinexExplorerWeb.Endpoint,
    url: url_opts,
    http: [
      ip: http_ip,
      port: port
    ],
    secret_key_base: secret_key_base,
    check_origin: [
      "https://hromp.com",
      "https://www.hromp.com"
    ]

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :bitcoinex_explorer, BitcoinexExplorerWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :bitcoinex_explorer, BitcoinexExplorerWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
