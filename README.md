# Bitcoinex Explorer

**Bitcoin block explorer** plus a **Bitcoinex**-powered inspector: live blocks/mempool/fee estimates from an Esplora-compatible API, deep-linked **block / transaction / address** pages, D3 visualizations, and the original **single-field** decode for addresses, **BOLT11** invoices, and **PSBT** payloads. Built with **[River Financial’s Bitcoinex](https://github.com/RiverFinancial/bitcoinex)** on **Elixir / Phoenix LiveView**.

| Resource | URL |
|----------|-----|
| **Live app** | [https://hromp.com/btcexp/](https://hromp.com/btcexp/) |
| **Landing page** (marketing / architecture overview) | [https://hromp.com/bitcoinex-explorer/](https://hromp.com/bitcoinex-explorer/) |
| **Source** | [https://github.com/151henry151/bitcoinex-explorer](https://github.com/151henry151/bitcoinex-explorer) |

The running app’s top nav links **About** to that landing page; **GitHub** / upstream Bitcoinex links remain in the page footer.

Licensed under the **MIT License** — see [`LICENSE`](LICENSE).

---

## What it does

### Chain explorer (Esplora API)

- **Home** — Recent blocks (poll), mempool stats (poll), fee estimates; universal **search** bar (txid / block hash / height / address / invoice / PSBT).
- **`/block/:hash`** — Header metadata, paginated txs, **script-type distribution** chart (Bitcoinex-classified outputs).
- **`/tx/:txid`** — Fees, confirmations, **flow diagram** (D3), input/output tables with **Bitcoinex enrichment** (network, type, witness program, payload).
- **`/address/:address`** — Balance and history from Esplora; **QR** code hook; Bitcoinex decode summary at top.
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
| **Chain data** | **`BitcoinexExplorer.Esplora`** (**Tesla** + **Hackney**) calls **`ESPLORA_BASE_URL`** (default Blockstream public API). Timeouts **5s**; **no** cache. |
| **Routing / search** | **`BitcoinexExplorer.Search`** classifies nav input; **`push_patch`** / **`redirect`** keep URLs shareable. |
| **Bitcoinex** | **`BitcoinexExplorer.Decode`** (local decode); **`TxEnrichment`**, **`OutputClassifier`**, **`TxFlow`** combine Esplora JSON with Segwit/Base58 decoders. |
| **UI** | Tailwind; **D3** stacked bar + tx flow (**`assets/js/hooks.js`**); **qrcode** for address QR; relative time hook. |
| **Assets** | Tailwind + esbuild (**`npm`** deps under **`assets/`**); **`mix assets.deploy`** → **`priv/static/`**. |
| **Root layout** | **`live_view_root_only`** — no nested app layout (`bitcoinex_explorer_web.ex`). |

Production can mount under a **path prefix** (e.g. **`/btcexp`**): set **`PHX_PATH`**, **`PHX_HOST`**, and optional **`ESPLORA_BASE_URL`** — **`config/runtime.exs`**, **`.env.production.example`**.

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
| Tesla + Hackney | Esplora HTTP client |
| d3 / qrcode (npm) | LiveView hooks for charts, flow, QR |

---

## Production (behind a reverse proxy)

Typical layout on **[https://hromp.com/btcexp/](https://hromp.com/btcexp/)**:

- **Reverse proxy** (e.g. nginx): terminate TLS, proxy **`/btcexp/`** (including WebSocket upgrade headers for LiveView) to **`http://127.0.0.1:<PORT>/`** where Phoenix listens.
- **Process supervisor**: run **`MIX_ENV=prod mix phx.server`** from the app checkout with env vars loaded from **`.env.production`** (copy **`.env.production.example`**; set **`SECRET_KEY_BASE`** via **`mix phx.gen.secret`**).
- After HTML/CSS/JS changes: **`MIX_ENV=prod mix assets.deploy`** before restarting the release/server.

Environment highlights (**`.env.production.example`**):

- **`PORT`** (e.g. **40174**), **`PHX_HOST`**, **`PHX_PATH=btcexp`** (must match the URL prefix the proxy strips/forwards), **`PHX_SERVER=true`**, **`MIX_ENV=prod`**.
- Optional **`ESPLORA_BASE_URL`** (defaults to **`https://blockstream.info/api`**).

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

- Live chain views depend on the configured Esplora-compatible endpoint (**availability, rate limits, and fork/network choices are upstream concerns**).
- Legacy Base58 decoding is best-effort classification using version-byte prefixes.
- PSBT **unsigned transaction ID** is not shown as a real txid — unsigned PSBTs do not have a valid txid until finalized.
- Auto-detection assumes **BOLT11** strings start with **`ln`** and **PSBT** base64 starts with the standard magic; unusual encodings may need future heuristics.
