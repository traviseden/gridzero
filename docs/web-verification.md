# Web verification and handoff

## November 17, 2026 — web-only transition

- Pushed `walled-garden` from committed `main`, before any changes in this session.
  It preserves the native apps and original website.
- Committed the first web fixes (phone layout, terminal QR, interim completion
  changes) as `ed5f483`.
- Removed native projects, engines, tests, screenshots, SDK/signing helpers, and
  native CI jobs. Moved the canonical puzzle data to `site/src/data/`.
- `/` is the lobby: existing difficulty/mode/source/custom controls, Play, About.
  No puzzle starts until Play. Preferences commit only on successful puzzle creation.
- `/play/` restores a valid save; without one it opens the lobby. New game returns
  to `/`. Completion offers New game / Admire puzzle, with no completion footer
  or extra heading/summary.
- About contains relevant existing web-app information. Privacy/Help/Credits and
  their shared layout no longer advertise native apps or use marketing headings.
- Manifest retains `id: /play/` for installed-app identity, with start URL/scope `/`.
  Offline caching covers lobby, game, informational pages, engine, and worker.
- Owner runs the dev server. Do not start or stop their server without a request.
- Verified: all 11 core tests passed (including collection uniqueness/checksum),
  Astro check/build passed, local links passed, 29 browser tests passed with one
  WebKit offline skip. Reviewed lobby/board screenshots at 390×664.
- Web-only redesign is a separate local commit after `ed5f483`; only the archive
  branch has been pushed. Production deployment is not part of this checkpoint.

## Run checks

```sh
npm --prefix site ci
npm --prefix site test
npm --prefix site run build
python3 tools/check_site.py
cd site
npx playwright install chromium webkit
npm run test:ui
```

Browser tests serve `site/dist` using `tools/serve_site.py` with the production
security headers. Chromium and iPhone WebKit cover selection, modes, settings,
generation/cancellation, notes/history, persistence, completion navigation,
keyboard/Reduce Motion, and responsive layout. Core tests verify all 8,000 puzzle
solutions and collection checksum, solver/generation, game rules, and validation.

Chromium tests offline lobby reload and collection/worker play. Playwright cannot
control WebKit service workers; that test is skipped there. Physical iPhone and
Android install/offline/update checks remain manual release gates.

Layout cases: 280×480, 320×568, 375×667, 390×664, 390×844, 430×740, 430×932,
600×500, 844×390, 768×1024, 1024×768, 1440×900.

Follow-up: owner requires full page width unconditionally. Removed all board
height constraints, width caps, and side-by-side landscape layout. The square
board is 100% page width; controls follow below, with vertical scrolling as needed.
Fresh lobby → Play tests verify full width at every size and with visible status
text. Astro check/build and both Chromium/WebKit layout tests passed. Next:
owner reviews the regular-browser phone layout.

Follow-up: moved Undo / Erase / Notes below the number keypad in document order,
so visual, keyboard, and screen-reader order agree.

## Entry transition and lobby refinement

- Accepted travel is now 600ms (previously 240ms); rejection is 600ms travel plus
  450ms recoil. The digit stays visible during travel and lands at the cell's
  computed font size/weight instead of fading out before the value appears.
- Explicit idle/travelling/recoiling state guards gameplay input. Saves commit
  immediately, presentation waits for arrival, and outcomes wait for settling.
  Rapid taps no longer cancel an active flight or accumulate duplicate strikes.
- Menu, navigation, resize, visibility, and Reduce Motion interruptions settle
  the saved state and clean up animations. Document-positioned flights follow
  scrolling instead of staying attached to the viewport.
- Lobby restyled using existing controls/copy only. Reviewed phone light,
  custom/dark, and desktop screenshots.
- Astro check/build passed; 33 browser tests passed, one WebKit offline skip.
  Added coverage for rapid input, delayed strike feedback, outcome ordering,
  menu/Reduce Motion interruption, and saved moves after interruption.
- Next: owner judges animation pacing and lobby appearance on physical phones.

Follow-up: travel shortened to 450ms at the owner's request; recoil remains
450ms. Astro's development toolbar is disabled in `site/astro.config.mjs`.

Latest pacing adjustment: travel is 350ms; recoil remains 450ms.

Release checks for the 350ms build: Astro check/build, link validation, all 11
core tests, and 33 browser tests passed (one existing WebKit offline skip).

Released `77e7057` to GitHub and Cloudflare Pages at
https://0ebc2a10.gridzero.pages.dev / https://gridzero.win/.
Live assets match the build; production WebKit gameplay/persistence smoke passed.
See `GO-LIVE.md` for deployment details and remaining physical-device checks.

## Local network development

`npm --prefix site run dev` listens on the LAN and prints a lobby QR code for
external IPv4 addresses. Connect phones to the same Wi-Fi. Astro reloads edits.
If Astro starts in background mode, `cd site && npx astro dev logs` shows the QR;
`npx astro dev stop` stops it.

Plain LAN HTTP supports gameplay/layout tests. Physical-device PWA/offline testing
requires HTTPS. Browser storage is local, not a backup. No persistent-storage
request, export/import, or account sync has been added.

## Next owner checkpoint

Review the lobby and completion flow on physical phones, including installed PWA
navigation back to `/`. There is deliberately no new Resume control on the lobby;
`/play/` still restores the current game. Any additional lobby controls require
the owner's design decision.
