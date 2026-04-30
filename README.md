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
| Tailwind / esbuild | Asset pipeline for CSS/JS |

---

## Production (typical hromp.com setup)

Documented in **[`my-webserver-setup`](https://github.com/151henry151/my-webserver-setup)** for this host:

- **nginx** terminates TLS and proxies **`https://hromp.com/btcexp/`** → **`http://127.0.0.1:40174/`**, with WebSocket upgrade headers for LiveView (`nginx/conf.d/00-hromp.com.conf`).
- **systemd** runs **`mix phx.server`** from **`/home/henry/bitcoinex-explorer`** using **`scripts/bitcoinex-explorer.service`** and **`/home/henry/bitcoinex-explorer/.env.production`** (copy from **`.env.production.example`**; set **`SECRET_KEY_BASE`** with **`mix phx.gen.secret`**).
- Before (re)starting after UI/asset changes: **`MIX_ENV=prod mix assets.deploy`**.

Environment highlights (**`.env.production.example`**):

- **`PORT=40174`**, **`PHX_HOST=hromp.com`**, **`PHX_PATH=btcexp`**, **`PHX_SERVER=true`**, **`MIX_ENV=prod`**.

---

## Run locally

```sh
mix deps.get
mix phx.server
```

Open **`http://127.0.0.1:4000/`** — no path prefix unless you set **`PHX_PATH`** locally.

---

## Tests

- **ExUnit**: `mix test` — LiveView and form integration tests under **`test/`**.
- **End-to-end (Playwright)**: headless Chromium against a running Phoenix app — **`e2e/`**.

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
- PSBT **unsigned transaction ID** is shown as unavailable — this parser path does not expose a ready-made txid helper in the UI.
- Auto-detection assumes **BOLT11** strings start with **`ln`** and **PSBT** base64 starts with the standard magic; unusual encodings may need future heuristics.

---

## Screenshot

Optional: add a UI screenshot under **`docs/`** once you want a frozen visual reference.
