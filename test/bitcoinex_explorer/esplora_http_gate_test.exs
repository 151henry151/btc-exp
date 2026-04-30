defmodule BitcoinexExplorer.EsploraHttpGateTest do
  use ExUnit.Case, async: true

  alias BitcoinexExplorer.EsploraHttpGate

  describe "compute_wait_ms/3" do
    test "returns 0 when gap is non-positive" do
      assert EsploraHttpGate.compute_wait_ms(1000, 0, 0) == 0
      assert EsploraHttpGate.compute_wait_ms(1000, 0, -5) == 0
    end

    test "returns 0 when no prior completion (first request)" do
      assert EsploraHttpGate.compute_wait_ms(99, nil, 250) == 0
    end

    test "returns 0 when enough time has passed since last completion" do
      assert EsploraHttpGate.compute_wait_ms(500, 100, 250) == 0
    end

    test "returns remaining gap when calls would be too close" do
      assert EsploraHttpGate.compute_wait_ms(300, 100, 250) == 50
    end
  end
end
