import { expect, type Page } from "@playwright/test";

/** The home “Decode locally” card (scoped so we never match the mempool `<dl>`). */
export function decodeSection(page: Page) {
  return page.getByRole("heading", { name: "Decode locally" }).locator("xpath=ancestor::section[1]");
}

/**
 * Navigates to the explorer (uses Playwright `baseURL`).
 * Use a relative path like `./about` — never `"/"` alone: with a path-suffixed
 * `baseURL` (e.g. `https://host/btcexp`), `goto("/")` strips the mount path and hits the site root.
 */
export async function openExplorer(page: Page, path = "."): Promise<void> {
  await page.goto(path);
  await expect(page.getByRole("link", { name: "Bitcoinex Explorer" })).toBeVisible();
}

/**
 * Replaces textarea content; LiveView `phx-change` + 300ms debounce runs after input settles.
 */
export async function setDecodeInput(page: Page, text: string): Promise<void> {
  const ta = page.locator("#decode-input");
  await ta.scrollIntoViewIfNeeded();
  await ta.fill(text);
}

/** Wait until decode summary or decode error appears (not other `<dl>` on home, e.g. mempool stats). */
export async function waitForDecodeOutcome(page: Page): Promise<void> {
  const section = decodeSection(page);
  await expect(section.locator("dl").or(section.locator("p.text-orange-300"))).toBeVisible();
}

export async function expectResultVisible(page: Page): Promise<void> {
  const section = decodeSection(page);
  await expect(section.locator("dl")).toBeVisible();
  await expect(section.locator("p.text-orange-300")).toHaveCount(0);
}

export async function expectErrorVisible(page: Page): Promise<void> {
  const section = decodeSection(page);
  await expect(section.locator("p.text-orange-300")).toBeVisible();
  await expect(section.locator("dl")).toHaveCount(0);
}

/** Assert that decoded summary text includes every fragment (anywhere under `<main>`). */
export async function expectMainContainsAll(
  page: Page,
  fragments: readonly string[],
): Promise<void> {
  await expectResultVisible(page);
  for (const f of fragments) {
    await expect(page.locator("main")).toContainText(f);
  }
}

/** Assert orange error panel includes every fragment. */
export async function expectErrorContainsAll(
  page: Page,
  fragments: readonly string[],
): Promise<void> {
  await expectErrorVisible(page);
  for (const f of fragments) {
    await expect(page.locator("main")).toContainText(f);
  }
}

/**
 * Reads the `<dd>` that follows a `<dt>` with the given label in the first result table.
 */
export async function expectDtDd(
  page: Page,
  term: string,
  expected: string | RegExp,
): Promise<void> {
  const dt = decodeSection(page).locator("dl dt", {
    hasText: new RegExp(`^${escapeRe(term)}$`),
  });
  await expect(dt).toBeVisible();
  const dd = dt.locator("xpath=following-sibling::dd[1]");
  await expect(dd).toHaveText(expected);
}

function escapeRe(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Paste input; auto-detection picks address / invoice / PSBT. */
export async function decodeAndExpectSuccess(
  page: Page,
  input: string,
  fragments: readonly string[],
): Promise<void> {
  await setDecodeInput(page, input);
  await waitForDecodeOutcome(page);
  await expectMainContainsAll(page, fragments);
}

export async function decodeAndExpectError(
  page: Page,
  input: string,
  fragments: readonly string[],
): Promise<void> {
  await setDecodeInput(page, input);
  await waitForDecodeOutcome(page);
  await expectErrorContainsAll(page, fragments);
}
