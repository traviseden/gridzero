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

## Live phone development

Run `npm --prefix site run dev` on the Mac. Astro listens on the LAN and prints
a terminal QR code for `/play/` on each external IPv4 address. Connect phones to
the same Wi-Fi; Astro live-reloads edits. If Astro starts in background mode,
use `cd site && npx astro dev logs` to view the QR code, and `npx astro dev stop`
to stop it. Plain LAN HTTP supports layout/gameplay testing; install/offline
verification requires HTTPS (or localhost on the device itself).

### November 17, 2026 checkpoint

- Follow-up: removed the web completion footer and intermediate Another puzzle /
  Done dialog. Completion opens New Puzzle directly; dismissing it preserves the
  finished board. Current iOS source also has the rejected completion UI; need
  the owner's earlier iOS reference before claiming exact parity.
- Empty status rows no longer reserve phone height. Full-width checks include
  browser-chrome-sized viewports 390×664 and 430×740. Extremely short viewports
  still shrink the square board to keep controls reachable without scrolling.
- Follow-up Astro check/build and completion/layout tests passed in Chromium and
  iPhone WebKit (four tests). Owner controls the dev server; the agent stopped its
  server on request. Next: physical-phone review and earlier iOS UI reference.

- Extended the existing compact phone layout through 750px viewport height,
  reclaiming space before shrinking the board. Verified the live LAN page at
  375×667: board starts at x=0 and measures 375×375.
- Astro check/build passed; existing ten-viewport no-scroll/square-board checks
  passed in Chromium and iPhone WebKit.
- Dev server started at `http://10.0.0.202:4321/play/`; QR output and HTTP 200
  verified. This address depends on the Mac's current network.
- Next: owner checks layout/live reload on physical phones. Fullscreen UI awaits
  a decision about adding a menu control. Fullscreen API requires browser support
  and a user gesture, not PWA installation; iPhone Home Screen standalone launch
  is the reliable browser-chrome-free route. Tablet/desktop sizing retains the
  shared specification's square-board caps and landscape arrangement.

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
