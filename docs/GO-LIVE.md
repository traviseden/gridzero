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
