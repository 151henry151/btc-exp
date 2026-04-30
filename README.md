# Bitcoinex Explorer

Bitcoin address, **BOLT11** Lightning invoice, and **PSBT** inspector — single paste box with automatic format detection. Built with **[River Financial’s Bitcoinex](https://github.com/RiverFinancial/bitcoinex)** on **Elixir / Phoenix LiveView**.

| Resource | URL |
|----------|-----|
| **Live app** | [https://hromp.com/btcexp/](https://hromp.com/btcexp/) |
| **Landing page** (about) | [https://hromp.com/bitcoinex-explorer/](https://hromp.com/bitcoinex-explorer/) |
| **Source** | [https://github.com/151henry151/bitcoinex-explorer](https://github.com/151henry151/bitcoinex-explorer) |

Licensed under the **MIT License** — see [`LICENSE`](LICENSE).

---

## What it does

You paste **one** payload into the UI. The app picks a decoder without tabs or modes:

1. **Lightning (BOLT11)** — if the trimmed input matches `ln…` (length ≥ 6).
2. **PSBT** — if whitespace is stripped and the base64 string begins with the PSBT magic (`cHNid…` when base64-encoded).
3. **Bitcoin address** — otherwise: **SegWit** (`bc1…`, `tb1…`, `bcrt1…`) via Bech32/Bech32m, then **legacy Base58** (`1…`, `3…`, etc.).

Decoded output includes an **Input type** row (Bitcoin address / Lightning invoice / PSBT) plus fields from Bitcoinex (`Segwit`, `Base58`, `LightningNetwork.Invoice`, `PSBT`).

---

## Architecture (technical)

| Layer | Details |
|-------|---------|
| **HTTP / WebSocket** | [**Bandit**](https://hex.pm/packages/bandit) serves Phoenix. [**LiveView**](https://hexdocs.pm/phoenix_live_view/) keeps state in **`BitcoinexExplorerWeb.ExplorerLive`**; the root route **`/`** is the only browser scope (`router.ex`). |
| **UI** | One [`phx-change`](https://hexdocs.pm/phoenix_live_view/form-bindings.html) form with a debounced textarea (`phx-debounce="300"`). Results render as a definition list; errors as inline alerts. |
| **Decoding** | All logic lives in **`ExplorerLive`**: `decode_auto/1` delegates to **`Bitcoinex.Segwit`**, **`Bitcoinex.Base58`**, **`Bitcoinex.LightningNetwork.Invoice`**, and **`Bitcoinex.PSBT`** — no separate API microservice. |
| **Assets** | Tailwind + esbuild (`assets/`); production builds digest into **`priv/static/`** via **`mix assets.deploy`**. |
| **Root layout** | Explorer uses **`live_view_root_only`** (no nested app layout) so LiveView does not double-wrap `<html>` (`bitcoinex_explorer_web.ex`). |

Production can mount the app under a **URL path prefix** (e.g. `/btcexp`): set **`PHX_PATH`** so URLs, static assets, and the LiveView socket match nginx — see **`config/runtime.exs`** and **`.env.production.example`**.

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

---

## Production (behind a reverse proxy)

Typical layout on **[https://hromp.com/btcexp/](https://hromp.com/btcexp/)**:

- **Reverse proxy** (e.g. nginx): terminate TLS, proxy **`/btcexp/`** (including WebSocket upgrade headers for LiveView) to **`http://127.0.0.1:<PORT>/`** where Phoenix listens.
- **Process supervisor**: run **`MIX_ENV=prod mix phx.server`** from the app checkout with env vars loaded from **`.env.production`** (copy **`.env.production.example`**; set **`SECRET_KEY_BASE`** via **`mix phx.gen.secret`**).
- After HTML/CSS/JS changes: **`MIX_ENV=prod mix assets.deploy`** before restarting the release/server.

Environment highlights (**`.env.production.example`**):

- **`PORT`** (e.g. **40174**), **`PHX_HOST`**, **`PHX_PATH=btcexp`** (must match the URL prefix the proxy strips/forwards), **`PHX_SERVER=true`**, **`MIX_ENV=prod`**.

---

## Run locally

```sh
mix deps.get
mix phx.server
```

Open **`http://127.0.0.1:4000/`** — no path prefix unless you set **`PHX_PATH`** locally.

---

## Tests

### ExUnit (`mix test`)

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

- Legacy Base58 decoding is best-effort classification using version-byte prefixes.
- PSBT **unsigned transaction ID** is not shown as a real txid — unsigned PSBTs do not have a valid txid until finalized.
- Auto-detection assumes **BOLT11** strings start with **`ln`** and **PSBT** base64 starts with the standard magic; unusual encodings may need future heuristics.
