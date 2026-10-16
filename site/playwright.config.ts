import { defineConfig, devices } from '@playwright/test';
export default defineConfig({
  testDir: './tests/browser',
  timeout: 30_000,
  fullyParallel: true,
  workers: 3,
  use: { baseURL: 'http://127.0.0.1:4322', trace: 'retain-on-failure' },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'iphone-webkit', use: { ...devices['iPhone 13'], browserName: 'webkit' } },
  ],
  webServer: { command: 'python3 ../tools/serve_site.py', url: 'http://127.0.0.1:4322', reuseExistingServer: !process.env.CI },
});
