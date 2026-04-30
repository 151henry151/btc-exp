# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
