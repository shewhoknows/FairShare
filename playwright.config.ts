import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './tests/e2e',
  timeout: 60_000,
  retries: process.env.CI ? 1 : 0,
  workers: 1, // serial — tests share live DB state across files
  reporter: process.env.CI
    ? [['github'], ['html', { open: 'never' }]]
    : [['html', { open: 'never' }], ['list']],
  globalSetup: './tests/e2e/setup/global-setup.ts',
  use: {
    baseURL: process.env.TEST_URL ?? 'https://fairshare-production-e481.up.railway.app',
    headless: true,
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'retain-on-failure',
  },
})
