import { test } from "@playwright/test";
import { INVOICE_ERRORS, INVOICE_SUCCESS } from "../fixtures/vectors";
import { decodeAndExpectError, decodeAndExpectSuccess, openExplorer } from "./helpers";

test.describe("Invoices (auto-detect)", () => {
  test.beforeEach(async ({ page }) => {
    await openExplorer(page);
  });

  for (const row of INVOICE_SUCCESS) {
    test(`decodes: ${row.name}`, async ({ page }) => {
      await decodeAndExpectSuccess(page, row.input, [...row.expectText]);
    });
  }

  for (const row of INVOICE_ERRORS) {
    test(`error: ${row.name}`, async ({ page }) => {
      await decodeAndExpectError(page, row.input, [...row.expectText]);
    });
  }
});
