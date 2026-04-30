import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :bitcoinex_explorer, BitcoinexExplorerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "31XQiLwEkmnbFKuWHVAKmiqQq//73GB9fRggbgmeiWI/sECjeKeo/LA5IJH9ouet",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Fast Esplora 429 retry tests (see Esplora.do_get_* retry chain).
config :bitcoinex_explorer, esplora_429_retry_delay_ms: 15
