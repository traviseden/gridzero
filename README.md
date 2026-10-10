# GridZero

**Sudoku. Zero distractions.** A free, open-source Sudoku app for iPhone, iPad, and Android. Swift/SwiftUI on Apple platforms; native Kotlin on Android. Website: **gridzero.win**.

**Android:** [build, install, and verification instructions](android/README.md). Tested on Murena / OnePlus 6 and GrapheneOS / Pixel 10; no Google services required.

## The app

- Edge-to-edge 9×9 board on portrait iPhones and a staggered thumb-friendly keypad: `1 3 5 7 9` above `2 4 6 8`.
- **Challenge:** immediate solution checking, three strikes by default; configurable 3 / 5 / 10 / unlimited. Wrong entries are rejected. Undo never removes strikes.
- **Classic:** freely enter hypotheses, then explicitly Check Board. No automatic error checking or strikes.
- Manual 3×3 pencil notes by default; opt-in Fill Notes and automatic cleanup. Undo/redo restores whole moves, including affected notes.
- Easy / Medium / Hard / Expert collection; optional offline generation; Custom with 20–60 empty squares and exact-count uniqueness checks.
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

The bundled collection contains **100 puzzles per difficulty** from [Grant McLean's Sudoku Exchange puzzle bank](https://github.com/grantm/sudoku-exchange-puzzle-bank). It was generated with QQWing and rated with Sukaku Explainer. Easy / Medium / Hard / Expert map to upstream Easy / Medium / Hard / Diabolical. The dataset is public domain, with its license retained in `Sources/GridZeroCore/Resources/Puzzle-LICENSE.txt`.

`tools/import_puzzles.py` downloads and independently verifies all 400 puzzles have exactly one solution. It produces a **42 KB** text resource containing puzzle IDs, boards, and ratings. This tool uses the network; the app does not. To refresh the selection:

```sh
python3 tools/import_puzzles.py
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

`site/` is plain HTML and CSS, local artwork and a real simulator screenshot. No JavaScript or tracking. Preview locally:

```sh
python3 -m http.server 8000 --directory site
```

Cloudflare Pages settings:

| Setting | Value |
|---|---|
| Framework | None |
| Build command | `exit 0` |
| Output directory | `site` |
| Domain | `gridzero.win` |

The GitHub links are prepared for `https://github.com/traviseden/gridzero`; publish the repository there or update them before deploying. Replace the homepage's honest “Coming soon” release status with the approved App Store and TestFlight links when available. No fake download links are shipped.

The app privacy manifest declares no tracking or collected data, and the app-only UserDefaults access reason. The website's privacy page separately explains hosting and Apple's TestFlight service.

## Layout

```text
GridZero/                       SwiftUI app, settings, local persistence
android/                        Native Kotlin Android app and Gradle wrapper
Sources/GridZeroCore/           Engine, solver, generator, puzzle collection
Tests/GridZeroCoreTests/        Pure Swift correctness tests
UITests/                       Gameplay and cross-device layout checks
site/                          Static Cloudflare Pages site
tools/                         Puzzle import, artwork, and headless device checks
docs/                          Device inventory and verification results
project.yml                    Reproducible Xcode project definition
```

## License

App, website, and original artwork: MIT. Bundled puzzle data: public domain. See `LICENSE` and the retained puzzle license.
