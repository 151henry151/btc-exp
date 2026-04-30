import { test } from "@playwright/test";
import {
  ADDRESS_SEGWIT_ERRORS,
  ADDRESS_SUCCESS,
  ADDRESS_TOTAL_FAILURE,
} from "../fixtures/vectors";
import { decodeAndExpectError, decodeAndExpectSuccess, openExplorer } from "./helpers";

test.describe("Addresses (auto-detect)", () => {
  test.beforeEach(async ({ page }) => {
    await openExplorer(page);
  });

  for (const row of ADDRESS_SUCCESS) {
    test(`decodes: ${row.name}`, async ({ page }) => {
      await decodeAndExpectSuccess(page, row.input, [...row.expectText]);
    });
  }

  for (const row of ADDRESS_SEGWIT_ERRORS) {
    test(`SegWit error: ${row.name}`, async ({ page }) => {
      await decodeAndExpectError(page, row.input, [...row.expectText]);
    });
  }

  for (const row of ADDRESS_TOTAL_FAILURE) {
    test(`non-SegWit failure: ${row.name}`, async ({ page }) => {
      await decodeAndExpectError(page, row.input, [...row.expectText]);
    });
  }
});
