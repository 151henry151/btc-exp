# Bitcoinex Explorer

**Bitcoin block explorer** plus a **Bitcoinex**-powered inspector: live blocks/mempool/fee estimates from a pluggable chain backend (**Esplora** HTTP by default, or **Bitcoin Core + Fulcrum** when self-hosted), deep-linked **block / transaction / address** pages, D3 visualizations, and the original **single-field** decode for addresses, **BOLT11** invoices, and **PSBT** payloads. Built with **[River Financial’s Bitcoinex](https://github.com/RiverFinancial/bitcoinex)** on **Elixir / Phoenix LiveView**.

| Resource | URL |
|----------|-----|
| **Live app** | [https://hromp.com/btcexp/](https://hromp.com/btcexp/) |
| **Landing page** (marketing / architecture overview) | [https://hromp.com/bitcoinex-explorer/](https://hromp.com/bitcoinex-explorer/) |
| **Source** | [https://github.com/151henry151/bitcoinex-explorer](https://github.com/151henry151/bitcoinex-explorer) |

The running app’s top nav links **About** to that landing page; **GitHub** / upstream Bitcoinex links remain in the page footer.

Licensed under the **MIT License** — see [`LICENSE`](LICENSE).

---

## What it does

### Chain explorer (`BitcoinexExplorer.DataSource`)

- **Home** — Recent blocks (poll), mempool stats (poll), fee estimates; universal **search** bar (txid / block hash / height / address / invoice / PSBT).
- **`/block/:hash`** — Header metadata, paginated txs, **script-type distribution** chart (Bitcoinex-classified outputs).
- **`/tx/:txid`** — Fees, confirmations, **flow diagram** (D3), input/output tables with **Bitcoinex enrichment** (network, type, witness program, payload).
- **`/address/:address`** — Balance and history from the configured backend (Esplora HTTP or Bitcoin Core + Fulcrum); **QR** code hook; Bitcoinex decode summary at top.
- **`/block/height/:height`** — Redirects to **`/block/:hash`** via **`BlockHeightController`**.

### Local decode (Bitcoinex only)

On the home page, **Decode locally** keeps the original behaviour: one debounced textarea; **no** chain lookup.

1. **Lightning (BOLT11)** — trimmed input matches `ln…` (length ≥ 6).
2. **PSBT** — whitespace stripped; base64 begins with PSBT magic (`cHNid…`).
3. **Bitcoin address** — **SegWit** then **legacy Base58**.

Universal **search** uses **`BitcoinexExplorer.Search`**: **64-char hex** tries **tx** then **block**; numeric string → **height redirect**; valid address → **address page**; otherwise falls through to the same local decode path.

---

## Architecture (technical)

| Layer | Details |
|-------|---------|
| **HTTP / WebSocket** | [**Bandit**](https://hex.pm/packages/bandit) serves Phoenix. [**LiveView**](https://hexdocs.pm/phoenix_live_view/) **`ExplorerLive`** uses **`handle_params/3`** for **`live_session`** routes (`router.ex`). |
| **Chain data** | **`BitcoinexExplorer.DataSource.impl()`** selects **`BitcoinexExplorer.Esplora`** (Esplora-compatible **`ESPLORA_BASE_URL`**, default Blockstream) or **`BitcoinexExplorer.BitcoinRPC`** (Bitcoin Core JSON-RPC + Fulcrum Electrum). See **Self-hosting with a Bitcoin full node** below. |
| **Routing / search** | **`BitcoinexExplorer.Search`** classifies nav input; **`push_patch`** / **`redirect`** keep URLs shareable. |
| **Bitcoinex** | **`BitcoinexExplorer.Decode`** (local decode); **`TxEnrichment`**, **`OutputClassifier`**, **`TxFlow`** combine normalized chain JSON with Segwit/Base58 decoders. |
| **UI** | Tailwind; **D3** stacked bar + tx flow (**`assets/js/hooks.js`**); **qrcode** for address QR; relative time hook. |
| **Assets** | Tailwind + esbuild (**`npm`** deps under **`assets/`**); **`mix assets.deploy`** → **`priv/static/`**. |
| **Root layout** | **`live_view_root_only`** — no nested app layout (`bitcoinex_explorer_web.ex`). |

Production can mount under a **path prefix** (e.g. **`/btcexp`**): set **`PHX_PATH`**, **`PHX_HOST`**, and optional **`DATA_SOURCE`** / **`ESPLORA_BASE_URL`** or RPC-related vars — **`config/runtime.exs`**, **`.env.production.example`**.

---

## Tech stack (pinned in `mix.exs`)

| Component | Notes |
|-----------|--------|
| Elixir | `~> 1.14` |
| Phoenix | `~> 1.7.14` |
| Phoenix LiveView | `~> 0.20.17` |
| Bandit | HTTP server (`~> 1.5`) |
| Bitcoinex (Hex) | `~> 0.1.8` (resolved e.g. **0.1.8** in `mix.lock`) |
| Decimal | Fixed-point display for Lightning BTC amounts (no float/scientific notation in the UI) |
| Tailwind / esbuild | Asset pipeline for CSS/JS |
| Tesla + Hackney | Esplora HTTP client + Bitcoin Core JSON-RPC (Basic auth) |
| d3 / qrcode (npm) | LiveView hooks for charts, flow, QR |

---

## Production (behind a reverse proxy)

Typical layout on **[https://hromp.com/btcexp/](https://hromp.com/btcexp/)**:

- **Reverse proxy** (e.g. nginx): terminate TLS, proxy **`/btcexp/`** (including WebSocket upgrade headers for LiveView) to **`http://127.0.0.1:<PORT>/`** where Phoenix listens.
- **Process supervisor**: run **`MIX_ENV=prod mix phx.server`** from the app checkout with env vars loaded from **`.env.production`** (copy **`.env.production.example`**; set **`SECRET_KEY_BASE`** via **`mix phx.gen.secret`**).
- After HTML/CSS/JS changes: **`MIX_ENV=prod mix assets.deploy`** before restarting the release/server.

Environment highlights (**`.env.production.example`**):

- **`PORT`** (e.g. **40174**), **`PHX_HOST`**, **`PHX_PATH=btcexp`** (must match the URL prefix the proxy strips/forwards), **`PHX_SERVER=true`**, **`MIX_ENV=prod`**.
- Optional **`ESPLORA_BASE_URL`** (defaults to **`https://blockstream.info/api`**) when **`DATA_SOURCE=esplora`** (default).
- **`ESPLORA_CACHE_TTL_MS`** — In **`MIX_ENV=prod`**, defaults to **45000** (45 seconds): dashboard Esplora calls (**recent blocks**, **mempool**, **fee estimates**) are cached in ETS so concurrent visitors do not each run full **`recent_blocks`** pagination. Set **`0`** to disable. Public APIs (e.g. Blockstream) often return **HTTP 429** under heavy traffic; mitigations include your own **`ESPLORA_BASE_URL`**, a higher TTL, slower UI polling (ship defaults), or **`DATA_SOURCE=rpc`**.
- **`ESPLORA_MIN_REQUEST_INTERVAL_MS`** — When **`DATA_SOURCE=esplora`**, **`MIX_ENV=prod`** defaults to **300** ms if unset: Esplora HTTP runs through **`BitcoinexExplorer.EsploraHttpGate`**, which serializes requests and enforces a minimum gap between **starting** each call (aligned with reference nginx rate limits below). Set **`0`** to disable (e.g. private Esplora).
- **`ESPLORA_429_RETRY_DELAY_MS`** — Milliseconds to sleep before an automatic retry after **HTTP 429** (default **2000** from **`config/config.exs`**; optional runtime override when set). **`ESPLORA_HTTP_MAX_ATTEMPTS`** — Total tries per logical GET including the first (default **2** = one retry after **429**).

### Esplora HTTP rate limits (reference deployment & Blockstream)

The upstream **[Blockstream/esplora](https://github.com/Blockstream/esplora)** repo ships sample nginx settings (**[`contrib/nginx.conf.in`](https://github.com/Blockstream/esplora/blob/master/contrib/nginx.conf.in)**): JSON **`/api/`** traffic uses **`limit_req`** at **~5 requests/s** with **`burst=10`**, plus **10 concurrent connections per IP**. Limits apply when each request **arrives**, not when the previous response finishes—so clients should avoid overlapping requests and keep average spacing roughly **≥ ~200 ms** between starts on that reference stack.

Blockstream’s hosted Explorer documents a separate **[Explorer API](https://blockstream.info/explorer-api)** path: **[Apr 2026 blog post](https://blog.blockstream.com/enhanced-analytics-and-infrastructure-improvements-for-the-blockstream-explorer-api/)** describes **production rate limiting on the free tier**, dashboard analytics at **[dashboard.blockstream.info](https://dashboard.blockstream.info/)**, and **paid tiers** (Basic / Advanced / Enterprise) with higher limits for production apps. **Enterprise** is described there as offering unlimited calls.

Community reports ([**esplora#449**](https://github.com/Blockstream/esplora/issues/449)) note that anonymous **429** responses often lack a **`Retry-After`** header; spacing requests (~250 ms apart) is commonly cited as helping. This app combines **start-based pacing**, **dashboard caching**, **429 retries**, and documents pointing operators at **API keys / paid tiers** or **`DATA_SOURCE=rpc`** when public limits are insufficient.
- **`DATA_SOURCE`** — **`esplora`** (default) or **`rpc`** (Bitcoin Core + Fulcrum); see **Self-hosting with a Bitcoin full node**.

---

## Self-hosting with a Bitcoin full node

This section is for operators who want the explorer to read **their own** archival Bitcoin Core node (with **`txindex`**) and **Fulcrum** for address indexing. The LiveView UI is identical to **`DATA_SOURCE=esplora`** as long as both backends return the same normalized maps (enforced by tests around **`BitcoinexExplorer.DataSource`**).

### Overview

Three components run together:

1. **Bitcoin Core** — Full **non-pruned** node with **`txindex=1`** so **`getrawtransaction`** works for any txid on main chain. Supplies blocks, transactions, mempool, and fee estimates via JSON-RPC.
2. **Fulcrum** — Electrum-protocol server that maintains an **address index** on top of Core. The app uses Fulcrum for **`blockchain.scripthash.*`** calls (balance + history); Bitcoin Core RPC still loads full transactions after history lists txids.
3. **Bitcoinex Explorer** (this Phoenix app) — **`DATA_SOURCE=rpc`** enables **`BitcoinexExplorer.BitcoinRPC`** plus a supervised **`BitcoinexExplorer.FulcrumClient`** (persistent TCP/TLS to Fulcrum).

**Hardware (approximate, increases over time):** expect **700GB+** disk for mainnet blocks and indexes (prefer **SSD/NVMe**), **8GB+ RAM**, and a modern multi-core CPU. **Initial block download** typically takes **several days** depending on bandwidth and peers. Fulcrum’s first index build after Core is synced commonly takes on the order of **12–48 hours** (often faster on fast NVMe).

### Installing Bitcoin Core

- Download official binaries from **[bitcoincore.org](https://bitcoincore.org)** (verify signatures using the project’s release process).
- **Full archival node:** do **not** use pruning for this deployment — the explorer expects full blocks and **`txindex`**.
- **`bitcoin.conf`** (minimal sketch — adjust paths and credentials):

  ```
  txindex=1
  server=1
  rpcuser=<choose_a_username>
  rpcpassword=<strong_random_password>
  rpcbind=127.0.0.1
  rpcallowip=127.0.0.1
  zmqpubrawblock=tcp://127.0.0.1:28332
  zmqpubrawtx=tcp://127.0.0.1:28333
  ```

  ZMQ is optional for this explorer but commonly used by other indexers/wallets.

- **Wait for initial sync** before starting Fulcrum. Verify with **`bitcoin-cli getblockchaininfo`**: **`initialblockdownload`** should be **`false`**, and **`blocks`** should match **`headers`** (for fully synced nodes).
- Verify **`txindex`** with **`bitcoin-cli getindexinfo`** — **`txindex`** should report **`synced: true`** once built.
- Enabling **`txindex=1`** on an already-synced node requires a **reindex** (often **many hours**): e.g. **`bitcoind -reindex`** once, then let it complete.

### Installing Fulcrum

- Project home: **[github.com/cculianu/Fulcrum](https://github.com/cculianu/Fulcrum)** (releases and documentation).
- Fulcrum builds an address index from Bitcoin Core’s block files and RPC; **start Fulcrum only after Bitcoin Core is fully synced**.
- **`fulcrum.conf`** (minimal sketch):

  ```
  bitcoin-rpc-url = http://127.0.0.1:8332
  bitcoin-rpc-user = <same rpcuser as bitcoin.conf>
  bitcoin-rpc-password = <same rpcpassword as bitcoin.conf>
  datadir = /path/to/fulcrum/data
  tcp = 127.0.0.1:50001
  # Optional TLS (needs cert/key files):
  # ssl = 127.0.0.1:50002
  # cert = /path/to/cert.pem
  # key = /path/to/key.pem
  ```

- Initial Fulcrum sync can take **hours to a day or more** depending on CPU/disk; watch logs for a **ready** / **listening** style completion message (exact wording follows Fulcrum version).
- Quick manual check from the shell (TCP mode):

  ```sh
  echo '{"id":1,"method":"server.version","params":["bitcoinex-explorer","1.4"]}' | nc 127.0.0.1 50001
  ```

  You should receive a one-line JSON response.

- **Never expose Fulcrum (or Bitcoin RPC) to the public Internet** without TLS, firewalling, and tight access control — see **Security notes**.

### Configuring Bitcoinex Explorer for RPC mode

Set **`DATA_SOURCE=rpc`** and provide:

| Variable | Purpose |
|----------|---------|
| **`BITCOIN_RPC_URL`** | JSON-RPC base URL, e.g. **`http://127.0.0.1:8332`** |
| **`BITCOIN_RPC_USER`** / **`BITCOIN_RPC_PASS`** | HTTP Basic credentials matching **`rpcuser`** / **`rpcpassword`** |
| **`FULCRUM_HOST`** | Fulcrum hostname (typically **`127.0.0.1`**) |
| **`FULCRUM_PORT`** | Fulcrum TCP port (e.g. **`50001`**) |
| **`FULCRUM_SSL`** | **`true`** / **`false`** — use TLS only if Fulcrum listens with **`ssl = …`** and you configure verification appropriately |

**Example `.env.production` skeleton (RPC mode):**

```bash
MIX_ENV=prod
PHX_SERVER=true
DATA_SOURCE=rpc
PORT=40174
PHX_HOST=your-domain.example
PHX_PATH=btcexp
SECRET_KEY_BASE=<output of mix phx.gen.secret>

BITCOIN_RPC_URL=http://127.0.0.1:8332
BITCOIN_RPC_USER=explorer_rpc
BITCOIN_RPC_PASS=<openssl rand -hex 32>

FULCRUM_HOST=127.0.0.1
FULCRUM_PORT=50001
FULCRUM_SSL=false
```

**Startup order:** Bitcoin Core fully synced → Fulcrum fully synced → start Phoenix. **`FulcrumClient`** reconnects with backoff if Fulcrum is not ready yet; the UI becomes usable once RPC + Fulcrum calls succeed.

### Address page totals (`DATA_SOURCE=rpc`)

Esplora’s **`/address/…`** API exposes **`chain_stats`** / **`mempool_stats`** with **lifetime funded**, **spent**, and **tx count** aggregates precomputed by the indexer.

With **`DATA_SOURCE=rpc`** today we only expose:

- **Confirmed / unconfirmed balance** via Fulcrum **`blockchain.scripthash.get_balance`** (mapped into **`chain_stats`** / **`mempool_stats`** so the existing LiveView layout still renders).
- **Tx history** via **`blockchain.scripthash.get_history`** plus **`getrawtransaction`** for full tx detail.

We **do not** yet recompute Esplora-style **total received** (**`funded_txo_sum`**) and **total sent** (**`spent_txo_sum`**) for RPC mode. That requires iterating address history and summing inputs/outputs per tx (or maintaining a cache)—correct but **O(history)** per cold load unless background aggregation is added.

**Planned:** add bounded incremental aggregation or a cached rollup keyed by address/script hash so RPC deployments match Esplora’s address-summary semantics without hammering **`getrawtransaction`** on every page view.

### Security notes

- **Do not expose Bitcoin Core RPC to the Internet.** RPC has powerful methods and no browser-grade rate limiting suitable for untrusted clients.
- **Do not expose Fulcrum without TLS + firewall rules** if it leaves localhost — it exposes rich indexing APIs.
- Prefer binding **`rpcbind`** / Fulcrum **`tcp`** / **`ssl`** to **`127.0.0.1`** unless Phoenix runs on another host; if split across machines, restrict sources to your private network only.
- Generate strong passwords: e.g. **`openssl rand -hex 32`** for **`rpcpassword`**.
- For TLS to Fulcrum, use a proper certificate for private LAN use or public PKI as appropriate.
- Run **`bitcoind`** / Fulcrum as **non-root** dedicated users with minimal filesystem permissions where practical.

### Esplora mode (default)

If you **do not** run a full stack, **`DATA_SOURCE=esplora`** (default) uses a public or private Esplora-compatible HTTP API (**`ESPLORA_BASE_URL`**) and **does not** start **`FulcrumClient`**. This is the lowest-friction setup. Running your own node is recommended when you need **full sovereignty** over chain data and indexing, at the cost of hardware, sync time, and ongoing maintenance.

---

## Run locally

```sh
mix deps.get
(cd assets && npm install)   # required once for D3 / QR hooks
mix phx.server
```

Open **`http://127.0.0.1:4000/`** — no path prefix unless you set **`PHX_PATH`** locally.

---

## Tests

### ExUnit (`mix test`)

- **`test/bitcoinex_explorer/esplora_test.exs`** — **`BitcoinexExplorer.Esplora`** with [**Bypass**](https://hex.pm/packages/bypass) (no real HTTP).
- **`test/bitcoinex_explorer/bitcoin_core_rpc_test.exs`**, **`bitcoin_rpc_normalize_test.exs`**, **`bitcoin_rpc_test.exs`** — JSON-RPC parsing/normalization and **`BitcoinexExplorer.BitcoinRPC`** pipelines (Bypass).
- **`test/bitcoinex_explorer/fulcrum_client_test.exs`**, **`scripthash_test.exs`** — Fulcrum TCP client + Electrum scripthash derivation (no outbound network).
- **`test/bitcoinex_explorer/data_source_test.exs`**, **`application_test.exs`** — backend selection wiring / supervision expectations.
- **`test/bitcoinex_explorer/search_test.exs`** — **`BitcoinexExplorer.Search`** routing classifications.

Integration tests in **`test/bitcoinex_explorer_web/live/explorer_live_test.exs`** exercise **`ExplorerLive`** without a browser:

| Test | What it checks | Why |
|------|----------------|-----|
| **renders explorer** | Title, paste hint, LiveView shell | Smoke-checks the shell users land on before pasting input. |
| **auto-detects Lightning invoice** | `ln…` input → BOLT11 decode; **sats** as plain integer (**250000**); **BTC** as decimal (**0.0025**) | Ensures invoice decoding and **Decimal**-based amounts render clearly in HTML. |
| **auto-detects PSBT** | Base64 magic → PSBT section and copy about **txid until finalized** | Guards PSBT detection and clear messaging for unsigned PSBTs. |
| **Bech32 checksum error** | Invalid `bc1…` surfaces checksum verification failure | Users get SegWit-specific validation feedback for bad Bech32 data. |
| **empty input** | No “Unable to decode” spam on clear field | Empty paste should not look like a failure. |
| **invalid invoice** | Garbage `ln…` → friendly invoice decode error | Distinguishes malformed invoices from other decode paths. |

### Playwright (`e2e/`)

Headless Chromium drives the real LiveView page (fixtures in **`e2e/fixtures/vectors.ts`**):

| Suite | What it covers | Why |
|-------|----------------|-----|
| **`address.spec.ts`** | SegWit/Base58 **success** vectors; SegWit **error** vectors (bad checksum, mixed case, etc.); **total failure** inputs | End-to-end confidence that address auto-detect matches Bitcoinex behavior and error copy in the DOM. |
| **`invoice.spec.ts`** | Valid BOLT11 fixtures and **error** rows | Same for Lightning invoices without manually repeating every ExUnit assertion in a browser. |
| **`psbt.spec.ts`** | One minimal valid PSBT (checks **Inputs**/**Outputs** counts) plus **PSBT_ERRORS** | Validates PSBT magic detection and structured output; errors stay visible to users. |
| **`edge-cases.spec.ts`** | Whitespace trim; uppercase Bech32; clearing input resets UI; empty input clears errors; malformed `bc1`-prefixed input surfaces SegWit decode errors | Catches UX issues unit tests might miss (DOM lifecycle, trimming, cross-type clears). |
| **`routes.spec.ts`** | Home “Live blocks”; classic coinbase **tx** route renders | Smoke-checks deep-linked explorer routes on the path-mounted app. |

```sh
cd e2e
npm install
npx playwright install chromium
npm test
# Path-mounted production URL (base URL must include /btcexp; trailing slash normalized in playwright.config):
BASE_URL=https://hromp.com/btcexp npm test
```

Playwright **`baseURL`** must include the mount path when the app is served under **`/btcexp`** so **`goto(".")`** resolves to the LiveView root.

---

## Known limitations

- Live chain views depend on the configured **`DataSource`** backend (**Esplora** availability/rate limits/network, or **your own** Core/Fulcrum health and sync).
- **`DATA_SOURCE=rpc`**: address page **lifetime funded/spent totals** are **not** Esplora-identical yet (balance + history work); see **Address page totals (`DATA_SOURCE=rpc`)** under self-hosting—aggregation/caching is **planned**.
- Legacy Base58 decoding is best-effort classification using version-byte prefixes.
- PSBT **unsigned transaction ID** is not shown as a real txid — unsigned PSBTs do not have a valid txid until finalized.
- Auto-detection assumes **BOLT11** strings start with **`ln`** and **PSBT** base64 starts with the standard magic; unusual encodings may need future heuristics.
