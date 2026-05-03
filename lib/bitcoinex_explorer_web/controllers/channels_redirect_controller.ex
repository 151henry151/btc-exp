defmodule BitcoinexExplorerWeb.ChannelsRedirectController do
  use BitcoinexExplorerWeb, :controller

  def redirect_to_home(conn, _params) do
    redirect(conn, to: ~p"/")
  end
end
