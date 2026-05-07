# Lightning graph — historical animation (roadmap + snapshots)

## Goal (not implemented yet)

Animate the home-page **Lightning Network** force graph from **past layout → current**: e.g. nodes appear where they would have been **yesterday** or **last week**, then move visibly to **today’s** positions and sizes.

**Why not shipped:** mempool.space gives **aggregate** Lightning stats over time, not a replayable **topology** (rankings + channels between top nodes). Positions are computed in the browser; “yesterday’s chart” requires **our own** saved graph inputs.

## What we store now

On each successful **`ChannelsCache`** fetch (same cadence as the live graph), we may append **daily JSON snapshots** under **`priv/data/lightning_snapshots/`** (production default; override with **`LIGHTNING_SNAPSHOT_DIR`**).

Each file is named **`snapshot-YYYY-MM-DD.json`** (UTC calendar day). Intraday refreshes **overwrite** that day’s file so it always reflects the latest successful pull.

Snapshot **`schema_version`** **1** includes:

- **`stats_latest`** — raw **`/api/v1/lightning/statistics/latest`** body (audit / future headline stats).
- **`mempool_rankings_nodes`** — raw top-liquidity node rows used to build the graph.
- **`subgraph_edges`** — deduped edges among those nodes (`source`, `target`, `capacity`).
- **`graph_for_client`** — output of **`LightningGraph.from_data/2`** (same shape as **`data-graph`** today).

Keeping both **raw** and **`graph_for_client`** lets you replay later even if **`from_data`** filtering changes.

## Planned implementation (later)

1. Expose **previous-day** (or **previous-week**) snapshot to **`LightningGraph`** (second dataset or embedded `{from, to}`).
2. Run the force layout **twice** (or interpolate): **past** positions/sizes → **current**.
3. Drive a short **transition** (e.g. d3 transition on `x`, `y`, `r`) instead of only synchronous settle.

Disable writes anytime: **`LIGHTNING_SNAPSHOT_DIR=disable`** (see **`.env.production.example`**).
