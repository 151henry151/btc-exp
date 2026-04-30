defmodule BitcoinexExplorer.ApplicationTest do
  use ExUnit.Case, async: true

  test "FulcrumClient is not registered when DATA_SOURCE defaults to esplora in test" do
    assert Application.get_env(:bitcoinex_explorer, :start_fulcrum_client, false) == false
    assert Process.whereis(BitcoinexExplorer.FulcrumClient) == nil
  end

  test "EsploraHttpGate is not registered when esplora_min_request_interval_ms is 0 in test" do
    assert Application.get_env(:bitcoinex_explorer, :esplora_min_request_interval_ms, 0) == 0
    assert Process.whereis(BitcoinexExplorer.EsploraHttpGate) == nil
  end
end
