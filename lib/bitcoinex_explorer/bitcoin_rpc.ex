defmodule BitcoinexExplorer.BitcoinRPC do
  @moduledoc """
  `BitcoinexExplorer.DataSource` backed by Bitcoin Core JSON-RPC and Fulcrum (Electrum protocol).

  Configure via `DATA_SOURCE=rpc` and related env vars (see README).
  """

  @behaviour BitcoinexExplorer.DataSource

  alias BitcoinexExplorer.{
    BitcoinCoreRpc,
    BitcoinRpcNormalize,
    FulcrumClient,
    Scripthash
  }

  @fee_targets [1, 3, 6, 144, 504, 1008]
  @address_tx_page 25

  @impl true
  def get_recent_blocks(count) when is_integer(count) and count > 0 do
    case BitcoinCoreRpc.call("getblockchaininfo", []) do
      {:ok, %{"blocks" => tip}} when is_integer(tip) ->
        heights =
          0..(count - 1)//1
          |> Enum.map(&Kernel.-(tip, &1))
          |> Enum.filter(&(&1 >= 0))

        fetch_summaries_for_heights(heights, [])

      {:ok, _} ->
        {:error, :invalid_tip}

      err ->
        err
    end
  end

  defp fetch_summaries_for_heights([], acc), do: {:ok, Enum.reverse(acc)}

  defp fetch_summaries_for_heights([h | rest], acc) do
    with {:ok, hash} <- BitcoinCoreRpc.call("getblockhash", [h]),
         {:ok, block} <- BitcoinCoreRpc.call("getblock", [hash, 1]) do
      fetch_summaries_for_heights(rest, [BitcoinRpcNormalize.block_summary(block) | acc])
    else
      {:error, _} = err -> err
    end
  end

  @impl true
  def get_block(hash) when is_binary(hash) do
    h = String.downcase(hash)

    case BitcoinCoreRpc.call("getblock", [h, 1]) do
      {:ok, block} -> {:ok, BitcoinRpcNormalize.block_full(block)}
      {:error, {:rpc_error, -5, _}} -> {:error, :not_found}
      err -> err
    end
  end

  @impl true
  def get_block_by_height(height) when is_integer(height) and height >= 0 do
    case get_block_hash_at_height(height) do
      {:ok, hash} -> get_block(hash)
      err -> err
    end
  end

  @impl true
  def get_block_hash_at_height(height) when is_integer(height) and height >= 0 do
    case BitcoinCoreRpc.call("getblockhash", [height]) do
      {:ok, hash} when is_binary(hash) ->
        {:ok, String.downcase(hash)}

      {:error, {:rpc_error, -8, _}} ->
        {:error, :not_found}

      {:error, {:rpc_error, -1, msg}} ->
        if String.contains?(msg, "out of range"),
          do: {:error, :not_found},
          else: {:error, {:rpc_error, -1, msg}}

      err ->
        err
    end
  end

  @impl true
  def get_block_txs(hash, start_index)
      when is_binary(hash) and is_integer(start_index) and start_index >= 0 do
    h = String.downcase(hash)

    case BitcoinCoreRpc.call("getblock", [h, 2]) do
      {:ok, block} ->
        txs = List.wrap(block["tx"] || [])
        chunk = txs |> Enum.drop(start_index) |> Enum.take(25)
        {:ok, Enum.map(chunk, &summarize_block_tx/1)}

      {:error, {:rpc_error, -5, _}} ->
        {:error, :not_found}

      err ->
        err
    end
  end

  defp summarize_block_tx(%{} = decoded) do
    decoded
    |> BitcoinRpcNormalize.tx_from_core(%{}, %{})
    |> trim_tx_for_block_list()
  end

  defp trim_tx_for_block_list(tx) do
    vin =
      Enum.map(tx["vin"] || [], fn v ->
        if v["is_coinbase"] do
          Map.take(v, ["is_coinbase", "scriptsig", "sequence", "witness"])
        else
          Map.take(v, ["txid", "vout", "scriptsig", "sequence", "witness", "is_coinbase"])
        end
      end)

    %{tx | "vin" => vin}
  end

  defp fetch_prevouts_for_tx(decoded) do
    decoded["vin"]
    |> List.wrap()
    |> Enum.reject(&Map.has_key?(&1, "coinbase"))
    |> Enum.reduce(%{}, fn vin, acc ->
      tid = String.downcase(to_string(vin["txid"]))
      idx = vin["vout"] || 0
      key = {tid, idx}

      if Map.has_key?(acc, key) do
        acc
      else
        case BitcoinCoreRpc.call("getrawtransaction", [tid, true]) do
          {:ok, prev_dec} ->
            prev_vouts = prev_dec["vout"] || []
            pv = Enum.at(prev_vouts, idx)

            prevout =
              if is_map(pv) do
                BitcoinRpcNormalize.normalize_vout(pv)
              else
                nil
              end

            Map.put(acc, key, prevout)

          _ ->
            Map.put(acc, key, nil)
        end
      end
    end)
  end

  @impl true
  def get_tx(txid) when is_binary(txid) do
    t = String.downcase(txid)

    case BitcoinCoreRpc.call("getrawtransaction", [t, true]) do
      {:ok, decoded} ->
        prevouts = fetch_prevouts_for_tx(decoded)
        {:ok, BitcoinRpcNormalize.tx_from_core(decoded, prevouts, %{})}

      {:error, {:rpc_error, -5, _}} ->
        {:error, :not_found}

      err ->
        err
    end
  end

  @impl true
  def get_address(addr) when is_binary(addr) do
    with {:ok, sh} <- Scripthash.from_address(addr),
         {:ok, bal} <- FulcrumClient.call("blockchain.scripthash.get_balance", [sh]),
         {:ok, hist} <- FulcrumClient.call("blockchain.scripthash.get_history", [sh]) do
      confirmed = Map.get(bal, "confirmed", 0)
      unconfirmed = Map.get(bal, "unconfirmed", 0)

      {:ok,
       %{
         "chain_stats" => %{
           "funded_txo_sum" => confirmed,
           "spent_txo_sum" => 0,
           "tx_count" => length(List.wrap(hist))
         },
         "mempool_stats" => %{
           "funded_txo_sum" => unconfirmed,
           "spent_txo_sum" => 0,
           "tx_count" => 0
         }
       }}
    else
      {:error, {:fulcrum_error, %{"message" => msg}}} ->
        {:error, {:fulcrum_error, msg}}

      {:error, _} = err ->
        err
    end
  end

  @impl true
  def get_address_txs(addr, last_seen_txid) when is_binary(addr) do
    with {:ok, sh} <- Scripthash.from_address(addr),
         {:ok, hist} <- FulcrumClient.call("blockchain.scripthash.get_history", [sh]) do
      ordered = order_history(List.wrap(hist))
      tx_entries = paginate_history(ordered, last_seen_txid, @address_tx_page)

      txs =
        Enum.reduce(tx_entries, [], fn entry, acc ->
          txid = Map.get(entry, "tx_hash") || Map.get(entry, :tx_hash)
          height = Map.get(entry, "height") || Map.get(entry, :height) || 0

          case fetch_normalized_address_tx(txid, height) do
            {:ok, tx} -> [tx | acc]
            {:error, _} -> acc
          end
        end)

      {:ok, Enum.reverse(txs)}
    else
      {:error, _} = err -> err
    end
  end

  defp order_history(hist) do
    {mempool, confirmed} = Enum.split_with(hist, &(height_of(&1) == 0))

    mempool_ordered = Enum.reverse(mempool)
    confirmed_ordered = Enum.sort_by(confirmed, &height_of(&1), :desc)
    mempool_ordered ++ confirmed_ordered
  end

  defp height_of(entry), do: Map.get(entry, "height") || Map.get(entry, :height) || 0

  defp paginate_history(ordered, nil, limit), do: Enum.take(ordered, limit)

  defp paginate_history(ordered, last_txid, limit) do
    idx =
      Enum.find_index(ordered, fn e ->
        tid = Map.get(e, "tx_hash") || Map.get(e, :tx_hash)
        String.downcase(to_string(tid)) == String.downcase(last_txid)
      end)

    case idx do
      nil -> []
      i -> ordered |> Enum.drop(i + 1) |> Enum.take(limit)
    end
  end

  defp fetch_normalized_address_tx(txid, height) do
    status = BitcoinRpcNormalize.status_from_history_height(height)

    case BitcoinCoreRpc.call("getrawtransaction", [String.downcase(txid), true]) do
      {:ok, decoded} ->
        prevouts = fetch_prevouts_for_tx(decoded)
        {:ok, BitcoinRpcNormalize.tx_from_core(decoded, prevouts, status)}

      {:error, {:rpc_error, -5, _}} ->
        {:error, :not_found}

      err ->
        err
    end
  end

  @impl true
  def get_mempool do
    case BitcoinCoreRpc.call("getmempoolinfo", []) do
      {:ok, info} -> {:ok, BitcoinRpcNormalize.mempool_from_core(info)}
      err -> err
    end
  end

  @impl true
  def get_fee_estimates do
    results =
      for t <- @fee_targets do
        case BitcoinCoreRpc.call("estimatesmartfee", [t, "ECONOMICAL"]) do
          {:ok, %{"feerate" => fr}} -> {Integer.to_string(t), %{"feerate" => fr}}
          {:ok, other} -> {Integer.to_string(t), other}
          {:error, _} -> {Integer.to_string(t), %{}}
        end
      end

    {:ok, BitcoinRpcNormalize.fee_estimates_from_core(Map.new(results))}
  end
end
