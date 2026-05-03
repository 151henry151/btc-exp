defmodule BitcoinexExplorerWeb.MempoolFeeDisplay do
  @moduledoc false

  @doc """
  Labels and confirmation-target indices for the home mempool fee strip.

  "Next" (1 block) and "~1d" (144 blocks) are always listed. "3 blk" and "6 blk"
  are included only when their sat/vB estimate differs from the Next estimate.
  """
  @spec rows(map() | nil) :: [{String.t(), pos_integer()}]
  def rows(fees) when is_map(fees) do
    next = fee_at(fees, 1)

    [{"Next", 1}] ++
      maybe_row(fees, next, 3, "3 blk") ++
      maybe_row(fees, next, 6, "6 blk") ++
      [{"~1d", 144}]
  end

  def rows(_), do: rows(%{})

  defp maybe_row(fees, next, target, label) do
    v = fee_at(fees, target)
    if fee_estimates_equivalent?(v, next), do: [], else: [{label, target}]
  end

  defp fee_at(fees, target) when is_map(fees) do
    key = Integer.to_string(target)
    Map.get(fees, key) || Map.get(fees, target)
  end

  defp fee_at(_, _), do: nil

  defp fee_estimates_equivalent?(a, b) do
    normalize(a) == normalize(b)
  end

  defp normalize(nil), do: nil
  defp normalize(n) when is_integer(n), do: n / 1
  defp normalize(n) when is_float(n), do: n
  defp normalize(_), do: :other
end
