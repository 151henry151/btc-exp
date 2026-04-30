defmodule BitcoinexExplorer.Decode do
  @moduledoc """
  Bitcoin address, BOLT11, and PSBT decoding using Bitcoinex (same behaviour as before extraction).
  """

  alias Bitcoinex.{Base58, PSBT, Segwit}
  alias Bitcoinex.LightningNetwork.Invoice
  alias Decimal

  def decode_auto(value) when is_binary(value) do
    trimmed = String.trim(value)
    compact_psbt = String.replace(trimmed, ~r/\s+/, "")

    cond do
      looks_like_bolt11?(trimmed) ->
        decode_invoice(trimmed)

      looks_like_psbt?(compact_psbt) ->
        decode_psbt(compact_psbt)

      true ->
        decode_address(trimmed)
    end
  end

  def looks_like_bolt11?(s) when is_binary(s) do
    String.length(s) >= 6 and Regex.match?(~r/^ln[a-zA-Z0-9]/i, s)
  end

  def looks_like_psbt?(compact) when is_binary(compact) do
    compact != "" and String.starts_with?(String.downcase(compact), "chnid")
  end

  def decode_address(value) do
    case Segwit.decode_address(value) do
      {:ok, {network, witness_version, witness_program}} ->
        {:ok,
         %{
           tool: :address,
           input_type: "Bitcoin address",
           network: Atom.to_string(network),
           address_type: segwit_type(witness_version, witness_program),
           witness_version: witness_version,
           witness_program_hex: witness_program_hex(witness_program)
         }}

      {:error, reason} ->
        if looks_like_bech32_address?(value) do
          {:error, segwit_error_message(reason)}
        else
          decode_legacy_address(value)
        end
    end
  end

  defp looks_like_bech32_address?(value) when is_binary(value) do
    v = String.downcase(value)
    String.starts_with?(v, "bc1") or String.starts_with?(v, "tb1") or String.starts_with?(v, "bcrt1")
  end

  defp segwit_error_message(:invalid_checksum) do
    "Not a valid Bech32 or Bech32m address: checksum verification failed. Check for typos, omitted characters, or a bad copy. Taproot mainnet addresses usually start with bc1p…"
  end

  defp segwit_error_message(:invalid_network) do
    "Unknown human-readable prefix for this Bech32 address (expected bc, tb, or bcrt for Bitcoin networks)."
  end

  defp segwit_error_message(:invalid_witness_version) do
    "Invalid witness version for this SegWit address encoding."
  end

  defp segwit_error_message(:invalid_program_length) do
    "Witness program length does not match rules for this witness version."
  end

  defp segwit_error_message(:empty_segwit_data) do
    "Decoded SegWit address data is empty or malformed."
  end

  defp segwit_error_message(other) do
    "Could not decode as a SegWit address: #{inspect(other)}"
  end

  defp decode_legacy_address(value) do
    case Base58.decode(value) do
      {:ok, <<prefix::8, payload::binary>>} ->
        {network, type} = legacy_prefix_info(prefix)

        {:ok,
         %{
           tool: :address,
           input_type: "Bitcoin address",
           network: network,
           address_type: type,
           witness_version: "n/a (legacy)",
           witness_program_hex: "n/a (legacy address detected)",
           payload_hex: Base.encode16(payload, case: :lower)
         }}

      _ ->
        {:error, "Unable to decode address. Check the address and try again."}
    end
  end

  defp decode_invoice(value) do
    case Invoice.decode(value) do
      {:ok, invoice} ->
        {:ok,
         %{
           tool: :invoice,
           input_type: "Lightning invoice (BOLT11)",
           network: Atom.to_string(invoice.network),
           amount_sat: format_invoice_sats(invoice.amount_msat),
           amount_btc: format_invoice_btc(invoice.amount_msat),
           description: invoice.description || "(none)",
           destination_pubkey: invoice.destination,
           expiry_seconds: invoice.expiry,
           timestamp: invoice.timestamp,
           payment_hash: invoice.payment_hash
         }}

      {:error, reason} ->
        {:error, "Unable to decode invoice: #{inspect(reason)}"}
    end
  end

  defp decode_psbt(value) do
    case PSBT.decode(value) do
      {:ok, psbt} ->
        inputs = psbt.global.unsigned_tx.inputs || []
        outputs = psbt.global.unsigned_tx.outputs || []

        {:ok,
         %{
           tool: :psbt,
           input_type: "PSBT",
           input_count: length(inputs),
           output_count: length(outputs),
           unsigned_tx_id:
             "Unsigned PSBTs don't have a valid txid until finalized",
           input_derivations: format_input_derivations(psbt.inputs || []),
           output_amounts: format_output_amounts(outputs)
         }}

      {:error, reason} ->
        {:error, "Unable to decode PSBT: #{inspect(reason)}"}
    end
  end

  def rows_for_result(%{tool: :address} = result) do
    [
      {"Input type", Map.get(result, :input_type, "Bitcoin address")},
      {"Network", result.network},
      {"Address type", result.address_type},
      {"Witness version", result.witness_version},
      {"Witness program", result.witness_program_hex}
    ] ++ if(Map.has_key?(result, :payload_hex), do: [{"Payload", result.payload_hex}], else: [])
  end

  def rows_for_result(%{tool: :invoice} = result) do
    [
      {"Input type", Map.get(result, :input_type, "Lightning invoice (BOLT11)")},
      {"Network", result.network},
      {"Amount (sats)", result.amount_sat},
      {"Amount (BTC)", result.amount_btc},
      {"Description", result.description},
      {"Destination pubkey", result.destination_pubkey},
      {"Expiry (seconds)", result.expiry_seconds},
      {"Timestamp", result.timestamp},
      {"Payment hash", result.payment_hash}
    ]
  end

  def rows_for_result(%{tool: :psbt} = result) do
    [
      {"Input type", Map.get(result, :input_type, "PSBT")},
      {"Inputs", result.input_count},
      {"Outputs", result.output_count},
      {"Unsigned tx id", result.unsigned_tx_id},
      {"Input derivation paths", result.input_derivations},
      {"Output amounts (sats)", result.output_amounts}
    ]
  end

  defp segwit_type(0, program) when length(program) == 20, do: "p2wpkh"
  defp segwit_type(0, program) when length(program) == 32, do: "p2wsh"
  defp segwit_type(1, _), do: "p2tr"
  defp segwit_type(version, _), do: "segwit_v#{version}"

  defp witness_program_hex(program), do: program |> :binary.list_to_bin() |> Base.encode16(case: :lower)

  defp legacy_prefix_info(0x00), do: {"mainnet", "p2pkh (legacy address detected)"}
  defp legacy_prefix_info(0x05), do: {"mainnet", "p2sh (legacy address detected)"}
  defp legacy_prefix_info(0x6F), do: {"testnet/regtest", "p2pkh (legacy address detected)"}
  defp legacy_prefix_info(0xC4), do: {"testnet/regtest", "p2sh (legacy address detected)"}
  defp legacy_prefix_info(_), do: {"unknown", "base58 (legacy address detected)"}

  defp format_invoice_sats(nil), do: "n/a"

  defp format_invoice_sats(msat) when is_integer(msat) do
    whole = div(msat, 1000)
    rem_msat = rem(msat, 1000)

    if rem_msat == 0 do
      Integer.to_string(whole)
    else
      frac =
        rem_msat
        |> Integer.to_string()
        |> String.pad_leading(3, "0")
        |> String.trim_trailing("0")

      "#{whole}.#{frac}"
    end
  end

  defp format_invoice_btc(nil), do: "n/a"

  defp format_invoice_btc(msat) when is_integer(msat) do
    msat
    |> Decimal.new()
    |> Decimal.div(Decimal.new(100_000_000_000))
    |> Decimal.round(11)
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
    |> trim_trailing_decimal_zeros()
  end

  defp trim_trailing_decimal_zeros(str) when is_binary(str) do
    if String.contains?(str, ".") do
      str
      |> String.trim_trailing("0")
      |> String.trim_trailing(".")
    else
      str
    end
  end

  defp format_input_derivations(inputs) do
    inputs
    |> Enum.with_index()
    |> Enum.map_join("\n", fn {input, idx} ->
      paths =
        (input.bip32_derivation || [])
        |> Enum.map_join(", ", fn derivation ->
          pubkey = Map.get(derivation, :public_key, "unknown_pubkey")
          path = Map.get(derivation, :derivation, []) |> format_derivation_path()
          "#{pubkey} -> #{path}"
        end)

      if paths == "", do: "input[#{idx}]: none", else: "input[#{idx}]: #{paths}"
    end)
  end

  defp format_derivation_path(path_indexes) do
    "m/" <>
      Enum.map_join(path_indexes, "/", fn idx ->
        if idx >= 0x80000000 do
          "#{idx - 0x80000000}'"
        else
          Integer.to_string(idx)
        end
      end)
  end

  defp format_output_amounts(outputs) do
    outputs
    |> Enum.with_index()
    |> Enum.map_join(", ", fn {output, idx} ->
      "out#{idx}=#{Map.get(output, :value, "unknown")}"
    end)
  end
end
