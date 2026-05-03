import { test, expect } from "@playwright/test";

test("channels page renders heading", async ({ page }) => {
  await page.goto("./channels");
  await expect(page.locator("h2")).toContainText(/lightning/i);
});

test("channels page has stat cards", async ({ page }) => {
  await page.goto("./channels");
  const section = page.locator("#channels-page");
  await expect(section.getByText("Nodes", { exact: true })).toBeVisible();
  await expect(section.getByText("Channels", { exact: true })).toBeVisible();
  await expect(section.getByText("Total capacity", { exact: true })).toBeVisible();
});

test("channels page graph element is present", async ({ page }) => {
  await page.goto("./channels");
  await expect(page.locator("#lightning-graph")).toBeVisible();
});
