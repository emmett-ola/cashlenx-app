import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: '.',
  testMatch: 'cashlenx.spec.js',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  timeout: 180_000,
  expect: { timeout: 15_000 },
  outputDir: '/tests/artifacts/results',
  reporter: [
    ['list'],
    ['json', { outputFile: '/tests/artifacts/result.json' }],
  ],
  use: {
    browserName: 'chromium',
    headless: true,
    viewport: { width: 390, height: 844 },
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
});
