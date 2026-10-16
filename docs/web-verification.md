# Browser verification

The Astro site is statically generated. Only `/play/` loads JavaScript, with a
first-party TypeScript game engine and a separate generator worker. The native
Swift puzzle resource is imported directly at build time, not duplicated.

## Run

```sh
npm --prefix site ci
npm --prefix site test
npm --prefix site run build
python3 tools/check_site.py
cd site
npx playwright install chromium webkit
npm run test:ui
```

Playwright serves `site/dist` through `tools/serve_site.py`, including the real
Cloudflare `_headers` security policy. Tests use Chromium and iPhone WebKit.

## Coverage

- All 8,000 collection puzzles have exactly one solution, with 2,000 per difficulty.
- Solver consistency, ambiguity, completion, and node-budget-safe uniqueness.
- Challenge rejection, strike persistence, strike-out, unlimited strikes, and
  continuation in Classic; valid-board-only completion in Classic.
- Manual note toggles, cleanup, Fill Notes based only on the current board,
  whole-board undo/redo, and fixed clues.
- Custom generation at exact empty counts; generated difficulty grading matches
  the native naked-single / hidden-single / locked-candidate / naked-pair grader.
- Save validation, browser reload persistence, invalid-save recovery, and visible
  storage-failure messages.
- Settings, themes, fixed per-game strike rules, keyboard controls, Reduce Motion,
  worker cancellation, completion, restart, and explicit Classic checking.
- Fresh Medium default, remembered successful difficulty with no game save,
  cancelled choices not changing defaults, remembered generation on startup, and
  recovery through the chooser after cancelling initial generation.
- Stable standalone PWA manifest and actual 192/512 PNG icon dimensions.
- Chromium offline reload, new collection puzzles, and offline worker generation.
  The WebKit offline test is skipped because Playwright does not expose WebKit
  service worker control; physical iPhone offline installation remains a manual check.
- No-scroll, square-board layout checks at 280×480, 320×568, 375×667, 390×844,
  430×932, 600×500, 844×390, 768×1024, 1024×768, and 1440×900.

Browser storage is separate from native saves. Browser haptics depend on vibration
API support and are unavailable on iOS Safari. Offline caching requires HTTPS or
localhost and a successful initial load. Informational pages remain script-free.
