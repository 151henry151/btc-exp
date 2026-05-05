# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.22] - 2026-05-05

- Bump **`VERSION`** and **`mix.exs`** patch to **`0.4.22`**; align **`CHANGELOG`** **`[0.4.1]`–`[0.4.22]`** headings with one release commit per **`0.4.x`** version (replacing the prior **`0.4.14`** cluster and skipped patch numbers).
- **`TxFlowGraph`** (**`hooks.js`**): stack inputs above and outputs below the transaction cell; draw connectors in an SVG group under node markup; show a monospace **`data-txid`** prefix on the TX cell (**`ExplorerLive`** supplies **`data-txid`**).
- **`ExplorerLive`** transaction **Inputs** / **Outputs**: replace tables with per-row **`dl`** grids for narrower layouts.
- **`LightningGraph`**: insert the focus detail panel as a block sibling after the graph container; remove that panel in **`_cleanup`**.

## [0.4.21] - 2026-05-04

Lightning graph work after **0.4.20** (channels query API, layout, focus mode, in-graph labels); condensed **`README.md`**; GitHub source at **`151henry151/btc-exp`**:

- **`ChannelsCache`**: fetch open channels via **`GET /api/v1/lightning/channels`** (**`public_key`**, **`status=open`**, paginated **`index`**) instead of the broken **`/nodes/{pubkey}/channels`** path; parse peer from **`node.public_key`**; add **`MempoolChannelRows`** tests.
- **`LightningGraph` hook**: widen force-layout spacing; **`normalize_public_key/1`** for ids and edges; client-side link normalization and filtered **`forceLink`**; **`from_data/2`** drops isolated nodes from the payload.
- **Focus mode**: click a node to pin it at the center, BFS ring seeding, radial/link tuning, sticky detail panel (**Clear focus**, background click clears), transient hover when unfocused; curved edges with hover/focus incidence highlighting and dimmed non-incident links; focus-mode hub spokes use gentler curves.
- **In-circle labels**: truncated aliases with font size from node radius and canvas **`measureText`**; legend **Hover for name** / **Click for details**; drop mempool sourcing footnote under the graph.
- **E2E**: **`channels.spec.ts`** asserts focus panel after graph interaction.
- Condense **`README.md`**: add table of contents; merge stack/architecture and trim production/Esplora notes; shorten self-hosting and tests sections.
- Point app footer **GitHub** link at **`151henry151/btc-exp`**; trim **`README`** quick-links table (drop self-referential source row).

## [0.4.20] - 2026-05-03

- **`LightningGraph`**: add **`normalize_public_key/1`** and use it for node **`id`**s and **`from_data/2`** edge endpoints so mempool channel keys match ranking nodes even when casing differs.
- **`ChannelsCache`**: normalize pubkeys for **`top_pubkeys`** and channel-side parsing (legacy node-key path attempts superseded by query-style channels API in later release).
- **`LightningGraph` hook** (**`hooks.js`**): normalize ids/links in the client, filter links to known nodes, seed near-center positions, strengthen **link/center/collide** forces, and draw slightly brighter edges with safe stroke widths.

## [0.4.19] - 2026-05-03

- **`ExplorerLive`** address UTXOs: fix **`async_result`** inner block to use the **list** returned for **`assign_async(:utxos, …)`** (not **`r.utxos`**, which crashed after load and could remount in a loop); show a short **failed** message when the async errors.
- **`UtxoEnrichment`**: coerce **`value`** to integer sats from int/float/binary before **`Decimal`** math; normalize **`"value"`** on enriched maps; make **`total_value_sats/1`** use the same coercion.

## [0.4.18] - 2026-05-03

- **`TxFlowGraph`** (**`hooks.js`**): size the SVG to the container width (minimum **400px**), center the **TX** box with **`ResizeObserver`** reflow, and use thinner grey link strokes (**~0.9–3.1** vs value) with round caps.

## [0.4.17] - 2026-05-03

- **`ExplorerLive`** block dissector: remove the duplicate horizontal color legend under the header hex; keep the single clickable field list with values and byte ranges.

## [0.4.16] - 2026-05-03

- Remove the **`Channels`** header link and the standalone **`ExplorerLive`** **`:channels`** route; Lightning content remains on the home page only.
- Add **`ChannelsRedirectController`**: **`GET /channels`** redirects to **`/`** for old bookmarks.
- Point Playwright **`channels`** specs at the home Lightning block and the redirect.

## [0.4.15] - 2026-05-03

- **`ExplorerLive`** home **Search** / **Decode**: drop the **`sm`** breakpoint grid (which still applied below **640px** CSS width, e.g. zoomed or narrow viewports) in favor of **`inline-flex flex-wrap`** with **`shrink-0`** buttons so width follows content at any zoom.

## [0.4.14] - 2026-05-03

- **`ExplorerLive`** home **Search** / **Decode** row: use a **two-column grid** below **`sm`**, then **`sm:flex sm:w-fit`** with **`sm:w-auto`** buttons so full-width layouts no longer stretch the buttons edge-to-edge.

## [0.4.13] - 2026-05-03

- **`ExplorerLive`**: keep **QR scan** in the nav search row and on the home card at **all** breakpoints (drop **`md:hidden`**) so desktop and laptop webcams can scan.
- **`ExplorerLive`**: size **Search** / **Decode** with **`flex-1`** only below **`sm`**; from **`sm`** use **`flex-none`** so the buttons are not full-width on large screens.

## [0.4.12] - 2026-05-03

- Add **`MempoolFeeDisplay`** and show **3 blk** / **6 blk** on the home mempool fee strip only when their sat/vB estimate differs from **Next**.
- Lay out the fee strip with **`flex flex-wrap`** so two to four cards align when optional targets are hidden.
- Reformat **`ChannelsCache`** Tesla **`get`** call and **`ExplorerLive`** Lightning stats / caption markup (whitespace only).
- **`/channels`**: fetch real channel edges between top-100 nodes via **`Task.async_stream`** in **`ChannelsCache`** (10 concurrent requests, 15s timeout, 400-edge cap sorted by capacity); feed edges into D3 **`forceLink`** in **`LightningGraph`** hook so node position reflects actual network topology.
- **`LightningGraph.from_data/2`**: new function accepting nodes + edges; edges filtered to top-100 set and mapped for D3 consumption.
- Increase canvas height to **500px**; edge line width encodes channel capacity.

## [0.4.11] - 2026-05-03

Address **`assign_async`** UTXOs, dashboard Esplora stepping, Lightning **`statistics/latest`**, **`FeeHeatmap`** / mempool recent, **`/channels`** surface, **`BlockHeader`** dissector, **`MEMPOOL_BASE_URL`**, and related **`ExplorerLive`** layout:

- Run **`assign_async`** for address **UTXOs** from **`load_address/2`** when connected so the async task always tracks the same load path as chain lookup.
- Split **home dashboard** Esplora fetch across **`handle_info`** steps (plus defer initial fetch) so **`phx-change`** decode is not blocked behind long **`get_recent_blocks`** calls.
- **`LightningGraph.summary_stats/1`**: unwrap **`statistics/latest`** **`"latest"`** object so channel/node counts and capacity match mempool.space JSON.
- **`FeeHeatmap`**: pad SVG, **`overflow: visible`**, and edge **`text-anchor`** so fee and time labels are not clipped.
- **`LightningGraph`** hook: **`simulation.on("tick")`** circle positions; tooltip **`div`** positioned with **`d3.pointer`** inside **`relative`** **`#lightning-graph`**.
- **Block dissector**: **`dissector_field_style/1`** legend, colored field rows, hex spans aligned to fields, orange border on the toggle when open.
- **Playwright e2e**: **`decodeSection`** helpers scoped to **Decode locally** (avoid mempool **`dl`**); **`#decode-result`** / **`#decode-error`** hooks where applicable.
- Preserve **`dissector_open`** and **`selected_field`** when **`load_block`** reloads the **same** block map so **`handle_params`** / reconnect does not close the anatomy panel after **`toggle_dissector`**.
- Add **`FeeHeatmap`** hook and **recent mempool** table on the home dashboard; poll **`mempool_recent`** on the existing mempool interval (**120s**) alongside mempool stats.
- Add **`address_utxos`** / **`UtxoEnrichment`** with **`assign_async`** and an **Unspent outputs** section on the address page.
- Add **`/channels`** (**Lightning Network** stats + **`LightningGraph`** D3 hook), **`ChannelsCache`** (mempool.space Lightning API), **`MEMPOOL_BASE_URL`**, and a **Channels** nav link.
- Add block header **`BlockHeader`** module and **Dissect this block** anatomy panel on block pages.
- Document **`MEMPOOL_BASE_URL`** in **`.env.production.example`**; run **`mix assets.deploy`** for hook releases.
- Show **About** in the header only from **`md`** up; on smaller screens link to the static landing page from the footer nav instead.
- Place mobile QR scan controls **beside** the nav search and decode fields (not inside the inputs); use a shared **QR code** outline icon (Heroicons-style) in fixed **40×40** tap targets.

## [0.4.10] - 2026-05-02

- Add single-flight concurrent **`EsploraCache.get_or_fetch`** misses so dashboard viewers do not each run full **`recent_blocks`** pagination against anonymous Esplora limits.
- Raise prod defaults **`ESPLORA_CACHE_TTL_MS`** to **60s** and **`ESPLORA_MIN_REQUEST_INTERVAL_MS`** to **450** ms; load **50** recent blocks on the home dashboard (was **100**).
- Extend **`EsploraCache`** tests and refine **`ExplorerLive`** dashboard/Esplora wiring.

## [0.4.9] - 2026-05-01

- Add **`jsqr`** dependency and **`QrScan`** LiveView hook (**`getUserMedia`**).
- Add mobile-only (**`md:hidden`**) **Scan QR code** camera buttons on the nav search field and **Decode locally** textarea; normalize **`bitcoin:`** / **`lightning:`** URI payloads before filling fields; submit search after a successful nav scan.
- Extend **`ExplorerLive`** tests for QR flows.

## [0.4.8] - 2026-04-30

- Map Esplora **`scriptpubkey_type`** **`op_return`** to chart bucket **`op_return`** and **`OP_RETURN`** flow-node labels in **`OutputClassifier`** / **`TxFlow`**.
- Add **`op_return`** stroke color and **`OP_RETURN`** click/no-navigation handling in **`TxFlowGraph`**; widen vertical spacing when there are four or more outputs; thicken coinbase→TX edges slightly.
- Use **`unknown`** instead of **`non-standard`** for vin prevouts missing address and type in **`TxEnrichment`**.
- Expand **`output_classifier`** / **`tx_flow`** tests.

## [0.4.7] - 2026-04-30

- Remove Live blocks caption line and footer Esplora / Bitcoinex attribution from **`ExplorerLive`**.

## [0.4.6] - 2026-04-30

- Load home dashboard Esplora data only when **`connected?(socket)`** (skip disconnected **`handle_params`** pass).
- Schedule initial **`poll_blocks`** / **`poll_mempool`** after the normal poll intervals instead of **100** ms.

## [0.4.5] - 2026-04-30

- Apply **`mix format`** across **`lib/`**, **`test/`**, and **`config/`** inputs from **`.formatter.exs`**.

## [0.4.4] - 2026-04-30

- Space **`EsploraHttpGate`** by **request start** time (not response completion); raise prod default **`ESPLORA_MIN_REQUEST_INTERVAL_MS`** to **300** ms.
- Retry **`Esplora`** GETs once after **HTTP 429** with **`ESPLORA_429_RETRY_DELAY_MS`** / **`ESPLORA_HTTP_MAX_ATTEMPTS`** (defaults **2000** ms and **2** tries).
- Restore **`EsploraCache`** wrapping on **`recent_blocks`**, **`mempool`**, and **`fee_estimates`**; restore **`EsploraCache.init_table`** in **`Application.start/2`**.
- Document reference nginx limits and Blockstream Explorer API / dashboard policy in **`README.md`**; expand **`.env.production.example`**.
- Extend **`Esplora`** / **`EsploraHttpGate`** tests.

## [0.4.3] - 2026-04-30

- Add **`BitcoinexExplorer.EsploraHttpGate`** (supervised when **`DATA_SOURCE=esplora`**): serialize Esplora HTTP and enforce **`ESPLORA_MIN_REQUEST_INTERVAL_MS`** between completions (prod default **250** ms when unset).
- Route **`Esplora`** **`get_json`** / **`get_raw`** through the gate when the interval is positive.
- Add **`test/esplora_http_gate_test.exs`** and **`application`** supervision coverage.

## [0.4.2] - 2026-04-30

- Replace technical **HTTP 429** LiveView copy with plain-language text for visitors.

## [0.4.1] - 2026-04-30

- Add **`BitcoinexExplorer.EsploraCache`** (ETS, configurable **`ESPLORA_CACHE_TTL_MS`**, prod default **45s**) for **`recent_blocks`**, **`mempool`**, and **`fee-estimates`** Esplora calls.
- Reduce home **`recent_blocks`** request size to **25**; slow LiveView polls (**60s** blocks, **120s** mempool).
- Improve dashboard live-blocks caption in **`ExplorerLive`**; document caching and rate limits in **`README.md`** and **`.env.production.example`**.
- Add **`test/esplora_cache_test.exs`** and extend **`Esplora`** tests.

## [0.4.0] - 2026-04-30

- Add **`BitcoinexExplorer.DataSource`** behaviour; refactor **`ExplorerLive`** and **`BlockHeightController`** to **`DataSource.impl()`**.
- Implement **`BitcoinexExplorer.Esplora`** as behaviour backend (existing HTTP API unchanged).
- Implement **`BitcoinexExplorer.BitcoinRPC`** (Bitcoin Core JSON-RPC + **`BitcoinRpcNormalize`**) and **`BitcoinexExplorer.FulcrumClient`** (Electrum TCP/TLS with backoff).
- Add **`BitcoinexExplorer.Scripthash`** (address → Electrum scripthash); wire **`DATA_SOURCE`** / RPC env vars in **`config/runtime.exs`**; start **`FulcrumClient`** only when **`DATA_SOURCE=rpc`**.
- Add **`BitcoinCoreRpc`** Tesla JSON-RPC client with binary-body decode fallback; add fixtures and ExUnit (Bypass + mock TCP).
- Expand **`README.md`** self-hosting guide for Core + Fulcrum; document RPC-mode address totals (**funded/spent**) not yet implemented and **planned** aggregation; expand **`.env.production.example`**.

## [0.3.1] - 2026-04-30

- Replace top-nav **GitHub** link with **About** pointing at **`https://hromp.com/bitcoinex-explorer/`**; document footer GitHub links in **`README.md`**.
- Note Esplora **upstream dependency** under Known limitations in **`README.md`**.

## [0.3.0] - 2026-04-30

- Add **`BitcoinexExplorer.Esplora`** (Tesla + Hackney) for Esplora-compatible REST calls with **`ESPLORA_BASE_URL`** (**`config/runtime.exs`**).
- Expand **`BitcoinexExplorerWeb.Router`** with **`live_session`** routes: home, **`/block/:hash`**, **`/tx/:txid`**, **`/address/:address`**; **`BlockHeightController`** redirects **`/block/height/:height`** to block hash.
- Extend **`ExplorerLive`** with **`handle_params`**, universal nav search (**`BitcoinexExplorer.Search`**), home live block feed + mempool + fee polls, block/tx/address chain views, Bitcoinex enrichment (**`TxEnrichment`**), script-type counts (**`OutputClassifier`**), flow JSON (**`TxFlow`**).
- Add client hooks (**`d3`**, **`qrcode`**): **`ScriptTypeChart`**, **`TxFlowGraph`**, **`RelativeTime`**, **`AddressQr`** (**`assets/js/hooks.js`**).
- Extract local decode logic to **`BitcoinexExplorer.Decode`**; keep paste-box decode behaviour.
- Add ExUnit tests for **`Esplora`** (Bypass) and **`Search`**; add Playwright **`routes.spec.ts`**.

## [0.2.8] - 2026-04-30

- Tighten **`README.md`** test and limitation wording (forward-looking copy); remove optional screenshot note.
- Rename ExUnit **`renders explorer without tabs`** to **`renders explorer`** (assertions unchanged).

## [0.2.7] - 2026-04-30

- Expand **`README.md`** tests section with per-suite and per-case rationale (**ExUnit** + **Playwright**).
- Rewrite production deployment notes without referencing private infrastructure repos; simplify **`.env.production.example`** comments.
- Format Lightning **amount (sats)** as plain integers and **amount (BTC)** as fixed-point decimals (no scientific notation); use **`Decimal`** for BTC strings.
- Replace PSBT “unsigned tx id” placeholder with an explanation that **unsigned PSBTs don't have a valid txid until finalized**.
- Add **`decimal`** as a direct **`mix.exs`** dependency; document it in **`README.md`**.

## [0.2.5] - 2026-04-30

- Expand **`README.md`** with architecture, auto-detection order, production env summary, and accurate stack versions.
- Add footer links to **hromp.com**, **about** (landing page), **GitHub** (this repo), and make **RiverFinancial/bitcoinex** a clickable upstream link.
- Move combined paste hint into the textarea **label**; remove duplicate subtitle under the title.
- Replace tabbed Address / Invoice / PSBT UI with a **single textarea**; **auto-detect** payload type (BOLT11 if `ln…`, PSBT if base64 magic `cHNid…`, otherwise Bitcoin address decode).
- Show **Input type** row in decoded results; remove **`switch_tab`** LiveView event.
- Add headless Chromium Playwright end-to-end tests under **`e2e/`** (addresses, Lightning invoices, PSBTs, UI edge cases).
- Document **`e2e/`** usage and **`BASE_URL`** path-mounted deployments in **`README.md`**.
