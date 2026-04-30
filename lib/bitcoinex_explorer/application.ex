defmodule BitcoinexExplorer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    BitcoinexExplorer.EsploraCache.init_table()

    base = [
      BitcoinexExplorerWeb.Telemetry,
      {DNSCluster,
       query: Application.get_env(:bitcoinex_explorer, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BitcoinexExplorer.PubSub}
    ]

    fulcrum =
      if Application.get_env(:bitcoinex_explorer, :start_fulcrum_client, false) do
        [{BitcoinexExplorer.FulcrumClient, []}]
      else
        []
      end

    children = base ++ fulcrum ++ [BitcoinexExplorerWeb.Endpoint]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BitcoinexExplorer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BitcoinexExplorerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
