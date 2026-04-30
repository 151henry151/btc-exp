defmodule BitcoinexExplorer.Search do
  @moduledoc """
  Maps paste-box input to navigation targets vs local decode-only payloads.
  """

  alias BitcoinexExplorer.Decode

  @type classification ::
          {:bolt11, binary()}
          | {:psbt, binary()}
          | {:hex64, binary()}
          | {:block_height, non_neg_integer()}
          | {:address, binary()}
          | {:decode_only, binary()}

  @spec classify(binary()) :: classification()
  def classify(raw) when is_binary(raw) do
    trimmed = String.trim(raw)
    compact_psbt = String.replace(trimmed, ~r/\s+/, "")

    cond do
      trimmed == "" ->
        {:decode_only, ""}

      Decode.looks_like_bolt11?(trimmed) ->
        {:bolt11, trimmed}

      Decode.looks_like_psbt?(compact_psbt) ->
        {:psbt, trimmed}

      match_all_digits?(trimmed) ->
        case Integer.parse(trimmed) do
          {height, ""} when height >= 0 ->
            {:block_height, height}

          _ ->
            {:decode_only, trimmed}
        end

      match_hex64?(trimmed) ->
        {:hex64, String.downcase(trimmed)}

      valid_address?(trimmed) ->
        {:address, trimmed}

      true ->
        {:decode_only, trimmed}
    end
  end

  defp match_all_digits?(s), do: Regex.match?(~r/^\d+$/, s)

  defp match_hex64?(s), do: Regex.match?(~r/^[0-9a-fA-F]{64}$/, s)

  defp valid_address?(trimmed) do
    case Decode.decode_address(trimmed) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end
end
