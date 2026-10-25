import { defineConfig, devices } from "@playwright/test"

const API_PORT = process.env.E2E_API_PORT ?? "3117"
const WEB_PORT = process.env.E2E_WEB_PORT ?? "5217"
const DATABASE_URL = (process.env.E2E_DATABASE_URL ??= "postgres://localhost/bshelf_e2e")
const external = process.env.E2E_BASE_URL

export default defineConfig({
  testDir: "e2e",
  timeout: 60_000,
  expect: { toHaveScreenshot: { maxDiffPixelRatio: 0.01 } },
  fullyParallel: false,
  workers: 1,
  reporter: "list",
  use: {
    baseURL: external ?? `http://localhost:${WEB_PORT}`,
    trace: "retain-on-failure",
    locale: "en-US",
    timezoneId: "UTC",
  },
  projects: [
    {
      name: "mobile",
      use: { ...devices["iPhone 13"], browserName: "chromium", viewport: { width: 390, height: 844 } },
    },
  ],
  webServer: external
    ? undefined
    : [
        {
          command: `bin/rails db:prepare && bin/rails server -p ${API_PORT} -P tmp/pids/e2e.pid`,
          cwd: "..",
          url: `http://localhost:${API_PORT}/up`,
          env: { DATABASE_URL, SOLID_QUEUE_IN_PUMA: "false", LAUNCHY_DRY_RUN: "true" },
          reuseExistingServer: false,
          timeout: 120_000,
        },
        {
          command: `npx vite --port ${WEB_PORT} --strictPort`,
          url: `http://localhost:${WEB_PORT}`,
          env: { API_PORT },
          reuseExistingServer: false,
        },
      ],
})
