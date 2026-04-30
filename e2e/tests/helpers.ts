import { expect, type Page } from "@playwright/test";

/**
 * Navigates to the explorer (uses Playwright `baseURL`).
 * Use a relative path like `./about` — never `"/"` alone: with a path-suffixed
 * `baseURL` (e.g. `https://host/btcexp`), `goto("/")` strips the mount path and hits the site root.
 */
export async function openExplorer(page: Page, path = "."): Promise<void> {
  await page.goto(path);
  await expect(page.getByRole("heading", { name: "Bitcoinex Explorer" })).toBeVisible();
}

/**
 * Replaces textarea content; LiveView `phx-change` + 300ms debounce runs after input settles.
 */
export async function setDecodeInput(page: Page, text: string): Promise<void> {
  const ta = page.locator('textarea[name="input"]');
  await ta.fill(text);
}

/** Wait until either the green summary `<dl>` or the orange error paragraph appears. */
export async function waitForDecodeOutcome(page: Page): Promise<void> {
  await expect(
    page.locator("main dl").or(page.locator("main p.text-orange-300")),
  ).toBeVisible();
}

export async function expectResultVisible(page: Page): Promise<void> {
  await expect(page.locator("main dl")).toBeVisible();
  await expect(page.locator("main p.text-orange-300")).toHaveCount(0);
}

export async function expectErrorVisible(page: Page): Promise<void> {
  await expect(page.locator("main p.text-orange-300")).toBeVisible();
  await expect(page.locator("main dl")).toHaveCount(0);
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
  const dt = page.locator("main dl dt", { hasText: new RegExp(`^${escapeRe(term)}$`) });
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
