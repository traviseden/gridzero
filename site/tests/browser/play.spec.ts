import { test, expect, type Page } from '@playwright/test';
import { createGame, type Game } from '../../src/game/game';
import { solutions } from '../../src/game/sudoku';

const example = [...'530070000600195000098000060800060003400803001700020006060000280000419005000080079'].map(Number);
const fixture = () => createGame({ id: 'browser-test', givens: [...example], solution: solutions(example)[0], source: 'collection', difficulty: 'easy' });
async function load(page: Page, game = fixture(), prefs = {}) {
  await page.addInitScript(({ game, prefs }) => {
    if (!localStorage.getItem('test-initialized')) {
      localStorage.setItem('gridzero.web.game.v1', JSON.stringify({ version: 1, game, played: [game.puzzle.id] }));
      localStorage.setItem('gridzero.web.preferences.v1', JSON.stringify(prefs));
      localStorage.setItem('test-initialized', 'true');
    }
  }, { game, prefs });
  await page.goto('/play/'); await expect(page.locator('#status')).not.toHaveText('Preparing your puzzle…');
}
async function saved(page: Page): Promise<Game> { return page.evaluate(() => JSON.parse(localStorage.getItem('gridzero.web.game.v1')!).game); }
async function menu(page: Page, action: string) { await page.getByRole('button', { name: 'Game menu', exact: true }).click(); await page.locator(`[data-action="${action}"]`).click(); }

test('homepage links to the game; informational pages stay script-free', async ({ page }) => {
  await page.goto('/'); await page.getByRole('link', { name: 'Play now' }).click();
  await expect(page.locator('[data-cell]')).toHaveCount(81);
  for (const route of ['/', '/privacy/', '/support/', '/credits/']) { await page.goto(route); await expect(page.locator('script')).toHaveCount(0); }
});
test('manual notes, undo, correct entries, and persistence', async ({ page }) => {
  await load(page); await page.locator('[data-cell="2"]').click();
  await page.locator('#notes').click(); await page.getByRole('button', { name: 'Toggle note 4', exact: true }).click();
  await expect(page.locator('[data-cell="2"] [data-note="4"]')).toHaveText('4');
  await page.locator('#undo').click(); await expect(page.locator('[data-cell="2"] [data-note="4"]')).toHaveText('');
  await page.locator('#notes').click(); await page.getByRole('button', { name: 'Enter 4', exact: true }).click();
  await expect(page.locator('[data-cell="2"] .value')).toHaveText('4');
  await page.reload(); await expect(page.locator('[data-cell="2"] .value')).toHaveText('4');
  expect((await saved(page)).strikes).toBe(0);
});
test('wrong numbers reject, strike-out persists, and Continue in Classic unlocks', async ({ page }) => {
  await load(page); await page.locator('[data-cell="2"]').click();
  for (let i = 0; i < 3; i++) await page.getByRole('button', { name: 'Enter 1', exact: true }).click();
  await expect(page.locator('#notice-title')).toHaveText('Strike limit reached');
  expect((await saved(page)).strikes).toBe(3); expect((await saved(page)).board.values[2]).toBe(0);
  await page.reload(); await expect(page.locator('#notice-dialog')).toBeVisible();
  await page.locator('#notice-dialog').getByRole('button', { name: 'Continue in Classic', exact: true }).click();
  await page.getByRole('button', { name: 'Enter 1', exact: true }).click();
  await expect(page.locator('[data-cell="2"] .value')).toHaveText('1');
  await menu(page, 'check'); await expect(page.locator('#notice-title')).toHaveText('A second look');
});
test('settings persist, themes apply, assistance is opt-in, strike rules stay fixed', async ({ page }) => {
  await load(page); await menu(page, 'settings');
  await page.locator('[data-theme-choice="moss"]').click();
  await page.getByLabel('Appearance', { exact: true }).selectOption('dark');
  await page.getByLabel('Enable Fill Notes', { exact: true }).check();
  await page.getByLabel('Challenge strike limit', { exact: true }).fill('4');
  await page.getByLabel('Challenge strike limit', { exact: true }).blur();
  await page.getByRole('button', { name: 'Increase strike limit' }).click();
  await expect(page.getByLabel('Challenge strike limit', { exact: true })).toHaveValue('5');
  await expect(page.getByRole('button', { name: 'Increase strike limit' })).toBeDisabled();
  await page.getByLabel('Challenge strike limit', { exact: true }).fill('1');
  await page.getByLabel('Challenge strike limit', { exact: true }).blur();
  await expect(page.getByRole('button', { name: 'Decrease strike limit' })).toBeDisabled();
  await page.getByRole('button', { name: 'Increase strike limit' }).click();
  await page.locator('#settings-dialog [data-close]').click();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'moss');
  await expect(page.locator('html')).toHaveAttribute('data-scheme', 'dark');
  expect((await saved(page)).strikeLimit).toBe(3);
  await menu(page, 'fill'); await expect(page.locator('[data-cell="2"] [data-note="4"]')).toHaveText('4');
  await page.reload(); await expect(page.locator('html')).toHaveAttribute('data-theme', 'moss');
  await menu(page, 'settings');
  await expect(page.getByLabel('Challenge strike limit', { exact: true })).toHaveValue('2');
});
test('custom generation runs in worker and cancellation keeps old game', async ({ page }) => {
  await load(page); await menu(page, 'new');
  await page.locator('#new-form [name="difficulty"]').selectOption('custom');
  await page.locator('#new-form [name="empty"]').fill('20');
  await page.getByRole('button', { name: 'Start Puzzle', exact: true }).click();
  await expect(page.locator('#new-dialog')).not.toBeVisible({ timeout: 20_000 });
  const g = await saved(page); expect(g.puzzle.givens.filter(v => !v)).toHaveLength(20);
  expect(solutions(g.puzzle.givens)).toHaveLength(1);
  await menu(page, 'new'); await page.locator('#new-form [name="empty"]').fill('60');
  await page.getByRole('button', { name: 'Start Puzzle', exact: true }).click();
  await page.locator('#new-dialog [data-close]').click();
  expect((await saved(page)).puzzle.id).toBe(g.puzzle.id);
});
test('mode info preserves pending puzzle choices and returns keyboard focus', async ({ page }) => {
  await load(page, fixture(), { strikeLimit: 5 });
  const original = await saved(page);
  await menu(page, 'new');
  await page.locator('#new-form [name="difficulty"]').selectOption('custom');
  await page.locator('#new-form [name="empty"]').fill('32');
  await page.getByRole('button', { name: 'About game mode' }).click();
  await expect(page.locator('#mode-info-message')).toContainText('5 strikes end the attempt.');
  await page.locator('#mode-info-dialog [data-close]').click();
  await expect(page.locator('#mode-info')).toBeFocused();
  await expect(page.locator('#new-form [name="difficulty"]')).toHaveValue('custom');
  await expect(page.locator('#new-form [name="empty"]')).toHaveValue('32');
  await page.locator('#new-form [name="mode"]').selectOption('classic');
  await page.getByRole('button', { name: 'About game mode' }).click();
  await expect(page.locator('#mode-info-title')).toHaveText('Classic');
  await expect(page.locator('#mode-info-message')).toContainText('Check Board');
  await page.keyboard.press('Escape');
  await expect(page.locator('#new-dialog')).toBeVisible();
  await expect(page.locator('#new-form [name="mode"]')).toHaveValue('classic');
  expect(await saved(page)).toEqual(original);
});
test('completion, restart, and Classic checking', async ({ page }) => {
  const g = fixture(); g.board.values = [...g.puzzle.solution]; g.board.values[2] = 0;
  await load(page, g); await page.locator('[data-cell="2"]').click();
  await page.getByRole('button', { name: 'Enter 4', exact: true }).click();
  await expect(page.locator('#notice-title')).toHaveText('Puzzle complete');
  await page.getByRole('button', { name: 'Done', exact: true }).click();
  await menu(page, 'restart'); await page.getByRole('button', { name: 'Restart', exact: true }).click();
  expect((await saved(page)).board.values).toEqual(example);
});
test('keyboard support and reduced motion', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' }); await load(page);
  await page.locator('[data-cell="2"]').click(); await page.keyboard.press('4');
  await expect(page.locator('[data-cell="2"] .value')).toHaveText('4');
  await expect(page.locator('.entry-flight')).toHaveCount(0);
  await page.keyboard.press('Control+z'); await expect(page.locator('[data-cell="2"] .value')).toHaveText('');
  await page.keyboard.press('ArrowRight'); await expect(page.locator('[data-cell="3"]')).toHaveAttribute('aria-pressed', 'true');
});
test('invalid saves recover and storage failures are visible', async ({ page }) => {
  await page.addInitScript(() => localStorage.setItem('gridzero.web.game.v1', '{bad'));
  await page.goto('/play/'); await expect(page.locator('#save-status')).toContainText('previous save');
  await page.evaluate(() => { Storage.prototype.setItem = () => { throw new Error('storage disabled'); }; });
  await page.locator('#notes').click(); await page.getByRole('button', { name: 'Toggle note 1', exact: true }).click();
  await expect(page.locator('#save-status')).toContainText("Couldn't save your progress");
});
test('offline reload includes the collection and generator worker', async ({ page, context, browserName }) => {
  test.skip(browserName === 'webkit', 'Playwright WebKit does not expose service worker control.');
  await load(page);
  await page.evaluate(async () => { await navigator.serviceWorker.ready; });
  await expect.poll(() => page.evaluate(() => !!navigator.serviceWorker.controller)).toBe(true);
  await context.setOffline(true); await page.reload();
  await expect(page.locator('[data-cell]')).toHaveCount(81);
  await menu(page, 'new'); await page.getByRole('button', { name: 'Start Puzzle', exact: true }).click();
  await expect(page.locator('#new-dialog')).not.toBeVisible();
  await menu(page, 'new'); await page.locator('#new-form [name="difficulty"]').selectOption('custom');
  await page.locator('#new-form [name="empty"]').fill('20');
  await page.getByRole('button', { name: 'Start Puzzle', exact: true }).click();
  await expect(page.locator('#new-dialog')).not.toBeVisible();
});
test('phone, tablet, desktop, and small-window layouts fit without scrolling', async ({ page }) => {
  await load(page);
  for (const [width, height] of [[320, 568], [375, 667], [390, 844], [430, 932], [844, 390], [1024, 768], [768, 1024], [1440, 900], [600, 500], [280, 480]]) {
    await page.setViewportSize({ width, height });
    const boxes = await page.locator('#board, .keypad, .tools').evaluateAll(elements => elements.map(e => {
      const r = e.getBoundingClientRect(); return { x: r.x, y: r.y, right: r.right, bottom: r.bottom, width: r.width, height: r.height };
    }));
    for (const box of boxes) { expect(box.x).toBeGreaterThanOrEqual(-1); expect(box.y).toBeGreaterThanOrEqual(0); expect(box.right).toBeLessThanOrEqual(width + 1); expect(box.bottom).toBeLessThanOrEqual(height + 1); }
    expect(Math.abs(boxes[0].width - boxes[0].height)).toBeLessThan(1);
    const overflow = await page.evaluate(() => document.documentElement.scrollHeight > innerHeight + 1 || document.documentElement.scrollWidth > innerWidth + 1);
    expect(overflow, `${width}×${height}`).toBe(false);
  }
});

test('fresh install starts Medium and last successful choice survives missing game save', async ({ page }) => {
  await page.goto('/play/'); await expect(page.locator('#difficulty')).toHaveText('Medium');
  await menu(page, 'new');
  await page.locator('#new-form [name="difficulty"]').selectOption('hard');
  await page.getByRole('button', { name: 'Start Puzzle', exact: true }).click();
  await expect(page.locator('#difficulty')).toHaveText('Hard');
  await page.evaluate(() => localStorage.removeItem('gridzero.web.game.v1'));
  await page.reload(); await expect(page.locator('#difficulty')).toHaveText('Hard');
  await menu(page, 'new');
  await expect(page.locator('#new-form [name="difficulty"]')).toHaveValue('hard');
  await page.locator('#new-form [name="difficulty"]').selectOption('easy');
  await page.locator('#new-dialog [data-close]').click();
  await page.reload(); await expect(page.locator('#difficulty')).toHaveText('Hard');
});
test('PWA manifest has a stable standalone identity and usable install icons', async ({ page }) => {
  await page.goto('/play/');
  const manifest = await (await page.request.get('/manifest.webmanifest')).json();
  expect(manifest.id).toBe('/play/'); expect(manifest.start_url).toBe('/play/'); expect(manifest.display).toBe('standalone');
  for (const size of [192, 512]) {
    const icon = manifest.icons.find((i: { sizes: string }) => i.sizes === `${size}x${size}`);
    expect(icon).toBeTruthy();
    const dimensions = await page.evaluate(async (url: string) => {
      const image = new Image(); image.src = url; await image.decode(); return [image.naturalWidth, image.naturalHeight];
    }, icon.src);
    expect(dimensions).toEqual([size, size]);
  }
  await expect(page.locator('link[rel="apple-touch-icon"]')).toHaveAttribute('href', '/assets/apple-touch-icon.png');
});

test('startup honors remembered generation and remains usable after cancellation', async ({ page }) => {
  await page.addInitScript(() => localStorage.setItem('gridzero.web.preferences.v1', JSON.stringify({ difficulty: 'custom', source: 'generated', customEmpty: 60 })));
  // Keep the worker pending so cancellation is deterministic rather than racing
  // a random puzzle that happened to generate unusually fast.
  await page.route('**/generator.worker-*.js', route => route.fulfill({ status: 200, contentType: 'application/javascript', body: 'self.onmessage = () => {};' }));
  await page.goto('/play/'); await expect(page.locator('#new-dialog')).toBeVisible();
  await expect(page.locator('#start-puzzle')).toHaveText('Preparing…');
  await page.locator('#new-dialog [data-close]').click();
  await menu(page, 'new'); await page.locator('#new-form [name="difficulty"]').selectOption('medium');
  await page.locator('#new-form [name="source"]').selectOption('collection');
  await page.getByRole('button', { name: 'Start Puzzle', exact: true }).click();
  await expect(page.locator('#new-dialog')).not.toBeVisible(); await expect(page.locator('#difficulty')).toHaveText('Medium');
});
