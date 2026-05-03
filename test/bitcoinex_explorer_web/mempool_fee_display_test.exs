defmodule BitcoinexExplorerWeb.MempoolFeeDisplayTest do
  use ExUnit.Case, async: true

  alias BitcoinexExplorerWeb.MempoolFeeDisplay

  describe "rows/1" do
    test "always includes Next and ~1d" do
      fees = %{"1" => 10.0, "3" => 10.0, "6" => 10.0, "144" => 2.0}
      rows = MempoolFeeDisplay.rows(fees)
      labels = Enum.map(rows, &elem(&1, 0))

      assert {"Next", 1} in rows
      assert {"~1d", 144} in rows
      assert Enum.find_index(labels, &(&1 == "Next")) < Enum.find_index(labels, &(&1 == "~1d"))
    end

    test "omits 3 blk and 6 blk when they match Next" do
      fees = %{"1" => 12.5, "3" => 12.5, "6" => 12.5, "144" => 1.0}
      labels = fees |> MempoolFeeDisplay.rows() |> Enum.map(&elem(&1, 0))

      refute "3 blk" in labels
      refute "6 blk" in labels
      assert labels == ["Next", "~1d"]
    end

    test "includes 3 blk and 6 blk when each differs from Next (even if 3 and 6 match each other)" do
      fees = %{"1" => 20.0, "3" => 15.0, "6" => 15.0, "144" => 1.0}
      labels = fees |> MempoolFeeDisplay.rows() |> Enum.map(&elem(&1, 0))

      assert "3 blk" in labels
      assert "6 blk" in labels
    end

    test "includes 6 blk when it differs from Next even if 3 blk matches Next" do
      fees = %{"1" => 20.0, "3" => 20.0, "6" => 8.0, "144" => 1.0}
      labels = fees |> MempoolFeeDisplay.rows() |> Enum.map(&elem(&1, 0))

      refute "3 blk" in labels
      assert "6 blk" in labels
    end

    test "treats integer and float Next/3 as equal for comparison" do
      fees = %{"1" => 10, "3" => 10.0, "6" => 9, "144" => 1}
      labels = fees |> MempoolFeeDisplay.rows() |> Enum.map(&elem(&1, 0))

      refute "3 blk" in labels
      assert "6 blk" in labels
    end

    test "omits 3 blk and 6 blk when estimates are missing (all nil)" do
      fees = %{}
      labels = fees |> MempoolFeeDisplay.rows() |> Enum.map(&elem(&1, 0))

      assert labels == ["Next", "~1d"]
    end

    test "nil Next still shows 3 blk when 3 has a value" do
      fees = %{"3" => 5.0, "6" => 5.0, "144" => 1.0}
      labels = fees |> MempoolFeeDisplay.rows() |> Enum.map(&elem(&1, 0))

      assert "3 blk" in labels
      assert "6 blk" in labels
    end
  end
end
