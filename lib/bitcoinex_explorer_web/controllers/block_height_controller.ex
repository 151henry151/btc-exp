defmodule BitcoinexExplorerWeb.BlockHeightController do
  use BitcoinexExplorerWeb, :controller

  alias BitcoinexExplorer.DataSource

  def redirect_to_block(conn, %{"height" => height_str}) do
    case Integer.parse(height_str) do
      {height, ""} when height >= 0 ->
        case DataSource.impl().get_block_hash_at_height(height) do
          {:ok, hash} ->
            redirect(conn, to: ~p"/block/#{hash}")

          {:error, :not_found} ->
            conn
            |> put_flash(:error, "No block at that height.")
            |> redirect(to: ~p"/")

          {:error, _} ->
            conn
            |> put_flash(:error, "Could not resolve block height.")
            |> redirect(to: ~p"/")
        end

      _ ->
        conn
        |> put_flash(:error, "Invalid block height.")
        |> redirect(to: ~p"/")
    end
  end
end
