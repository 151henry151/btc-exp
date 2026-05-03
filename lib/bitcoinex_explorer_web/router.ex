defmodule BitcoinexExplorerWeb.Router do
  use BitcoinexExplorerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {BitcoinexExplorerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", BitcoinexExplorerWeb do
    pipe_through :browser

    get "/block/height/:height", BlockHeightController, :redirect_to_block
    get "/channels", ChannelsRedirectController, :redirect_to_home

    live_session :explorer,
      on_mount: [] do
      live "/", ExplorerLive, :home
      live "/block/:hash", ExplorerLive, :block
      live "/tx/:txid", ExplorerLive, :tx
      live "/address/:address", ExplorerLive, :address
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", BitcoinexExplorerWeb do
  #   pipe_through :api
  # end
end
