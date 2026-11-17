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
600×500, 844×390, 768×1024, 1024×768, 1440×900. Phone full-width checks include
browser-chrome-sized viewports; very short windows shrink the board to preserve
reachable controls.

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
