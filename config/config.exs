# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :bitcoinex_explorer,
  generators: [timestamp_type: :utc_datetime],
  esplora_base_url: "https://blockstream.info/api"

# Configures the endpoint
config :bitcoinex_explorer, BitcoinexExplorerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: BitcoinexExplorerWeb.ErrorHTML, json: BitcoinexExplorerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: BitcoinexExplorer.PubSub,
  live_view: [signing_salt: "MIUzq9iu"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  bitcoinex_explorer: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  bitcoinex_explorer: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
