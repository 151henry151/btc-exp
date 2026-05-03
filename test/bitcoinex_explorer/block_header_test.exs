defmodule BitcoinexExplorer.BlockHeaderTest do
  use ExUnit.Case, async: true

  alias BitcoinexExplorer.BlockHeader

  @genesis_hex "0100000000000000000000000000000000000000000000000000000000000000000000003ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a29ab5f49ffff001d1dac2b7c"

  @genesis_block_map %{
    "version" => 1,
    "previousblockhash" => String.duplicate("0", 64),
    "merkle_root" => "4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b",
    "timestamp" => 1_231_006_505,
    "bits" => "1d00ffff",
    "nonce" => 2_083_236_893
  }

  test "parse/1 genesis block version is 1" do
    assert {:ok, fields} = BlockHeader.parse(@genesis_hex)
    version_field = Enum.find(fields, &(&1.name == "version"))
    assert version_field.value == 1
  end

  test "parse/1 genesis block nonce matches known value" do
    assert {:ok, fields} = BlockHeader.parse(@genesis_hex)
    nonce_field = Enum.find(fields, &(&1.name == "nonce"))
    assert nonce_field.value == 2_083_236_893
  end

  test "parse/1 genesis block timestamp matches known value" do
    assert {:ok, fields} = BlockHeader.parse(@genesis_hex)
    ts_field = Enum.find(fields, &(&1.name == "timestamp"))
    assert ts_field.value == 1_231_006_505
  end

  test "parse/1 genesis prev_block is all zeros" do
    assert {:ok, fields} = BlockHeader.parse(@genesis_hex)
    prev = Enum.find(fields, &(&1.name == "prev_block"))
    assert prev.value == String.duplicate("0", 64)
  end

  test "parse/1 returns 6 fields" do
    assert {:ok, fields} = BlockHeader.parse(@genesis_hex)
    assert length(fields) == 6
  end

  test "parse/1 returns wrong_length for short hex" do
    assert {:error, :wrong_length} = BlockHeader.parse(String.duplicate("a", 159))
  end

  test "parse/1 returns invalid_hex for non-hex string" do
    assert {:error, :invalid_hex} = BlockHeader.parse(String.duplicate("z", 160))
  end

  test "target_from_bits/1 genesis bits returns 64-char hex" do
    result = BlockHeader.target_from_bits(486_604_799)
    assert is_binary(result)
    assert String.length(result) == 64
    assert result =~ ~r/^[0-9a-f]+$/
    assert String.starts_with?(result, "00000000ffff")
  end

  test "encode_from_block_map/1 then parse/1 round-trips cleanly" do
    assert {:ok, hex} = BlockHeader.encode_from_block_map(@genesis_block_map)
    assert {:ok, fields} = BlockHeader.parse(hex)
    version = Enum.find(fields, &(&1.name == "version"))
    nonce = Enum.find(fields, &(&1.name == "nonce"))
    assert version.value == 1
    assert nonce.value == 2_083_236_893
  end
end
