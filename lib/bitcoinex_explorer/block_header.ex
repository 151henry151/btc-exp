defmodule BitcoinexExplorer.BlockHeader do
  @moduledoc """
  Encodes and parses Bitcoin block headers from wire format.
  Uses Elixir binary pattern matching on the 80-byte header structure.
  """

  import Bitwise

  @spec encode_from_block_map(map()) ::
          {:ok, String.t()} | {:error, :missing_fields | :invalid_data}
  def encode_from_block_map(%{} = m) do
    with {:ok, version} <- fetch_any_int(m, "version"),
         {:ok, prev_hex} <- fetch_hex64(m, "previousblockhash"),
         {:ok, merkle_hex} <- fetch_hex64(m, "merkle_root"),
         {:ok, timestamp} <- fetch_any_int(m, "timestamp"),
         {:ok, bits_int} <- parse_bits_field(m),
         {:ok, nonce} <- fetch_any_int(m, "nonce"),
         {:ok, prev_bin} <- hex32_decode(prev_hex),
         {:ok, merkle_bin} <- hex32_decode(merkle_hex) do
      prev_wire = reverse_bin(prev_bin)
      merkle_wire = reverse_bin(merkle_bin)

      raw =
        <<version::little-signed-32, prev_wire::binary-32, merkle_wire::binary-32,
          timestamp::little-32, bits_int::little-32, nonce::little-32>>

      {:ok, Base.encode16(raw, case: :lower)}
    else
      _ -> {:error, :invalid_data}
    end
  rescue
    _ -> {:error, :invalid_data}
  end

  defp fetch_any_int(m, key) do
    case Map.get(m, key) do
      n when is_integer(n) -> {:ok, n}
      _ -> {:error, :missing_fields}
    end
  end

  defp fetch_hex64(m, key) do
    case Map.get(m, key) do
      h when is_binary(h) and byte_size(h) == 64 ->
        if Regex.match?(~r/^[0-9a-fA-F]+$/, h),
          do: {:ok, String.downcase(h)},
          else: {:error, :invalid_data}

      _ ->
        {:error, :missing_fields}
    end
  end

  defp parse_bits_field(m) do
    case Map.get(m, "bits") do
      n when is_integer(n) and n >= 0 ->
        {:ok, n}

      h when is_binary(h) ->
        case Base.decode16(String.downcase(h), case: :mixed) do
          {:ok, bin} when byte_size(bin) == 4 ->
            <<compact::little-32>> = bin
            {:ok, compact}

          _ ->
            {:error, :invalid_data}
        end

      _ ->
        {:error, :missing_fields}
    end
  end

  defp hex32_decode(hex) do
    case Base.decode16(hex, case: :mixed) do
      {:ok, bin} when byte_size(bin) == 32 -> {:ok, bin}
      _ -> {:error, :invalid_data}
    end
  end

  defp reverse_bin(bin),
    do: bin |> :binary.bin_to_list() |> Enum.reverse() |> :binary.list_to_bin()

  @spec parse(String.t()) :: {:ok, [map()]} | {:error, atom()}
  def parse(hex) when byte_size(hex) != 160, do: {:error, :wrong_length}

  def parse(hex) when is_binary(hex) do
    case safe_decode_hex(hex) do
      {:error, reason} ->
        {:error, reason}

      {:ok, raw} ->
        case raw do
          <<version::little-signed-32, prev_hash::binary-32, merkle_root::binary-32,
            timestamp::little-32, bits::little-32, nonce::little-32>> ->
            {:ok,
             [
               field(
                 :version,
                 "Version",
                 "0–3",
                 4,
                 <<version::little-signed-32>>,
                 version,
                 "Block version number, signaling which protocol upgrade rules apply to this block."
               ),
               field(
                 :prev_block,
                 "Previous block hash",
                 "4–35",
                 32,
                 prev_hash,
                 reverse_and_hex(prev_hash),
                 "SHA256d hash of the previous block header. This is what forms the chain — each block commits to its predecessor."
               ),
               field(
                 :merkle_root,
                 "Merkle root",
                 "36–67",
                 32,
                 merkle_root,
                 reverse_and_hex(merkle_root),
                 "Root of the Merkle tree of all transactions in this block. Any change to any transaction changes this value."
               ),
               field(
                 :timestamp,
                 "Timestamp",
                 "68–71",
                 4,
                 <<timestamp::little-32>>,
                 timestamp,
                 "Unix timestamp (seconds since 1970-01-01 UTC) when the miner began hashing this block header."
               ),
               field_bits(bits),
               field(
                 :nonce,
                 "Nonce",
                 "76–79",
                 4,
                 <<nonce::little-32>>,
                 nonce,
                 "A 32-bit number miners increment repeatedly, changing the block header hash, searching for one below the target."
               )
             ]}

          _ ->
            {:error, :invalid_pattern}
        end
    end
  end

  defp field(name, display, bytes, byte_count, raw_bin, value, description)
       when is_binary(raw_bin) do
    raw_hex = binary_to_hex(raw_bin)

    %{
      name: to_string(name),
      display_name: display,
      bytes: bytes,
      byte_count: byte_count,
      raw_hex: raw_hex,
      value: value,
      description: description
    }
  end

  defp field_bits(bits_int) do
    hex_val = bits_int |> Integer.to_string(16) |> String.downcase()

    %{
      name: "bits",
      display_name: "Bits (difficulty target)",
      bytes: "72–75",
      byte_count: 4,
      raw_hex: binary_to_hex(<<bits_int::little-32>>),
      value: String.upcase(hex_val),
      description:
        "Compact encoding of the difficulty target. The hash of a valid block must be numerically less than this target."
    }
  end

  defp safe_decode_hex(hex) do
    case Base.decode16(String.trim(hex), case: :mixed) do
      {:ok, raw} when byte_size(raw) == 80 -> {:ok, raw}
      {:ok, _} -> {:error, :wrong_length}
      :error -> {:error, :invalid_hex}
    end
  rescue
    _ -> {:error, :invalid_hex}
  end

  defp binary_to_hex(bin), do: Base.encode16(bin, case: :lower)

  defp reverse_and_hex(binary) when byte_size(binary) == 32 do
    binary |> reverse_bin() |> binary_to_hex()
  end

  @spec target_from_bits(integer()) :: String.t()
  def target_from_bits(bits_int) when is_integer(bits_int) do
    exponent = band(bsr(bits_int, 24), 0xFF)
    mantissa = band(bits_int, 0x00FFFFFF)

    target = mantissa * Integer.pow(256, exponent - 3)

    Integer.to_string(target, 16)
    |> String.downcase()
    |> String.pad_leading(64, "0")
  end
end
