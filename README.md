# Bitcoinex Explorer

**Bitcoin block explorer** and **Bitcoinex** inspector: pluggable chain backend (**Esplora** HTTP by default, or **Bitcoin Core + Fulcrum**), deep-linked **block / tx / address** views, D3 charts, and a **single-field** decode (address, **BOLT11**, **PSBT**). **[River Financial’s Bitcoinex](https://github.com/RiverFinancial/bitcoinex)** · **Elixir / Phoenix LiveView**.

| | |
|--|--|
| **App** | [hromp.com/btcexp/](https://hromp.com/btcexp/) |
| **Landing** (overview) | [hromp.com/bitcoinex-explorer/](https://hromp.com/bitcoinex-explorer/) |

Nav **About** → landing; app footer links **GitHub** (source) and upstream Bitcoinex. **MIT** — [`LICENSE`](LICENSE).

## Contents

- [Features](#features)
- [Stack & architecture](#stack--architecture)
- [Production](#production)
- [Self-hosting](#self-hosting)
- [Run locally](#run-locally)
- [Tests](#tests)
- [Known limitations](#known-limitations)

---

## Features

**Routes** (LiveView `ExplorerLive`, `handle_params`): **home** (recent blocks, mempool, fees, search); **`/block/:hash`** (header, txs, script-type chart); **`/tx/:txid`** (flow diagram, enriched ins/outs); **`/address/:address`** (balance/history, QR); **`/block/height/:height`** → hash redirect.

**Search** (`BitcoinexExplorer.Search`): 64-char hex → tx then block; numeric → height; address → page; else local decode.

**Decode locally** (home): debounced textarea only — **no** chain calls. Order: **`ln…`** (BOLT11) → PSBT base64 (`cHNid…`) → address (SegWit then Base58).

---

## Stack & architecture

| Area | |
|------|--|
| **Server** | Phoenix **`~> 1.7`**, LiveView **`~> 0.20`**, **Bandit** |
| **Chain** | **`DataSource`** → **`Esplora`** (Tesla/Hackney) or **`BitcoinRPC`** + **`FulcrumClient`** |
| **Bitcoinex** | **`Decode`**, **`TxEnrichment`**, **`OutputClassifier`**, **`TxFlow`** |
| **UI** | Tailwind; **D3** / **qrcode** / relative-time hooks in **`assets/js/hooks.js`** |
| **Assets** | `npm` under **`assets/`** → **`mix assets.deploy`** |
| **Layout** | Root-only LiveView layout (`live_view_root_only`) |

Path prefix (e.g. **`/btcexp`**): **`PHX_PATH`**, **`PHX_HOST`**, **`PORT`** — see **`config/runtime.exs`** and **`.env.production.example`**.

---

## Production

**Typical setup:** nginx terminates TLS, proxies **`/btcexp/`** (WebSocket upgrade) to **`http://127.0.0.1:$PORT/`**. Run **`MIX_ENV=prod mix phx.server`** with env from **`.env.production`** (copy **`.env.production.example`**; **`SECRET_KEY_BASE`** via **`mix phx.gen.secret`**). After CSS/JS changes: **`MIX_ENV=prod mix assets.deploy`**.

| Variable | Role |
|----------|------|
| **`PORT`**, **`PHX_HOST`**, **`PHX_PATH`**, **`PHX_SERVER=true`**, **`MIX_ENV=prod`** | Listen address and public URL (prefix must match proxy). |
| **`DATA_SOURCE`** | **`esplora`** (default) or **`rpc`**. |
| **`ESPLORA_BASE_URL`** | Esplora API root (default Blockstream). |
| **`ESPLORA_CACHE_TTL_MS`** | Prod default **60s** — ETS cache for dashboard Esplora calls; misses single-flight. **`0`** disables. |
| **`ESPLORA_MIN_REQUEST_INTERVAL_MS`** | Prod default **450 ms** — serialized Esplora HTTP via **`EsploraHttpGate`** (**`0`** disables). |
| **`ESPLORA_429_RETRY_DELAY_MS`**, **`ESPLORA_HTTP_MAX_ATTEMPTS`** | Retry after **429** (defaults **2000 ms**, **2** attempts). |

**Esplora limits:** Public APIs often return **429**. Reference nginx stacks use ~**5 req/s** on **`/api/`**; spacing ~**200 ms+** between request starts is a safe baseline. This app uses pacing + cache + retries; for heavy use prefer your own Esplora, a [Blockstream Explorer API](https://blockstream.info/explorer-api) tier, or **`DATA_SOURCE=rpc`**. See [Blockstream/esplora#449](https://github.com/Blockstream/esplora/issues/449) (often no **`Retry-After`**).

---

## Self-hosting

Use **`DATA_SOURCE=rpc`** when you run **Bitcoin Core** (archival, **`txindex=1`**) + **[Fulcrum](https://github.com/cculianu/Fulcrum)** (Electrum index). UI matches Esplora mode when backends return the normalized maps enforced by **`DataSource`** tests.

**Rough footprint:** ~**700GB+** disk (mainnet), **8GB+** RAM, SSD preferred; IBD **days**; Fulcrum first index often **12–48 h** after Core is synced.

### Bitcoin Core

Official builds: **[bitcoincore.org](https://bitcoincore.org)**. Do **not** prune for this setup. Minimal **`bitcoin.conf`** sketch:

```
txindex=1
server=1
rpcuser=…
rpcpassword=…
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
```

Wait until **`getblockchaininfo`** shows **`initialblockdownload: false`** and **`getindexinfo`** shows **`txindex`** synced. Turning on **`txindex`** later needs **`-reindex`**.

### Fulcrum

Start **after** Core is synced. Point **`bitcoin-rpc-*`** at Core; **`tcp = 127.0.0.1:50001`** (example). Health check:  
`echo '{"id":1,"method":"server.version","params":["bitcoinex-explorer","1.4"]}' | nc 127.0.0.1 50001`

### Phoenix env (`DATA_SOURCE=rpc`)

| Variable | |
|----------|--|
| **`BITCOIN_RPC_URL`**, **`BITCOIN_RPC_USER`**, **`BITCOIN_RPC_PASS`** | Core JSON-RPC (**Basic**). |
| **`FULCRUM_HOST`**, **`FULCRUM_PORT`**, **`FULCRUM_SSL`** | Fulcrum TCP/TLS. |

Example skeleton:

```bash
MIX_ENV=prod
PHX_SERVER=true
DATA_SOURCE=rpc
PORT=40174
PHX_HOST=your-domain.example
PHX_PATH=btcexp
SECRET_KEY_BASE=<mix phx.gen.secret>

BITCOIN_RPC_URL=http://127.0.0.1:8332
BITCOIN_RPC_USER=explorer_rpc
BITCOIN_RPC_PASS=<openssl rand -hex 32>

FULCRUM_HOST=127.0.0.1
FULCRUM_PORT=50001
FULCRUM_SSL=false
```

**Order:** Core synced → Fulcrum ready → Phoenix. **`FulcrumClient`** reconnects with backoff.

### RPC address page vs Esplora

Confirmed/unconfirmed **balance** and **tx history** work via Fulcrum + **`getrawtransaction`**. Esplora-style **lifetime funded/spent** aggregates are **not** reproduced yet (**planned**: rollup/cache). See implementation notes in **`BitcoinRPC`** / **`ExplorerLive`** if extending.

### Security

Bind RPC and Fulcrum to **localhost** (or firewall tightly). Never expose Core RPC or Fulcrum raw to the Internet. Strong passwords (**`openssl rand -hex 32`**). Run **`bitcoind`** / Fulcrum as non-root.

### Esplora-only (default)

**`DATA_SOURCE=esplora`** — no Fulcrum process. Lowest friction; own stack when you need sovereignty.

---

## Run locally

```sh
mix deps.get
(cd assets && npm install)
mix phx.server
```

Open **`http://127.0.0.1:4000/`** unless you set **`PHX_PATH`**.

---

## Tests

**ExUnit:** **`mix test`** — backend suites under **`test/bitcoinex_explorer/`**; **`test/bitcoinex_explorer_web/live/explorer_live_test.exs`** covers **`ExplorerLive`** decode flows (invoice, PSBT, Bech32 errors, empty input).

**Playwright:** **`e2e/`** — **`npm install`**, **`npx playwright install chromium`**, **`npm test`**. Path-mounted deploys: **`BASE_URL=https://hromp.com/btcexp npm test`** (`baseURL` must include the prefix).

---

## Known limitations

- Live data depends on Esplora availability / limits or your Core/Fulcrum health.
- **`DATA_SOURCE=rpc`**: address **totals** differ from Esplora until aggregation work lands (balance + history OK).
- Base58 decode is prefix-based best effort.
- Unsigned PSBT has no valid txid until finalized.
- Auto-detect assumes **`ln`** / PSBT magic; odd encodings may need manual handling.
