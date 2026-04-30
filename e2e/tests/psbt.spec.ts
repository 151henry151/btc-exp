import { test } from "@playwright/test";
import { PSBT_ERRORS, PSBT_VALID_MINIMAL } from "../fixtures/vectors";
import {
  decodeAndExpectError,
  decodeAndExpectSuccess,
  expectDtDd,
  openExplorer,
} from "./helpers";

test.describe("PSBT (auto-detect)", () => {
  test.beforeEach(async ({ page }) => {
    await openExplorer(page);
  });

  test(PSBT_VALID_MINIMAL.name, async ({ page }) => {
    await decodeAndExpectSuccess(page, PSBT_VALID_MINIMAL.input, [
      ...PSBT_VALID_MINIMAL.expectText,
    ]);
    await expectDtDd(page, "Inputs", "1");
    await expectDtDd(page, "Outputs", "2");
  });

  for (const row of PSBT_ERRORS) {
    test(`error: ${row.name}`, async ({ page }) => {
      await decodeAndExpectError(page, row.input, [...row.expectText]);
    });
  }
});
