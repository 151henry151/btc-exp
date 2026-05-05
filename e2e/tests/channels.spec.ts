import { test, expect } from "@playwright/test";

test("/channels redirects to home", async ({ page }) => {
  await page.goto("./channels");
  await expect(page).not.toHaveURL(/\/channels\/?$/);
  await expect(page.locator("#home-action-form")).toBeVisible();
});

test("home page shows Lightning Network heading and graph", async ({ page }) => {
  await page.goto("./");
  await expect(page.getByRole("heading", { name: /Lightning Network/i })).toBeVisible();
  await expect(page.locator("#home-lightning-graph")).toBeVisible();
});

test("home Lightning section shows stats labels when cache is warm", async ({ page }) => {
  await page.goto("./");
  const section = page.locator("section").filter({ hasText: "Lightning Network" }).first();
  await expect(section.getByText("Nodes", { exact: true })).toBeVisible();
  await expect(section.getByText("Channels", { exact: true })).toBeVisible();
  await expect(section.getByText("Capacity", { exact: true })).toBeVisible();
});

test("Lightning graph click opens focus panel with clear control", async ({ page }) => {
  await page.goto("./");
  const graph = page.locator("#home-lightning-graph");
  const firstCircle = graph.locator("svg circle").first();
  await expect(firstCircle).toBeVisible({ timeout: 45_000 });
  await firstCircle.click();
  await expect(graph.getByRole("button", { name: /clear focus/i })).toBeVisible({ timeout: 10_000 });
  await expect(graph.getByText(/channels in this graph/i)).toBeVisible();
});
