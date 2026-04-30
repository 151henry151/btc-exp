import { test, expect } from "@playwright/test";

/**
 * Deep-linked explorer routes (path-mounted app).
 */
test.describe("Explorer routes", () => {
  test("home loads blocks heading", async ({ page }) => {
    await page.goto(".");
    await expect(page.getByRole("heading", { name: /Live blocks/i })).toBeVisible({
      timeout: 30_000,
    });
  });

  test("transaction route renders Transaction heading", async ({ page }) => {
    await page.goto("./tx/f4184fc596403b9d638783cf57adfe4c75c605f6356fbc91338530e9831e9e16");
    await expect(page.getByRole("heading", { name: /^Transaction$/ })).toBeVisible({
      timeout: 30_000,
    });
  });
});
