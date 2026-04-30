defmodule BitcoinexExplorer.ApplicationTest do
  use ExUnit.Case, async: true

  test "FulcrumClient is not registered when DATA_SOURCE defaults to esplora in test" do
    assert Application.get_env(:bitcoinex_explorer, :start_fulcrum_client, false) == false
    assert Process.whereis(BitcoinexExplorer.FulcrumClient) == nil
  end
end
