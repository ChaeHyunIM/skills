import { defineConfig, devices } from "@playwright/test";

// verify 스킬이 base/head 두 서버에 같은 spec 을 돌리므로 대상 URL·결과 위치는 환경변수로 받는다.
const baseURL = process.env.E2E_BASE_URL ?? "http://localhost:3000";
const outputDir = process.env.E2E_OUT ?? ".e2e/results";
const storageState = process.env.E2E_STORAGE_STATE;

export default defineConfig({
  testDir: "apps",
  testMatch: /\/e2e\/.*\.spec\.ts$/,
  outputDir,
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 60_000,
  reporter: [["list"], ["json", { outputFile: `${outputDir}/report.json` }]],
  use: {
    baseURL,
    storageState,
    // 기본값은 800×800 안으로 축소되어 글자가 뭉개진다. 뷰포트 크기 그대로 녹화한다.
    video: { mode: "on", size: { width: 1280, height: 800 } },
    trace: "on",
    screenshot: "only-on-failure",
    locale: "ko-KR",
    timezoneId: "Asia/Seoul",
  },
  projects: [
    { name: "chromium", use: { ...devices["Desktop Chrome"], viewport: { width: 1280, height: 800 } } },
    { name: "mobile", use: { ...devices["iPhone 14"] } },
  ],
});
