import { expect, test } from "@playwright/test";
import {
  decodeAndExpectSuccess,
  decodeSection,
  openExplorer,
  setDecodeInput,
  waitForDecodeOutcome,
} from "./helpers";

const SAMPLE_BC1Q = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4";

test.describe("Cross-cutting behavior", () => {
  test.beforeEach(async ({ page }) => {
    await openExplorer(page);
  });

  test("leading and trailing whitespace is trimmed for decode", async ({ page }) => {
    await decodeAndExpectSuccess(page, `  \n\t${SAMPLE_BC1Q}   `, ["mainnet", "p2wpkh"]);
  });

  test("all-uppercase Bech32 decodes the same as lowercase", async ({ page }) => {
    await decodeAndExpectSuccess(page, "BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4", [
      "mainnet",
      "p2wpkh",
    ]);
  });

  test("replacing input clears prior result when switching payload type", async ({ page }) => {
    await decodeAndExpectSuccess(page, SAMPLE_BC1Q, ["p2wpkh"]);
    await setDecodeInput(page, "");
    await expect(decodeSection(page).locator("dl")).toHaveCount(0);
    await expect(decodeSection(page).locator("p.text-orange-300")).toHaveCount(0);
  });

  test("empty input clears error and summary", async ({ page }) => {
    await setDecodeInput(page, "not-an-address");
    await waitForDecodeOutcome(page);
    await expect(decodeSection(page).locator("p.text-orange-300")).toBeVisible();

    await setDecodeInput(page, "");
    await expect(decodeSection(page).locator("dl")).toHaveCount(0);
    await expect(decodeSection(page).locator("p.text-orange-300")).toHaveCount(0);
  });

  test("bc1-prefixed mixed-case garbage surfaces SegWit error (not legacy decode)", async ({
    page,
  }) => {
    await setDecodeInput(page, "bc1" + "1AGNa15ZQXAZUgFiqJ2i7Z2DPU2J6hW62i");
    await waitForDecodeOutcome(page);
    await expect(decodeSection(page).locator("p.text-orange-300")).toBeVisible();
    await expect(page.locator("main")).toContainText("Could not decode as a SegWit address");
    await expect(page.locator("main")).toContainText("mixed_case");
  });
});
