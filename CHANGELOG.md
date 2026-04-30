# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.2] - 2026-04-30

- Replace technical **HTTP 429** LiveView copy with plain-language text for visitors.

## [0.4.1] - 2026-04-30

- Add **`BitcoinexExplorer.EsploraCache`** (ETS, configurable **`ESPLORA_CACHE_TTL_MS`**, prod default **45s**) for **`recent_blocks`**, **`mempool`**, and **`fee-estimates`** Esplora calls.
- Reduce home **`recent_blocks`** request size to **25**; slow LiveView polls (**60s** blocks, **120s** mempool).
- Improve dashboard live-blocks caption in **`ExplorerLive`**; document caching and rate limits in **`README.md`** and **`.env.production.example`**.

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

## [0.2.6] - 2026-04-30

- Format Lightning **amount (sats)** as plain integers and **amount (BTC)** as fixed-point decimals (no scientific notation); use **`Decimal`** for BTC strings.
- Replace PSBT “unsigned tx id” placeholder with an explanation that **unsigned PSBTs don't have a valid txid until finalized**.
- Add **`decimal`** as a direct **`mix.exs`** dependency; document it in **`README.md`**.

## [0.2.5] - 2026-04-30

- Expand **`README.md`** with architecture, auto-detection order, production env summary, and accurate stack versions.

## [0.2.4] - 2026-04-30

- Add footer links to **hromp.com**, **about** (landing page), **GitHub** (this repo), and make **RiverFinancial/bitcoinex** a clickable upstream link.

## [0.2.3] - 2026-04-30

- Move combined paste hint into the textarea **label**; remove duplicate subtitle under the title.

## [0.2.2] - 2026-04-30

- Replace tabbed Address / Invoice / PSBT UI with a **single textarea**; **auto-detect** payload type (BOLT11 if `ln…`, PSBT if base64 magic `cHNid…`, otherwise Bitcoin address decode).
- Show **Input type** row in decoded results; remove **`switch_tab`** LiveView event.

## [0.2.1] - 2026-04-30

- Add headless Chromium Playwright end-to-end tests under **`e2e/`** (addresses, Lightning invoices, PSBTs, UI edge cases).
- Document **`e2e/`** usage and **`BASE_URL`** path-mounted deployments in **`README.md`**.
