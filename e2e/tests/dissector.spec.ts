import { test, expect, type Page } from "@playwright/test";

/** Deep-link a known height so we do not depend on the home “Live blocks” Esplora fetch. */
const BLOCK_VIA_HEIGHT = "./block/height/800000";

/** Opening button label — avoid `/dissect/i` (matches “Close dissector” too). */
function dissectToggle(page: Page) {
  return page.getByRole("button", { name: /dissect this block/i });
}

async function gotoBlockHeight(page: Page): Promise<void> {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      await page.goto(BLOCK_VIA_HEIGHT, { waitUntil: "domcontentloaded", timeout: 60_000 });
      return;
    } catch {
      if (attempt === 2) {
        throw new Error(`goto ${BLOCK_VIA_HEIGHT} failed after 3 attempts`);
      }

      await page.waitForTimeout(1000);
    }
  }
}

/** Wait until LiveView’s client exists (Phoenix socket wiring may lag behind DOMContentLoaded). */
async function waitForLiveSocket(page: Page): Promise<void> {
  await page.waitForFunction(() => (window as unknown as { liveSocket?: unknown }).liveSocket != null, null, {
    timeout: 60_000,
  });
  await page.waitForTimeout(750);
}

test.describe("block dissector", () => {
  test.describe.configure({ timeout: 120_000 });

  test("block page shows Dissect button", async ({ page }) => {
    await gotoBlockHeight(page);
    await expect(page.getByRole("heading", { name: /block\s+/i })).toBeVisible({
      timeout: 60_000,
    });
    await waitForLiveSocket(page);
    await expect(dissectToggle(page)).toBeVisible({ timeout: 60_000 });
  });

  test("opening dissector shows Version and expandable Nonce detail", async ({ page }) => {
    await gotoBlockHeight(page);
    await expect(page.getByRole("heading", { name: /block\s+/i })).toBeVisible({
      timeout: 60_000,
    });
    await waitForLiveSocket(page);
    await dissectToggle(page).click();
    const panel = page.locator("#block-dissector");
    try {
      await expect(panel).toBeVisible({ timeout: 8000 });
    } catch {
      await dissectToggle(page).click();
      await expect(panel).toBeVisible({ timeout: 60_000 });
    }
    await expect(panel.getByText("Version", { exact: true })).toBeVisible();
    await panel.getByText("Nonce", { exact: true }).click();
    await expect(panel.locator("p.italic")).toContainText(/quadrillions/i);
  });
});
