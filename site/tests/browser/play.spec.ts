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

test('lobby starts the selected game; informational pages stay script-free', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('#main')).not.toBeVisible();
  expect(await page.evaluate(() => localStorage.getItem('gridzero.web.game.v1'))).toBeNull();
  await page.locator('#new-form [name="difficulty"]').selectOption('hard');
  await page.locator('#new-form [name="mode"]').selectOption('classic');
  await page.getByRole('button', { name: 'Play', exact: true }).click();
  await expect(page).toHaveURL(/\/play\/$/);
  await expect(page.locator('#difficulty')).toHaveText('Hard');
  await expect(page.locator('#mode')).toHaveText('Classic');
  await expect(page.locator('[data-cell]')).toHaveCount(81);
  for (const route of ['/about/', '/privacy/', '/support/', '/credits/']) { await page.goto(route); await expect(page.locator('script')).toHaveCount(0); }
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
  for (let i = 0; i < 3; i++) {
    await page.getByRole('button', { name: 'Enter 1', exact: true }).click();
    await expect(page.locator('#main')).toHaveAttribute('data-entry-phase', 'idle');
  }
  await expect(page.locator('#notice-title')).toHaveText('Strike limit reached');
  expect((await saved(page)).strikes).toBe(3); expect((await saved(page)).board.values[2]).toBe(0);
  await page.reload(); await expect(page.locator('#notice-dialog')).toBeVisible();
  await page.locator('#notice-dialog').getByRole('button', { name: 'Continue in Classic', exact: true }).click();
  await page.locator('[data-cell="2"]').click();
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
  await page.getByRole('button', { name: 'Play', exact: true }).click();
  await expect(page.locator('#new-dialog')).not.toBeVisible({ timeout: 20_000 });
  const g = await saved(page); expect(g.puzzle.givens.filter(v => !v)).toHaveLength(20);
  expect(solutions(g.puzzle.givens)).toHaveLength(1);
  await page.route('**/generator.worker-*.js', route => route.fulfill({ status: 200, contentType: 'application/javascript', body: 'self.onmessage = () => {};' }));
  await menu(page, 'new'); await page.locator('#new-form [name="empty"]').fill('60');
  await page.getByRole('button', { name: 'Play', exact: true }).click();
  await page.locator('#cancel-generation').click();
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
  await expect(page.locator('#main')).toHaveAttribute('data-entry-phase', 'travelling');
  await expect(page.locator('#notice-dialog')).not.toBeVisible();
  await expect(page.locator('#notice-dialog')).toBeVisible();
  await page.getByRole('button', { name: 'Admire puzzle', exact: true }).click();
  await expect(page.locator('#status')).toBeEmpty();
  expect((await saved(page)).finished).toBe(true);
  await menu(page, 'restart'); await page.getByRole('button', { name: 'Restart', exact: true }).click();
  expect((await saved(page)).board.values).toEqual(example);
});
test('completion New game returns to lobby without replacing the completed save', async ({ page }) => {
  const g = fixture(); g.board.values = [...g.puzzle.solution]; g.board.values[2] = 0;
  await load(page, g); await page.locator('[data-cell="2"]').click();
  await page.getByRole('button', { name: 'Enter 4', exact: true }).click();
  await page.locator('#notice-dialog').getByRole('button', { name: 'New game', exact: true }).click();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.locator('#new-dialog')).toBeVisible();
  expect((await saved(page)).finished).toBe(true);
  await page.goBack();
  await expect(page.locator('#main')).toBeVisible();
  await expect(page.locator('#status')).toBeEmpty();
});
test('keyboard support and reduced motion', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' }); await load(page);
  await page.locator('[data-cell="2"]').click(); await page.keyboard.press('4');
  await expect(page.locator('[data-cell="2"] .value')).toHaveText('4');
  await expect(page.locator('.entry-flight')).toHaveCount(0);
  await page.keyboard.press('Control+z'); await expect(page.locator('[data-cell="2"] .value')).toHaveText('');
  await page.keyboard.press('ArrowRight'); await expect(page.locator('[data-cell="3"]')).toHaveAttribute('aria-pressed', 'true');
});
test('entry transitions serialize rapid input and show strikes at arrival', async ({ page }) => {
  await load(page); await page.locator('[data-cell="2"]').click();
  await page.getByRole('button', { name: 'Enter 4', exact: true }).click();
  await expect(page.locator('#main')).toHaveAttribute('data-entry-phase', 'travelling');
  expect(await page.locator('.entry-flight').evaluate(e => e.getAnimations()[0].effect!.getTiming().duration)).toBe(350);
  await expect(page.locator('[data-cell="2"] .value')).toBeEmpty();
  await page.evaluate(() => {
    for (const selector of ['[data-digit="1"]', '#notes', '#erase', '[data-cell="3"]']) {
      document.querySelector<HTMLButtonElement>(selector)!.click();
    }
  });
  expect((await saved(page)).strikes).toBe(0);
  expect((await saved(page)).undoStack).toHaveLength(1);
  await expect(page.locator('#main')).toHaveAttribute('data-entry-phase', 'idle');
  await expect(page.locator('[data-cell="2"] .value')).toHaveText('4');
  await expect(page.locator('#notes')).toHaveAttribute('aria-pressed', 'false');
  await expect(page.locator('[data-cell="2"]')).toHaveAttribute('aria-pressed', 'true');
  await page.locator('[data-cell="3"]').click();
  await page.evaluate(() => {
    const main = document.querySelector<HTMLElement>('#main')!;
    const observer = new MutationObserver(() => {
      if (main.dataset.entryPhase !== 'recoiling') return;
      observer.disconnect();
      main.dataset.recoilStrikes = String(document.querySelectorAll('.strike.used').length);
      document.querySelector<HTMLButtonElement>('[data-digit="1"]')!.click();
    });
    observer.observe(main, { attributes: true, attributeFilter: ['data-entry-phase'] });
  });
  await page.getByRole('button', { name: 'Enter 1', exact: true }).click();
  await expect(page.locator('.strike.used')).toHaveCount(0);
  await expect(page.locator('#main')).toHaveAttribute('data-recoil-strikes', '1');
  await expect(page.locator('.strike.used')).toHaveCount(1);
  await expect(page.locator('#main')).toHaveAttribute('data-entry-phase', 'idle');
  expect((await saved(page)).strikes).toBe(1);
  await expect(page.locator('.entry-flight, .cell.flying')).toHaveCount(0);
});
test('interrupting a flight settles the saved move and restores the cell', async ({ page }) => {
  await load(page); await page.locator('[data-cell="2"]').click();
  await page.getByRole('button', { name: 'Enter 4', exact: true }).click();
  await page.getByRole('button', { name: 'Game menu', exact: true }).click();
  await expect(page.locator('#menu-dialog')).toBeVisible();
  await expect(page.locator('.entry-flight, .cell.flying')).toHaveCount(0);
  await expect(page.locator('[data-cell="2"] .value')).toHaveText('4');
  await page.locator('#menu-dialog [data-close]').click();
  await page.locator('[data-cell="3"]').click();
  await page.getByRole('button', { name: 'Enter 6', exact: true }).click();
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(page.locator('#main')).toHaveAttribute('data-entry-phase', 'idle');
  await expect(page.locator('.entry-flight, .cell.flying')).toHaveCount(0);
  await expect(page.locator('[data-cell="3"] .value')).toHaveText('6');
  await page.reload();
  await expect(page.locator('[data-cell="2"] .value')).toHaveText('4');
  await expect(page.locator('[data-cell="3"] .value')).toHaveText('6');
});
test('invalid saves recover and storage failures are visible', async ({ page }) => {
  await page.addInitScript(() => localStorage.setItem('gridzero.web.game.v1', '{bad'));
  await page.goto('/play/'); await expect(page.locator('#lobby-error')).toContainText('previous save');
  await page.evaluate(() => { Storage.prototype.setItem = () => { throw new Error('storage disabled'); }; });
  await page.getByRole('button', { name: 'Play', exact: true }).click();
  await page.locator('.cell:not(.has-value)').first().click();
  await page.locator('#notes').click(); await page.getByRole('button', { name: 'Toggle note 1', exact: true }).click();
  await expect(page.locator('#save-status')).toContainText("Couldn't save your progress");
});
test('new game focuses the least-filled digit without selecting an input cell', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Play', exact: true }).click();
  const g = await saved(page);
  const counts = Array.from({ length: 9 }, (_, i) => g.board.values.filter(v => v === i + 1).length);
  const digit = Number(await page.locator('#board').getAttribute('data-digit'));
  expect(counts[digit - 1]).toBe(Math.min(...counts));
  await expect(page.locator('#board')).toHaveAttribute('data-focus', 'number');
  await expect(page.locator('.cell.selected, .cell.related')).toHaveCount(0);
  await expect(page.locator('.cell.matching')).toHaveCount(counts[digit - 1]);
  await page.keyboard.press('1');
  expect((await saved(page)).board).toEqual(g.board);
  expect((await saved(page)).strikes).toBe(0);
});
test('filled-cell taps focus all matching digits equally and number entry is a no-op', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' }); await load(page);
  await page.locator('[data-cell="0"]').click();
  await expect(page.locator('#board')).toHaveAttribute('data-digit', '5');
  await expect(page.locator('.cell.selected, .cell.related')).toHaveCount(0);
  const borders = await page.locator('.cell.matching').evaluateAll(elements => elements.map(element => {
    const style = getComputedStyle(element);
    return [style.boxShadow, style.backgroundColor];
  }));
  expect(borders.length).toBeGreaterThan(1);
  expect(new Set(borders.map(style => JSON.stringify(style))).size).toBe(1);
  expect(borders[0][0]).not.toBe('none');
  await page.keyboard.press('1');
  expect((await saved(page)).strikes).toBe(0);
  await page.locator('[data-cell="2"]').click();
  await expect(page.locator('#board')).toHaveAttribute('data-focus', 'cell');
  await expect(page.locator('.cell.selected')).toHaveCount(1);
  await expect(page.locator('.cell.matching')).toHaveCount(0);
  await page.getByRole('button', { name: 'Enter 4', exact: true }).click();
  await expect(page.locator('#board')).toHaveAttribute('data-digit', '4');
  await page.keyboard.press('1');
  expect((await saved(page)).strikes).toBe(0);
  expect((await saved(page)).undoStack).toHaveLength(1);
  await expect(page.locator('[data-cell="2"] .value')).toHaveText('4');
  await page.locator('#erase').click();
  await expect(page.locator('[data-cell="2"] .value')).toBeEmpty();
  await expect(page.locator('[data-cell="2"]')).toHaveClass(/selected/);
});
test('offline reload includes the collection and generator worker', async ({ page, context, browserName }) => {
  test.skip(browserName === 'webkit', 'Playwright WebKit does not expose service worker control.');
  await load(page);
  await page.evaluate(async () => { await navigator.serviceWorker.ready; });
  await expect.poll(() => page.evaluate(() => !!navigator.serviceWorker.controller)).toBe(true);
  await context.setOffline(true); await page.reload();
  await expect(page.locator('[data-cell]')).toHaveCount(81);
  await menu(page, 'new');
  await page.reload();
  await expect(page.locator('#new-dialog')).toBeVisible();
  await page.getByRole('button', { name: 'Play', exact: true }).click();
  await expect(page.locator('#new-dialog')).not.toBeVisible();
  await menu(page, 'new'); await page.locator('#new-form [name="difficulty"]').selectOption('custom');
  await page.locator('#new-form [name="empty"]').fill('20');
  await page.getByRole('button', { name: 'Play', exact: true }).click();
  await expect(page.locator('#new-dialog')).not.toBeVisible();
});
test('fresh Play always fills the page width, including short browser windows', async ({ page }) => {
  await page.goto('/');
  await page.getByRole('button', { name: 'Play', exact: true }).click();
  for (const [width, height] of [[320, 568], [375, 667], [390, 664], [430, 740], [390, 844], [430, 932], [844, 390], [1024, 768], [768, 1024], [1440, 900], [600, 500], [280, 480]]) {
    await page.setViewportSize({ width, height });
    const boxes = await page.locator('#board, .keypad, .tools').evaluateAll(elements => elements.map(e => {
      const r = e.getBoundingClientRect(); return { x: r.x, y: r.y, right: r.right, bottom: r.bottom, width: r.width, height: r.height };
    }));
    const pageWidth = await page.evaluate(() => document.documentElement.clientWidth);
    for (const box of boxes) { expect(box.x).toBeGreaterThanOrEqual(-1); expect(box.y).toBeGreaterThanOrEqual(0); expect(box.right).toBeLessThanOrEqual(pageWidth + 1); }
    expect(Math.abs(boxes[0].width - boxes[0].height)).toBeLessThan(1);
    expect(boxes[0].x).toBe(0);
    expect(boxes[0].width, `full-width board at ${width}×${height}`).toBe(pageWidth);
    expect(boxes[1].y).toBeGreaterThanOrEqual(boxes[0].bottom);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);
    expect(overflow, `${width}×${height}`).toBe(false);
  }
  await page.locator('#status').evaluate(element => { element.textContent = 'Incorrect number'; });
  expect((await page.locator('#board').boundingBox())!.width).toBe(await page.evaluate(() => document.documentElement.clientWidth));
});

test('lobby defaults Medium and remembers only successfully started choices', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('#new-form [name="difficulty"]')).toHaveValue('medium');
  await page.locator('#new-form [name="difficulty"]').selectOption('hard');
  await page.getByRole('button', { name: 'Play', exact: true }).click();
  await expect(page.locator('#difficulty')).toHaveText('Hard');
  // Clear on the next document before startup; pagehide intentionally saves the
  // current in-memory game, so clearing immediately before reload is not enough.
  await page.addInitScript(() => localStorage.removeItem('gridzero.web.game.v1'));
  await page.reload(); await expect(page.locator('#new-dialog')).toBeVisible();
  await expect(page.locator('#new-form [name="difficulty"]')).toHaveValue('hard');
  await page.locator('#new-form [name="difficulty"]').selectOption('easy');
  await page.reload(); await expect(page.locator('#new-form [name="difficulty"]')).toHaveValue('hard');
});
test('PWA manifest has a stable standalone identity and usable install icons', async ({ page }) => {
  await page.goto('/play/');
  const manifest = await (await page.request.get('/manifest.webmanifest')).json();
  expect(manifest.id).toBe('/play/'); expect(manifest.start_url).toBe('/'); expect(manifest.scope).toBe('/'); expect(manifest.display).toBe('standalone');
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
  await expect(page.locator('#new-form [name="difficulty"]')).toHaveValue('custom');
  await page.getByRole('button', { name: 'Play', exact: true }).click();
  await expect(page.locator('#start-puzzle')).toHaveText('Preparing…');
  await page.locator('#cancel-generation').click();
  await page.locator('#new-form [name="difficulty"]').selectOption('medium');
  await page.locator('#new-form [name="source"]').selectOption('collection');
  await page.getByRole('button', { name: 'Play', exact: true }).click();
  await expect(page.locator('#new-dialog')).not.toBeVisible(); await expect(page.locator('#difficulty')).toHaveText('Medium');
});
