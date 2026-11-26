import { defineConfig, devices } from "@playwright/test";

/** Firebase Hosting 에뮬레이터 주소(web/firebase.json). 흔한 포트를 피합니다. */
export const BASE_URL = "http://127.0.0.1:47291";

export default defineConfig({
  testDir: ".",
  outputDir: "../test-results",
  reporter: process.env.CI === undefined ? "list" : [["list"], ["html", { outputFolder: "../playwright-report", open: "never" }]],
  use: { baseURL: BASE_URL },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
});
