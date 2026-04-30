import { defineConfig, devices } from "@playwright/test";

/**
 * Target URL for the LiveView app (path-only deployments supported).
 * @example Production: BASE_URL=https://hromp.com/btcexp npm test
 * @example Local:    BASE_URL=http://127.0.0.1:4000 npm test
 */
/** Trailing `/` is required so `page.goto(".")` resolves to the same path (not parent) when using a subpath mount (e.g. `/btcexp/`). */
const baseURL = `${(process.env.BASE_URL ?? "http://127.0.0.1:4000").trim().replace(/\/+$/, "")}/`;

export default defineConfig({
  testDir: "./tests",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 2 : undefined,
  reporter: process.env.CI ? "github" : [["html", { open: "never" }], ["list"]],
  timeout: 45_000,
  expect: { timeout: 15_000 },
  use: {
    baseURL,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
    ...devices["Desktop Chrome"],
    channel: "chromium",
  },
  projects: [{ name: "chromium", use: { channel: "chromium" } }],
});
