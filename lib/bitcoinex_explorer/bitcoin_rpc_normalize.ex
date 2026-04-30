defmodule BitcoinexExplorer.BitcoinRpcNormalize do
  @moduledoc false

  @spec block_summary(map()) :: map()
  def block_summary(%{} = b) do
    txs = b["tx"] || []

    n_tx =
      case b["nTx"] do
        n when is_integer(n) -> n
        _ -> if(is_list(txs), do: length(txs), else: 0)
      end

    %{
      "id" => b["hash"],
      "height" => b["height"],
      "timestamp" => b["time"],
      "tx_count" => n_tx,
      "size" => b["size"] || 0,
      "weight" => b["weight"] || 0
    }
  end

  @spec block_full(map()) :: map()
  def block_full(%{} = b) do
    Map.merge(block_summary(b), %{
      "difficulty" => b["difficulty"] || 0.0,
      "merkle_root" => b["merkleroot"],
      "previousblockhash" => b["previousblockhash"]
    })
  end

  @spec btc_to_sats(number() | String.t()) :: integer()
  def btc_to_sats(btc) when is_float(btc), do: round(btc * 100_000_000)

  def btc_to_sats(btc) when is_integer(btc), do: btc * 100_000_000

  def btc_to_sats(btc) when is_binary(btc) do
    case Decimal.parse(btc) do
      {d, _} -> d |> Decimal.mult(Decimal.new(100_000_000)) |> Decimal.round(0) |> Decimal.to_integer()
      :error -> 0
    end
  end

  def btc_to_sats(%Decimal{} = btc) do
    btc |> Decimal.mult(Decimal.new(100_000_000)) |> Decimal.round(0) |> Decimal.to_integer()
  end

  @spec core_script_type_to_esplora(String.t() | nil) :: String.t()
  def core_script_type_to_esplora(nil), do: "unknown"

  def core_script_type_to_esplora(t) when is_binary(t) do
    case String.downcase(t) do
      "pubkeyhash" -> "p2pkh"
      "scripthash" -> "p2sh"
      "witness_v0_keyhash" -> "v0_p2wpkh"
      "witness_v0_scripthash" -> "v0_p2wsh"
      "witness_v1_taproot" -> "v1_p2tr"
      "pubkey" -> "p2pk"
      "multisig" -> "multisig"
      other -> other
    end
  end

  @spec normalize_vout(map()) :: map()
  def normalize_vout(%{"value" => btc} = vo) do
    spk = vo["scriptPubKey"] || %{}
    addr = extract_address(spk)

    %{
      "value" => btc_to_sats(btc),
      "scriptpubkey_address" => addr,
      "scriptpubkey_type" => core_script_type_to_esplora(spk["type"]),
      "scriptpubkey" => spk["hex"] || ""
    }
  end

  defp extract_address(spk) do
    case spk["address"] do
      a when is_binary(a) -> a
      [a | _] when is_binary(a) -> a
      _ -> ""
    end
  end

  @spec normalize_vin(map(), map()) :: map()
  def normalize_vin(%{"coinbase" => cb} = vin, _prevouts) do
    %{
      "txid" => "",
      "vout" => 4_294_967_295,
      "scriptsig" => cb,
      "sequence" => vin["sequence"] || 0,
      "is_coinbase" => true,
      "prevout" => nil,
      "witness" => vin["txinwitness"] || []
    }
  end

  def normalize_vin(vin, prevouts) do
    txid = vin["txid"]
    vout_i = vin["vout"] || 0
    prev = Map.get(prevouts, {String.downcase(to_string(txid)), vout_i})

    %{
      "txid" => txid,
      "vout" => vout_i,
      "scriptsig" => get_in(vin, ["scriptSig", "hex"]) || "",
      "sequence" => vin["sequence"] || 0,
      "is_coinbase" => false,
      "prevout" => prev,
      "witness" => vin["txinwitness"] || []
    }
  end

  @spec tx_from_core(map(), map(), map()) :: map()
  def tx_from_core(%{} = decoded, prevouts, status_override \\ %{}) do
    vin = Enum.map(decoded["vin"] || [], &normalize_vin(&1, prevouts))
    vout = Enum.map(decoded["vout"] || [], &normalize_vout/1)

    fee =
      case decoded["fee"] do
        f when is_number(f) -> btc_to_sats(f)
        _ -> infer_fee(vin, vout)
      end

    status =
      if map_size(status_override) > 0 do
        status_override
      else
        status_from_core_decoded(decoded)
      end

    weight = decoded["weight"] || max(div((decoded["vsize"] || decoded["size"] || 0) * 4 + 3, 4), 1)

    %{
      "txid" => decoded["txid"],
      "version" => decoded["version"] || 1,
      "locktime" => decoded["locktime"] || 0,
      "size" => decoded["size"] || 0,
      "weight" => weight,
      "vsize" => decoded["vsize"] || max(div(weight + 3, 4), 1),
      "fee" => fee,
      "vin" => vin,
      "vout" => vout,
      "status" => status
    }
  end

  defp infer_fee(vin, vout) do
    in_sum =
      vin
      |> Enum.filter(&(&1["is_coinbase"] != true))
      |> Enum.map(fn v -> Map.get(v["prevout"] || %{}, "value", 0) end)
      |> Enum.sum()

    out_sum = Enum.map(vout, & &1["value"]) |> Enum.sum()
    max(in_sum - out_sum, 0)
  end

  defp status_from_core_decoded(d) do
    conf = d["confirmations"]

    if is_integer(conf) and conf > 0 do
      %{
        "confirmed" => true,
        "block_height" => d["blockheight"],
        "block_hash" => d["blockhash"]
      }
    else
      %{"confirmed" => false, "block_height" => nil, "block_hash" => nil}
    end
  end

  @spec status_from_history_height(integer()) :: map()
  def status_from_history_height(0),
    do: %{"confirmed" => false, "block_height" => nil, "block_hash" => nil}

  def status_from_history_height(height) when is_integer(height) and height > 0 do
    %{"confirmed" => true, "block_height" => height, "block_hash" => nil}
  end

  def mempool_from_core(%{} = i) do
    total_fee_btc = Map.get(i, "total_fee", 0)
    total_fee = if is_float(total_fee_btc), do: btc_to_sats(total_fee_btc), else: total_fee_btc

    %{
      "count" => Map.get(i, "size", 0),
      "vsize" => Map.get(i, "bytes", 0),
      "total_fee" => total_fee
    }
  end

  @spec fee_estimates_from_core(%{optional(String.t() | integer()) => map()}) :: map()
  def fee_estimates_from_core(results_by_target) when is_map(results_by_target) do
    results_by_target
    |> Enum.flat_map(fn {k, v} ->
      key = if is_integer(k), do: Integer.to_string(k), else: to_string(k)

      case v do
        %{"feerate" => rate} when is_number(rate) and rate > 0 ->
          sat_vb = rate * 100_000_000 / 1000
          [{key, Float.round(sat_vb * 1.0, 2)}]

        _ ->
          []
      end
    end)
    |> Map.new()
  end
end
