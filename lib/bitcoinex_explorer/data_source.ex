defmodule BitcoinexExplorer.DataSource do
  @moduledoc """
  Pluggable chain/indexer backend contract. LiveView and controllers call
  `BitcoinexExplorer.DataSource.impl()` and invoke callbacks on the returned module.

  All callbacks return `{:ok, term()} | {:error, term()}`. Error `:not_found` indicates
  the resource does not exist.

  ## Shared map shapes (Esplora-compatible keys)

  Implementations must normalize to these shapes so the UI stays backend-agnostic.

  ### Block summary (`get_recent_blocks` list elements)

  String keys: `"id"` (block hash hex), `"height"`, `"timestamp"` (unix int),
  `"tx_count"`, `"size"` (bytes), optionally `"weight"`.

  ### Full block (`get_block`, `get_block_by_height`)

  `"id"`, `"height"`, `"timestamp"`, `"tx_count"`, `"size"`, `"weight"`,
  `"difficulty"` (float), `"merkle_root"`, `"previousblockhash"`.

  ### Transaction (`get_tx`, elements of `get_block_txs`, `get_address_txs`)

  `"txid"`, `"version"`, `"locktime"`, `"size"`, `"weight"`, `"fee"` (sats int),
  `"vin"` — each vin: `"txid"`, `"vout"`, `"scriptsig"` (hex), `"sequence"`,
  `"is_coinbase"` (boolean), optional `"witness"` (list of hex strings),
  `"prevout"` — map with `"scriptpubkey_address"`, `"scriptpubkey_type"`,
  `"value"` (sats int), or omit/`nil` for coinbase spends handled by enrichment.

  `"vout"` — each: `"value"` (sats int), `"scriptpubkey_address"`, `"scriptpubkey_type"`
  (Esplora-style: `"p2pkh"`, `"p2sh"`, `"v0_p2wpkh"`, `"v0_p2wsh"`, `"v1_p2tr"`, …),
  `"scriptpubkey"` (hex).

  `"status"` — `%{"confirmed" => boolean, "block_height" => int | nil, "block_hash" => binary | nil}`.

  ### Address info (`get_address`)

  `"chain_stats"` — `%{"funded_txo_sum" => int, "spent_txo_sum" => int, "tx_count" => int}`.

  `"mempool_stats"` — same keys for unconfirmed UTXO view; use zeros when unknown.

  ### Mempool (`get_mempool`)

  `"count"` (tx count), `"vsize"` (virtual bytes total), `"total_fee"` (sats int).

  ### Fee estimates (`get_fee_estimates`)

  Map with **string** keys `"1"`, `"3"`, `"6"`, `"144"`, `"504"`, `"1008"` → float sat/vB
  (omit targets Core cannot estimate).

  ### Address tx history (`get_address_txs`)

  Ordered newest-first (same as Esplora). Pagination: pass `last_seen_txid` as the
  **`txid` of the last tx`** currently shown; backend returns the **next** page.
  Use `nil` for the first page.

  On partial failures fetching individual txs, implementations may skip failed rows
  and still return `{:ok, txs}` (documented for RPC backend).
  """

  @type block_summary :: %{String.t() => term()}
  @type block_full :: %{String.t() => term()}
  @type tx_map :: %{String.t() => term()}
  @type address_info :: %{String.t() => term()}
  @type mempool_info :: %{String.t() => term()}
  @type fee_estimates_map :: %{String.t() => float()}

  @doc "Configured backend module (`BitcoinexExplorer.Esplora` or `BitcoinexExplorer.BitcoinRPC`)."
  def impl do
    Application.fetch_env!(:bitcoinex_explorer, :data_source_module)
  end

  @callback get_recent_blocks(count :: pos_integer()) ::
              {:ok, [block_summary()]} | {:error, term()}

  @callback get_block(hash :: String.t()) ::
              {:ok, block_full()} | {:error, term()}

  @callback get_block_by_height(height :: non_neg_integer()) ::
              {:ok, block_full()} | {:error, term()}

  @callback get_block_hash_at_height(height :: non_neg_integer()) ::
              {:ok, String.t()} | {:error, term()}

  @callback get_block_txs(hash :: String.t(), start_index :: non_neg_integer()) ::
              {:ok, [tx_map()]} | {:error, term()}

  @callback get_tx(txid :: String.t()) ::
              {:ok, tx_map()} | {:error, term()}

  @callback get_address(address :: String.t()) ::
              {:ok, address_info()} | {:error, term()}

  @callback get_address_txs(address :: String.t(), last_seen_txid :: String.t() | nil) ::
              {:ok, [tx_map()]} | {:error, term()}

  @callback get_mempool() ::
              {:ok, mempool_info()} | {:error, term()}

  @callback get_fee_estimates() ::
              {:ok, fee_estimates_map()} | {:error, term()}
end
