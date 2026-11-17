import { test as base, expect, type Page } from '@playwright/test';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join, extname } from 'node:path';

async function serveReleases() {
  const root = fileURLToPath(new URL('../../dist/', import.meta.url));
  const release = { version: 1, failAssets: false, failedRequests: 0, url: '' };
  const server = createServer(async (request, response) => {
    try {
      const pathname = new URL(request.url!, 'http://localhost').pathname;
      if (release.failAssets && pathname.endsWith('.css')) {
        release.failedRequests++;
        response.writeHead(503); response.end(); return;
      }
      const file = join(root, pathname.endsWith('/') ? `${pathname}index.html` : pathname);
      let content = await readFile(file);
      if (pathname === '/sw.js' || pathname.endsWith('/')) {
        content = Buffer.from(content.toString().replaceAll(/gridzero-play-\d+/g, `gridzero-play-test-${release.version}`));
      }
      const mime: Record<string, string> = { '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css', '.webmanifest': 'application/manifest+json', '.svg': 'image/svg+xml', '.png': 'image/png' };
      response.writeHead(200, { 'Content-Type': mime[extname(file)] || 'text/plain', 'Cache-Control': 'no-store' });
      response.end(content);
    } catch { response.writeHead(404); response.end(); }
  });
  await new Promise<void>(resolve => server.listen(0, '127.0.0.1', resolve));
  release.url = `http://127.0.0.1:${(server.address() as { port: number }).port}`;
  return Object.assign(release, { server });
}

// Each test owns its server, so deployments never mutate the shared dist files
// or race other browser tests.
const test = base.extend<{ release: Awaited<ReturnType<typeof serveReleases>> }>({
  release: async ({}, use) => {
    const release = await serveReleases();
    try { await use(release); }
    finally {
      release.server.closeAllConnections();
      await new Promise<void>(resolve => release.server.close(() => resolve()));
    }
  },
});
test.beforeEach(({ browserName }) => {
  test.skip(browserName === 'webkit', 'Playwright WebKit cannot control service workers.');
});
const build = (page: Page) => page.locator('meta[name="gridzero-build"]');
async function installed(page: Page) {
  await page.evaluate(async () => { await navigator.serviceWorker.ready; });
  await expect.poll(() => page.evaluate(() => !!navigator.serviceWorker.controller)).toBe(true);
}
async function checkUpdate(page: Page) {
  await page.evaluate(async () => { await (await navigator.serviceWorker.getRegistration())!.update(); });
}
async function waiting(page: Page) {
  await expect.poll(() => page.evaluate(async () => !!(await navigator.serviceWorker.getRegistration())?.waiting)).toBe(true);
}

test('startup adopts a complete update, preserves saves, and stays usable offline', async ({ page, context, release }) => {
  await page.goto(release.url); await installed(page);
  await page.getByRole('button', { name: 'Play', exact: true }).click();
  const save = await page.evaluate(() => localStorage.getItem('gridzero.web.game.v1'));
  release.version = 2;
  await checkUpdate(page); await waiting(page);
  // Already-interactive sessions must not reload themselves.
  await expect(build(page)).toHaveAttribute('content', 'gridzero-play-test-1');
  // An old page's cleanup request must not delete the newer waiting cache.
  await page.evaluate(() => new Promise<void>(resolve => {
    const channel = new MessageChannel();
    channel.port1.onmessage = () => { channel.port1.close(); resolve(); };
    navigator.serviceWorker.controller!.postMessage({ type: 'CLIENT_READY', build: 'gridzero-play-test-1' }, [channel.port2]);
  }));
  expect(await page.evaluate(() => caches.keys())).toContain('gridzero-play-test-2');
  await page.reload();
  await expect(build(page)).toHaveAttribute('content', 'gridzero-play-test-2');
  expect(await page.evaluate(() => localStorage.getItem('gridzero.web.game.v1'))).toBe(save);
  await context.setOffline(true); await page.reload();
  await expect(build(page)).toHaveAttribute('content', 'gridzero-play-test-2');
  await expect(page.locator('#board')).toBeVisible();
  await expect.poll(() => page.evaluate(() => caches.keys())).toEqual(['gridzero-play-test-2']);
});

test('failed update retains the working offline app and saved game', async ({ page, context, release }) => {
  await page.goto(release.url); await installed(page);
  await page.getByRole('button', { name: 'Play', exact: true }).click();
  const save = await page.evaluate(() => localStorage.getItem('gridzero.web.game.v1'));
  release.version = 2; release.failAssets = true;
  await checkUpdate(page);
  await expect.poll(() => release.failedRequests).toBeGreaterThan(0);
  await expect.poll(() => page.evaluate(async () => {
    const registration = await navigator.serviceWorker.getRegistration();
    return !registration?.installing && !registration?.waiting;
  })).toBe(true);
  await context.setOffline(true); await page.reload();
  await expect(build(page)).toHaveAttribute('content', 'gridzero-play-test-1');
  expect(await page.evaluate(() => localStorage.getItem('gridzero.web.game.v1'))).toBe(save);
  await expect(page.locator('#board')).toBeVisible();
});

test('another open window blocks forced activation until the next single-window startup', async ({ page, context, release }) => {
  await page.goto(release.url); await installed(page);
  const other = await context.newPage();
  await other.goto(release.url); await installed(other);
  release.version = 2;
  await checkUpdate(page); await waiting(page);
  await page.reload();
  await waiting(page);
  await expect(build(page)).toHaveAttribute('content', 'gridzero-play-test-1');
  await expect(build(other)).toHaveAttribute('content', 'gridzero-play-test-1');
  await other.close(); await page.reload();
  await expect(build(page)).toHaveAttribute('content', 'gridzero-play-test-2');
});
