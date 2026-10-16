# GridZero shared product specification

**Version 1.1 · October 12, 2026 · Applies to iOS/iPadOS, Android, and Web/PWA.**

This is the product contract, not a promise that every release has been verified
on every device. See [go-live gates](GO-LIVE.md), [data provenance](puzzle-data.md),
and platform verification reports. Changes to rules, defaults, collection format,
or user-facing behavior must update this document and all three implementations.

## 1. Product promise

Sudoku. Zero distractions. Free to play; no ads, accounts, purchases, analytics,
tracking, social features, or required gameplay network calls. The native apps
work offline from installation; the web app needs an initial HTTPS visit, then
caches the game for offline play. No cross-device sync is implied.

| Platform | Implementation | Identifier / minimum |
|---|---|---|
| iOS / iPadOS | SwiftUI; shared Swift core | `win.gridzero.app`; iOS 26+ |
| Android | Kotlin; native views/canvas | `win.gridzero.android`; API 26+; currently targets API 36 |
| Web / PWA | Astro static pages; TypeScript engine; generator worker | `https://gridzero.win/play/`; modern browser |

The implementations share behavior and data, not runtime code. Native controls
and accessibility conventions can differ. Browser haptics are optional where the
Vibration API exists; iOS Safari does not support it. Browser installation and
storage behavior depend on the OS/browser and must not be presented as guaranteed
native equivalence.

## 2. Startup, defaults, and remembered choices

1. A valid saved game always resumes **unchanged**, including its difficulty,
   mode, solution, strike limit, strikes, notes, history, and elapsed time.
2. Without a saved game, use the last successfully started puzzle's difficulty,
   mode, source, and custom empty count. Respect generation instead of silently
   switching source or difficulty. Generation failure leaves a useful retry/chooser.
3. Without saved preferences, start **Medium / Challenge / Collection**.
4. New Puzzle is prefilled from remembered choices. Commit choices only when a
   replacement puzzle is successfully ready. Cancelling or failing a request must
   not replace the current board or overwrite those choices.
5. Existing users' remembered Easy/Hard/etc. choices must not be migrated to Medium.
6. Custom always uses generation, regardless of the source selector.

| Preference | Fresh-install default |
|---|---|
| Difficulty / mode / source | Medium / Challenge / Collection |
| Strike limit | 3; alternatives 5, 10, unlimited (`0`) |
| Custom empty cells | 45; range 20–60 inclusive |
| Theme / appearance | Ink / System |
| Scheduled appearance | Light 07:00; Dark 19:00; local clock, no location |
| Notes mode / Fill Notes / automatic cleanup | Off / disabled / disabled |
| Related-cell / matching-digit highlighting | On / On |
| Timer | Hidden; elapsed time still recorded |
| Haptics | On where supported; no substitute audio |

Preferences are local: iOS UserDefaults, Android SharedPreferences, web
localStorage. Missing or invalid settings use validated defaults. Do not erase a
valid existing game just because settings need repair.

## 3. Puzzle and collection contract

- Conventional 9×9 Sudoku: each row, column, and 3×3 box contains 1–9 once.
- Starting clues are immutable. Every distributed/generated puzzle has exactly
  one independently verified solution. Ambiguous or inconclusive results fail.
- Bundle **8,000 puzzles**, 2,000 in each of Easy, Medium, Hard, Expert.
- Source of truth: `Sources/GridZeroCore/Resources/puzzles.txt`. Swift packages
  it, Android includes that same directory as assets, and Astro imports it at
  build time. Do not maintain three hand-copied collections.
- Record format: `difficulty id 81-digit-board rating`, one ASCII record per line.
  Zero means empty; IDs and ratings are preserved from upstream.
- `collection.json` records schema/collection version, pinned upstream revision,
  license, counts, byte length, and SHA-256. Update it with the importer, not by hand.
- Same ID means the same original board across platforms/releases. Original
  400 puzzle IDs remain valid in the expanded bank. Saved games embed their full
  puzzle, so collection updates cannot change an in-progress solution.
- Prefer puzzles not in the local recent-ID history; retain up to 500 IDs. When
  that difficulty's unseen pool is empty, choose from the full difficulty pool.
  This is recent-repeat avoidance, not a lifetime "never repeat" guarantee.

### Difficulty

| Collection level | Upstream bucket | Published rating |
|---|---|---|
| Easy | Easy | < 1.5 |
| Medium | Medium | 1.5–<2.5 |
| Hard | Hard | 2.5–<5.0 |
| Expert | Diabolical | ≥5.0 |

Generated puzzles use the same deliberately small logical grader on each
platform: Easy = naked singles; Medium = hidden singles required; Hard = locked
candidates or naked pairs required; Expert = beyond these techniques, possibly
search. Do not claim generated and published ratings are identical. Custom is
an exact empty-cell request, not a difficulty rating.

### Generation

Build a randomized solved grid and remove clues only while uniqueness is
preserved. Standard targets: Easy 42 empty, Medium 49, Hard 54, Expert 57. Custom
must hit its exact requested count. Check non-custom logical grade before success.
Limit to 100 attempts / approximately 15 seconds plus the current bounded solver
pass. Solver budget: 100,000 nodes; never call an exhausted search "unique".
Run off the UI thread, allow cancellation, and ignore stale results. Failure must
suggest retry, fewer empty cells, or the collection—never silently lower settings.

## 4. Game rules

### Challenge

Check each non-note entry against the puzzle solution immediately. Wrong digits
are rejected and add one strike, even without a duplicate in the current board.
Notes are never solution-checked. Unlimited Challenge still counts strikes but
never locks at a strike limit. Strike limits belong to the game; Settings changes
apply only to future games. Undo/redo never remove strikes.

At the limit, preserve the board and stop entry/erase/notes/history actions. Offer
Retry This Puzzle, Continue in Classic, and New Puzzle. Retry resets the same
puzzle's board, notes, history, time, and strikes. Continue changes only the mode,
preserving progress and strikes. Restart requires confirmation during play.

### Classic

Accept editable-cell hypotheses without automatic correctness feedback, rejected
entries, or strikes. Check Board is an explicit menu action: compare nonempty
entries with the solution, mark wrong cells, and report either Looking good or
A second look. A full **valid** board completes automatically in either mode;
an invalid full Classic board must not complete.

### Notes and history

Manual 3×3 pencil notes are the default. Toggle a digit's bit only in an empty
editable cell. Placing a digit clears that cell's notes; optional cleanup removes
that digit from its peers. Fill Notes uses only current board candidates, never
the hidden answer. All entry/erase/note/cleanup/fill changes are whole-board
undoable, up to 300 history states. A new change clears redo. Completion locks
gameplay/history actions; replay is through confirmed Restart or New Puzzle.

## 5. Interface and accessibility

- Quiet system typography; Ink, Moss, Clay with the existing shared palettes.
- Portrait phone board edge-to-edge when height permits; shrink on short windows.
  Tablet portrait centered, board capped at 720 points/CSS pixels, keypad at 480.
  Landscape places keypad beside board. Normal gameplay must not require scrolling.
- Keypad: `1 3 5 7 9` above centered `2 4 6 8`, staggered between top-row buttons.
- Primary tools: Undo, Erase, Notes. Menu: New Puzzle, Settings, Classic-only Check
  Board, opt-in Fill Notes, Redo, Restart. Show difficulty and mode; optional timer.
- Challenge strike indicators use Xs for small limits, a count for 10/unlimited.
- Accepted digits travel from keypad to cell. Rejections turn red and recoil;
  Reduce Motion / disabled animations use immediate feedback, not travel/shaking.
- Completion: Beautifully solved, another puzzle, or dismiss and enjoy the result.
- Cells expose row, column, value/clue or notes, selection, and explicit errors to
  assistive technology. Browser dialogs manage focus; controls work with keyboard.
  Web shortcuts: arrows, 1–9, N, Backspace/Delete, Cmd/Ctrl+Z, Shift for redo.

## 6. Persistence and privacy

Validate dimensions, values, masks, fixed clues, solution consistency, mode,
strikes, limits, finite nonnegative time, history size, and completion flag before
restoring/indexing a save. Native game files are atomically replaced; web uses one
versioned localStorage save envelope. Persist moves immediately and pause/time
periodically; elapsed time excludes backgrounded or modal UI time.

Corrupt saves or storage failures must produce a visible, useful message, not a
crash or a false "saved" claim. Web site-data clearing, eviction, private mode,
browser/installed-PWA storage separation, and uninstall can lose local progress.
No cross-platform save interoperability or backup service is currently provided.
Android currently requests no Internet permission. Privacy pages and store
disclosures must distinguish local gameplay from hosting/store-provider data.

## 7. Web / PWA contract

Astro builds static pages; only `/play/` requires first-party JS. Ship a manifest
with stable ID/start URL `/play/`, standalone display, 192/512 PNG icons, SVG icon,
and an Apple touch icon. Explain Safari Share → Add to Home Screen and Android
Install app / Add to Home screen on the website; no misleading store badges.

The production service worker caches the game, collection bundle, styles, icons,
and generation worker on HTTPS/localhost. A failed new installation leaves the
old working worker intact; a waiting update activates after old clients close.
Never clear saves during cache updates. Physical-device install/offline/update
checks are release gates even when automated Chromium checks pass.

## 8. Credits, parity, and change management

Credit Grant McLean / Sudoku Exchange, QQWing, and Sukaku Explainer in native
Settings, website `/credits/`, and documentation. Keep the upstream public-domain
license in shipped resources. Credit dataset tools without suggesting their code
is embedded in GridZero. See [provenance](puzzle-data.md).

Every rule/default change requires a regression test or a recorded manual check
on all platforms. Validate collection count/checksum/uniqueness from one source.
Run Swift tests/build, Kotlin tests/lint/build, web tests/build/link check/browser
tests, then physical-device checks. When a platform cannot be verified, say so;
do not mark the corresponding go-live checkbox complete.

## 9. Future static puzzle packs — design only, NOT implemented

Bundling 8,000 is the current release choice: no accounts, API server, keys, or
network permission required. More bundles are permitted; bundle size is not a
reason to reduce puzzle choice. If expansion needs independent updates:

- Host immutable HTTPS files under `/data/v1/packs/<content-hash>.txt` and a small
  `/data/v1/manifest.json`. This is static hosting, not a paid compute API.
- Manifest: schema/version, pack ID, difficulty, record count, byte size, SHA-256,
  source URL, pinned revision, license, original IDs, minimum compatible schema.
- Explicit Download more puzzles action on **all three** platforms; no automatic
  launch fetch, background tracking, account, or required network access.
- Keep the base bundle. Download into a temporary file/cache, enforce byte/count
  limits, validate IDs/clues/ratings/checksum and bounded uniqueness off-thread,
  and install only if every check succeeds. Network failure must retain everything.
- Dedupe by stable ID and board; never mutate saved games. Allow deletion of packs
  without deleting in-progress games. Keep license/provenance per pack.
- Before enabling native downloads, add Android Internet permission, update
  privacy/store disclosures, and implement identical UX and tests on all platforms.
- SHA-256 detects corruption, not authenticity by itself; use trusted HTTPS,
  same-origin hosting, and consider a pinned signing key for third-party packs.
