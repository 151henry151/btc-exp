defmodule BitcoinexExplorer.DataSourceTest do
  use ExUnit.Case, async: true

  alias BitcoinexExplorer.DataSource

  test "impl/0 returns configured backend module from application env" do
    mod = Application.fetch_env!(:bitcoinex_explorer, :data_source_module)
    assert mod == DataSource.impl()
    assert mod == BitcoinexExplorer.Esplora
  end
end
