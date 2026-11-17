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
