# GridZero

Free, open-source Sudoku for the web. No accounts, ads, or tracking.

`/` is the game lobby. Choose difficulty, mode, and source, then Play.
`/play/` is the board and resumes a saved game. `/about/` contains project,
installation, and offline information.

## Development

Node 24 or newer:

```sh
npm --prefix site ci
npm run dev
```

Astro listens on the local network and prints a QR code for the lobby.
Connect phones to the same Wi-Fi for live updates. If Astro starts in background
mode, `cd site && npx astro dev logs` shows the QR; `npx astro dev stop` stops it.
HTTPS is required for physical-device offline/PWA testing.

## Checks

```sh
npm --prefix site test
npm --prefix site run build
python3 tools/check_site.py
cd site
npx playwright install chromium webkit
npm run test:ui
```

Deploy `site/dist` as a static site. Build command: `npm --prefix site ci && npm --prefix site run build`.

## Project

- [Product specification](docs/SPEC.md)
- [Gameplay and state-machine diagrams](GAMEPLAY.md)
- [Browser verification and handoff](docs/web-verification.md)
- [Release checks](docs/GO-LIVE.md)
- [Puzzle provenance](docs/puzzle-data.md)

The 8,000-puzzle collection lives in `site/src/data/` and is imported at build
time. Code and original artwork are MIT licensed; puzzle data is public domain.

The retired iOS and Android implementations are preserved on the
[`walled-garden`](https://github.com/traviseden/gridzero/tree/walled-garden) branch.
