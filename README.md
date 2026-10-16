# GridZero

**Sudoku. Zero distractions.** A free, open-source Sudoku app for iPhone, iPad, Android, and the browser. Swift/SwiftUI on Apple platforms; native Kotlin on Android; Astro and TypeScript on the web. Website: **gridzero.win**. Browser game: **gridzero.win/play/**.

**Android:** [build, install, and verification instructions](android/README.md). Tested on Murena / OnePlus 6 and GrapheneOS / Pixel 10; no Google services required.

**Start here:** [Laptop setup and signing recovery](docs/LAPTOP-SETUP.md).

**Follow the product:** [Shared specification](docs/SPEC.md) · [Go-live checklist for all three platforms](docs/GO-LIVE.md) · [Free puzzle data & credits](docs/puzzle-data.md).

## The app

- Edge-to-edge 9×9 board on portrait iPhones and a staggered thumb-friendly keypad: `1 3 5 7 9` above `2 4 6 8`.
- **Challenge:** immediate solution checking, three strikes by default; configurable 3 / 5 / 10 / unlimited. Wrong entries are rejected. Undo never removes strikes.
- **Classic:** freely enter hypotheses, then explicitly Check Board. No automatic error checking or strikes.
- Manual 3×3 pencil notes by default; opt-in Fill Notes and automatic cleanup. Undo/redo restores whole moves, including affected notes.
- Easy / Medium / Hard / Expert collection; optional offline generation; Custom with 20–60 empty squares and exact-count uniqueness checks.
- Starts on Medium for a fresh install. Resumes a saved game unchanged and remembers the last successfully started difficulty, mode, source, and custom count on each platform.
- Ink / Moss / Clay; System / Light / Dark / opt-in clock schedule.
- Atomic local autosaves, optional timer, optional haptics, VoiceOver labels. Universal iPhone/iPad support, portrait and landscape, and adaptive iPad window sizes. Gameplay never requires scrolling.
- Portrait tablets use a centered board capped at 720 points and a keypad capped at 480 points. Landscape puts the keypad beside the board; small windows tighten spacing and scale the board before any controls clip.
- Entered digits fly from the staggered keypad to the selected cell. Rejected Challenge entries turn red and recoil; the cell shakes and strikes appear as Xs. Reduce Motion uses immediate feedback without travel or shaking.
- No accounts, ads, purchases, analytics, third-party runtime dependencies, or network requirements for gameplay.

## Build for iOS / iPadOS

All builds and tests can run from Terminal; the Xcode and Simulator GUI apps can stay closed. Install Xcode's command-line tools and an iOS simulator runtime first. Alternatively, open **GridZero.xcodeproj**, select the GridZero scheme and a device, and Run.

Personal signing settings live in **`Signing.local.xcconfig`**, which is gitignored and survives project regeneration. Copy `Signing.local.xcconfig.example` to that filename and enter your Apple Developer team identifier. You can also pass `DEVELOPMENT_TEAM=…` to `xcodebuild`. The bundle identifier is `win.gridzero.app`; change it if required by your team.

The project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen); the generated project is included so XcodeGen isn't required to open it. If editing project structure:

```sh
brew install xcodegen
xcodegen generate
```

Build the simulator app without a signing team:

```sh
xcodebuild -project GridZero.xcodeproj -scheme GridZero \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

Use a supported, stable Xcode release with the iOS 26 SDK or newer for App Store submission. Current simulator checks use Xcode 27 and an iOS 27 runtime; the app's deployment target remains iOS 26.0. Verify on an iOS 26 device/runtime before release.

## Verification

```sh
swift test
xcodebuild -project GridZero.xcodeproj -scheme GridZero \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO -collect-test-diagnostics never test
npm --prefix site ci
npm --prefix site run build
python3 tools/check_site.py
```

The pure Swift tests cover solver consistency and ambiguity, strike semantics, Classic completion, candidate cleanup/undo, save validation, collection puzzles, exact custom counts, logical generation grading, cancellation, and window geometry. Geometry checks cover 40 simulator model profiles in both orientations with conservative safe-area budgets, 2,960 resizable-window/breakpoint sizes, and Display Zoom sizes.

The UI tests check note entry/undo, number rejection, staggered keypad geometry, edge-to-edge phone layout, theme switching, and relaunch. Layout checks exercise portrait/landscape on representative hardware for each distinct display size, plus embedded iPad window-size cases. See [device inventory](docs/device-layouts.md) and [verification results](docs/layout-verification.md).

For the headless layout matrix:

```sh
python3 tools/device_inventory.py
xcodebuild -project GridZero.xcodeproj -scheme GridZero \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build-for-testing
python3 tools/verify_layouts.py --resume
python3 tools/verify_layouts.py --windows --resume
python3 tools/verify_layouts.py --gameplay --resume
```

The runner creates one temporary simulator at a time and shuts it down/deletes it afterward. It leaves existing personal simulators alone. Screenshots and result bundles are saved under `build/layout-results/`. The iPad viewport probe exists only in Debug builds with explicit test environment variables; Release always uses the real window size.

## Puzzle provenance and generation

The bundled collection contains **2,000 puzzles per difficulty (8,000 total)** from [Grant McLean's Sudoku Exchange puzzle bank](https://github.com/grantm/sudoku-exchange-puzzle-bank). Thank you to Grant McLean / Sudoku Exchange, [Stephen Ostermiller's QQWing](https://github.com/stephenostermiller/qqwing) for upstream generation, and [SudokuMonster's Sukaku Explainer](https://github.com/SudokuMonster/SukakuExplainer) for ratings. Easy / Medium / Hard / Expert map to upstream Easy / Medium / Hard / Diabolical. The dataset is public domain, with its license retained in `Sources/GridZeroCore/Resources/Puzzle-LICENSE.txt`. Full provenance and alternative-source research are in [docs/puzzle-data.md](docs/puzzle-data.md) and on `/credits/`.

`tools/import_puzzles.py` downloads a pinned revision and independently verifies all 8,000 puzzles have exactly one solution, valid IDs/ratings, and no duplicate IDs/boards. It produces an **840 KB** text resource and `collection.json` provenance/count/checksum metadata. The upstream bank has 893,916 records at that revision; the original 400 limit was our selection, not the source's capacity. This tool uses the network; native gameplay does not. To reproduce the selection:

```sh
python3 tools/import_puzzles.py
# Optional larger bundle: --per-difficulty 5000
```

Generation uses randomized backtracking to construct a completed board, removes clues only while uniqueness is preserved, then applies a small logical grader:

| Level | Grader |
|---|---|
| Easy | Naked singles |
| Medium | Hidden singles required |
| Hard | Locked candidates or naked pairs required |
| Expert | Beyond these techniques; may require search |

Generated and collection ratings aren't directly equivalent. Expert is a classification beyond the implemented logical strategies, not a guarantee of a particular advanced technique. Custom controls empty cells, not difficulty. Generation is cancellable, limited to 100 attempts / roughly 15 seconds plus the current bounded solver pass. A solver node budget conservatively rejects inconclusive uniqueness checks. Impossible or unlucky requests report failure rather than returning ambiguous boards or silently changing settings.

## Small by design

System fonts, SF Symbols, code-drawn board, code-defined themes, one opaque app icon, and a compact collection. Release builds use size optimization (`-Osize`) and dead-code stripping. The core is a local Swift package linked into the app. No external packages are downloaded. Use a Release archive and Xcode's export/app-thinning report to measure actual App Store download size; simulator/debug sizes aren't representative.

Regenerate the icon with `swift tools/make_icon.swift` (macOS only).

## Website

`site/` is an Astro static site. The homepage, privacy, support, and credits pages ship no JavaScript. `/play/` runs a first-party TypeScript port of the native game: the same Challenge/Classic rules, staggered keypad, manual notes, whole-board undo/redo, settings, and 8,000-puzzle collection. Generation runs in a cancellable worker, with the same uniqueness budget and logical grading. No framework runtime, third-party gameplay dependencies, network APIs, or tracking.

Browser progress and preferences are stored locally, independently of native app saves. A versioned service worker caches the production game and generator for offline use after the first load (HTTPS or localhost required). Haptics depend on browser vibration support; iOS Safari does not support vibration. Install to your phone's home screen with the browser's Add to Home Screen action.

The PWA includes a stable manifest ID, standalone display, 192/512 PNG icons, and an Apple touch icon. Safari: Share → Add to Home Screen; Android: browser menu → Install app / Add to home screen. Installation needs no store account. Browser storage may be cleared/evicted and may differ between the tab and installed app. [Publishing and physical-device PWA checks](docs/GO-LIVE.md#2-web--pwa--publish-first-if-desired).

Use Node 24+:

```sh
cd site
npm ci
npm run dev
# http://localhost:4321/play/

npm test
npm run build
npx playwright install chromium webkit
npm run test:ui
cd ..
python3 tools/check_site.py
```

Cloudflare Pages settings:

| Setting | Value |
|---|---|
| Framework | None |
| Build command | `npm --prefix site ci && npm --prefix site run build` |
| Output directory | `site/dist` |
| Node version | `24` or newer |
| Domain | `gridzero.win` |

The GitHub links point to `https://github.com/traviseden/gridzero`. The homepage's primary action is Play now; native releases remain honestly marked coming soon until approved App Store / TestFlight / Android links are available. No fake download links are shipped. Existing Cloudflare Pages projects must update their build command and output directory to the values above.

The app privacy manifest declares no tracking or collected data, and the app-only UserDefaults access reason. The website's privacy page separately explains hosting and Apple's TestFlight service.

## Layout

```text
GridZero/                       SwiftUI app, settings, local persistence
android/                        Native Kotlin Android app and Gradle wrapper
Sources/GridZeroCore/           Engine, solver, generator, puzzle collection
Tests/GridZeroCoreTests/        Pure Swift correctness tests
UITests/                       Gameplay and cross-device layout checks
site/                          Astro site and offline-ready browser game
tools/                         Puzzle import, artwork, and headless device checks
docs/                          Device inventory and verification results
project.yml                    Reproducible Xcode project definition
```

## License

App, website, and original artwork: MIT. Bundled puzzle data: public domain. See `LICENSE` and the retained puzzle license.

## GitHub Actions and costs

Actions run correctness/build checks, not store publishing. Standard runners are free for public repositories; this workflow now skips every job in private repositories and uploads no artifacts or dependency caches. You do not need paid GitHub. Disable Actions if preferred and run the same commands locally. See [cost controls](docs/GO-LIVE.md#5-github-actions-cost-control-and-zero-github-bill-policy); Apple/Google publisher fees are separate.
