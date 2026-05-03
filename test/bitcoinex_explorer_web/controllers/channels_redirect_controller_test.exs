defmodule BitcoinexExplorerWeb.ChannelsRedirectControllerTest do
  use BitcoinexExplorerWeb.ConnCase, async: true

  test "GET /channels redirects to /", %{conn: conn} do
    conn = get(conn, ~p"/channels")
    assert redirected_to(conn, 302) == ~p"/"
  end
end
