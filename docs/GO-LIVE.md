# Web release checks

- [ ] Core tests, Astro check/build, local-link validation, Chromium and WebKit tests.
- [ ] Physical iPhone Safari and Android Chrome: lobby, Play, board, rotation,
      settings, completion, New game, Admire puzzle, reload persistence.
- [ ] HTTPS Home Screen installation opens the lobby without external browser UI.
- [ ] After an online load, lobby, game, collection, generation, and About work offline.
- [ ] Updating the deployed app preserves saves and preferences.
- [ ] Existing installed PWA upgrades retain their identity (`id: /play/`).
- [ ] Storage failures remain visible; no false backup or guaranteed-persistence claims.

Native releases are retired; their previous gates remain on `walled-garden`.

## November 17, 2026 deployment

- Application commit: `77e7057`, pushed to GitHub `main`.
- Cloudflare Pages project: `gridzero`; production branch: `main`.
- Direct upload of `site/dist` using Wrangler 4 and the existing `cf` OAuth
  credentials passed privately through the subprocess environment. No Git-triggered
  deployment is configured.
- Deployment: https://0ebc2a10.gridzero.pages.dev
- Production: https://gridzero.win/
- Verified production HTML for lobby/game/About, manifest, service worker, styles,
  game bundle, and generator worker match the local build byte-for-byte.
- Production WebKit smoke passed: lobby → Play, 390px full-width board, animated
  entry, and save restoration after reload, with no JavaScript errors.
- Local release checks: 11 core tests, 33 browser tests passed, one WebKit offline
  skip; Astro check/build and local-link validation passed.
- Physical-device install/offline/update review remains manual. Existing clients
  may need all GridZero tabs/windows closed and reopened to activate a waiting
   service-worker update; do not clear site data to update.

## November 18, 2026 layout deployment

- Application commit: `0a4a3e4`, pushed to GitHub `main`.
- Deployed `site/dist` to Cloudflare Pages project `gridzero`, production branch
  `main`, using Wrangler 4 and existing OAuth credentials passed privately via
  the subprocess environment.
- Deployment: https://be1b43c3.gridzero.pages.dev
- Production: https://gridzero.win/
- All 20 served production files match the checked local build byte-for-byte.
- Production WebKit smoke passed: vertically centered landscape lobby, Play,
  full-height board, 32px tool icons, actual strike-out, reload persistence,
  focused New Puzzle default, and Enter returning to the lobby. No JS errors.
- The first smoke attempt injected a replacement save into a running game;
  the normal page-hide save overwrote that fixture. Verification was corrected
  to lose the actual game through keypad input and passed.
- Local release checks: 13 core tests and 50 browser tests passed, four existing
  WebKit service-worker skips; Astro check/build, local-link and whitespace checks
  passed.
- Owner approved the visual changes. Next checkpoint: physical-device review of
  the deployed layout and installed-PWA update behavior.

### Desktop correction

- Application commit: `0f1ef4d`, pushed to `main`.
- Deployment: https://7d738c50.gridzero.pages.dev
- Production: https://gridzero.win/
- All 20 served files match the local build. Live Chromium smoke verified
  540px boards at 900×1100 and 1440×900, 454px at 800×600, and the existing
  390px phone boards in both orientations. Desktop controls remain fully visible
  without page scrolling; no JavaScript errors.
- Build, 13 core tests, 50 browser tests, link and whitespace checks passed;
  four existing WebKit service-worker skips remain.
- Next checkpoint: owner reviews the corrected desktop size in their window.

## November 19, 2026 wordmark fix

- Application commit: `27fabea`, pushed to `main`.
- Cloudflare Pages deployment: https://fe49dd42.gridzero.pages.dev
- All 20 served files at https://gridzero.win/ match the verified build.
- Production iPhone WebKit smoke: tapping the wordmark during play leaves the
  current board and note intact. The About wordmark still returns to the lobby.
  No JavaScript errors.

## November 25, 2026 — tabletop gameplay and Last tile

- Released application commit `2be9fae` from `tabletop-gameplay` to the existing
  Pages production environment by direct upload. Deployment:
  https://113b8695.gridzero.pages.dev/ · Production: https://gridzero.win/
- All 23 public production files matched the checked build byte-for-byte.
  A fresh WebKit session completed a Classic board with Reduce Motion and
  verified that the win cue's four tones started once alongside the completion actions.
- Build and link checks passed; 15 core and 58 browser tests passed, with the
  four existing WebKit service-worker skips. Next physical check: hear the final
  harmony on the iPad and confirm the installed app updates with its save intact.

## November 26, 2026 — completed digits and root app layout

- Deployed `76fec7d` from `main`, including the completed-digit fix `2283128`,
  to https://33562cb0.gridzero.pages.dev. All 20 files served at
  https://gridzero.win/ match the verified root `dist/` build.
- Live iPhone-emulated WebKit opened the lobby, started a puzzle, and confirmed
  that with nine fives on the board the 5 button is disabled and the 5 key adds
  no strike. Local checks: 14 core tests and 54 browser tests passed, four
  WebKit skips; build and link checks passed.
