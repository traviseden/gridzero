# GridZero web product specification

**Version 3 · November 25, 2026**

## Product and interface

Free Sudoku, without accounts, ads, analytics, tracking, purchases, or gameplay
network requests. Astro builds a static web app with a TypeScript engine and a
generation worker. Native apps are retired and preserved on `walled-garden`.

Ask the owner before adding UI text or making new design choices. Prefer concise
controls and whitespace. No promotional copy, redundant status text, or decorative
badges. Mode explanations live behind the existing info control; other explanations
belong on About/Help.

- `/` is the lobby: GridZero, Settings and About, existing puzzle controls, and Play.
  Settings opens the same preferences dialog without starting a puzzle.
- Lobby and board are two states of the same game shell; URLs preserve history,
  bookmarks, and installed-app identity. See the [gameplay machines](../GAMEPLAY.md).
- Controls: difficulty, custom empty count when applicable, mode with info button,
  and source. Defaults: Medium / Challenge / Collection / 45 custom empty cells.
- Visiting the lobby does not start or replace a puzzle. Play installs a puzzle
  only after selection/generation succeeds, then navigates to `/play/`.
- Remember only successfully started choices. Generation failure/cancellation
  preserves the previous saved game and choices.
- `/play/` restores a valid saved game unchanged. Without one it opens the lobby.
- On game start, choose the digit with the fewest filled cells, randomly among
  ties, and enter number focus rather than selecting an input cell. Restoring or
  restarting a board also initializes number focus from its current counts.
- Tapping a filled cell focuses its digit: all matching cells receive the same
  background, without per-match borders, a uniquely selected cell, or peer shading. Tapping
  an empty cell switches to cell focus. Accepted entries switch to number focus.
  Respect the existing matching-highlight preference.
- Completion offers **New game** (lobby) and **Admire puzzle** (dismiss and retain
  completed board). No completion heading, summary, or persistent footer.
- The game menu's New game returns to the lobby. Browser back/forward switches
  between lobby and board without replacing the saved puzzle.
- `/about/` contains existing relevant web-app information and links to Help,
  Credits, and Privacy. Informational pages are script-free.
- The GridZero wordmark links to the lobby only on About; elsewhere it is plain text.

## Gameplay

- Conventional 9×9 Sudoku; rows, columns, and boxes contain 1–9 once.
- Starting clues are immutable. Every puzzle must have exactly one solution.
- Number entry on any filled cell is a no-op in either mode: no replacement,
  strike, or history change. Erase an editable filled cell before changing it.
  Erase targets the editable cell explicitly tapped/entered, not every match.
- Challenge rejects wrong entries and adds strikes; default limit 3, configurable
  1–5 for future games. Saved games retain their original limits, including legacy
  unlimited/10. Undo never removes strikes; notes are not solution-checked.
- At the strike limit, lock entry/history and offer New Puzzle as the primary,
  keyboard-focused default, followed by Retry This Puzzle and Continue in Classic.
  Retry resets the same puzzle. Continue preserves
  progress and strikes. Restart requires confirmation.
- Classic accepts hypotheses without correctness feedback. Check Board explicitly
  marks wrong filled cells. Only a full valid board completes.
- Manual notes toggle candidates in empty editable cells. Placement clears that
  cell's notes. Optional cleanup removes that digit from peers.
- Fill Notes is opt-in and uses current-board candidates, never the solution.
- Whole-board undo/redo covers entries, erasures, and notes, up to 300 states.
  New edits clear redo. Completion locks gameplay/history.
- Entries travel from keypad to cell in 350ms; rejections turn red at arrival and
  recoil for 450ms. Explicit idle/travelling/recoiling states serialize input.
  During travel/recoil, ignore additional gameplay input rather than cancelling
  the flight or applying duplicate strikes. Persist the move immediately, present
  cell/strike feedback on arrival, and show completion/strike-out only after settling.
  Menu/navigation/resize interruptions settle the committed move and remove the
  flight. Scrolling carries the flight with the document. Reduce Motion and manual
  notes use immediate feedback.

## Layout, preferences, and accessibility

- On portrait phones, the square board fills the page width. Tools and keypad follow
  below; the keypad remains capped at 480 CSS pixels.
- Above 600px in portrait, grow the board fluidly with the viewport and available
  height. Allow modest side margins, keep the keypad below, and share one header
  row between the wordmark, status, and menu. There is no fixed board maximum.
- In landscape, fit the board between a wordmark-width non-number column on the
  left and a slightly wider keypad on the right, shifting the board slightly left
  of exact center. Maximize its square size with no top/bottom inset; apply
  safe-area spacing only to controls. In nearly square windows, use the
  maximum width between usable side controls. Allow scrolling for short viewports,
  enlarged text, or status messages rather than clipping controls.
- Square or landscape windows at least 800px wide and 600px tall use the side-control
  arrangement. Center the whole game, cap the board at 540px,
  keep controls close beside it, and leave at least 24px around the game.
  Shrink the board as needed to fit; phone-sized windows retain their sizing.
- Keypad: portrait has 1 3 5 7 9 above centered, staggered 2 4 6 8;
  landscape transposes this into two adjacent staggered columns on the far right,
  odd digits followed by even digits, respecting safe areas.
  No empty status-row budget.
- Portrait tools below the keypad: Undo, Erase, Notes; game menu in the header.
  Landscape has a matching 2×2 control block at bottom left: Settings (game menu)
  top left, Notes top right, Undo bottom left, Erase bottom right.
  Menu: New game, Settings, Classic-only Check
  Board, opt-in Fill Notes, Redo, Restart.
- The landscape tool block uses outlined buttons with the matte table showing
  through and contrasting icons. Active Notes remains distinct. Cell selection/matching
  uses filled highlights; keyboard focus retains a visible outline.
- The game-menu control uses a gear, circular in portrait and matching the other
  square tool buttons in landscape. All four controls use larger, label-free
  icons with accessible names.
- Show difficulty, mode, Challenge strikes, and optional timer. Small limits use Xs.
- Set the board and tactile number keys on a matte surround. Use locally bundled
  B612 digits on the board, notes, keys, and flying entries; system text elsewhere.
- Challenge guesses play an original rising tone on acceptance or a descending bloop
  on rejection. Sound effects default on and can be muted independently of haptics.
  Deliver the cue once at arrival or immediate settlement. The final move in either
  mode plays the “Last tile” win cue instead. Notes and ordinary Classic entries stay silent.
- Ink/Moss/Clay themes; System appearance by default. Scheduled defaults 07:00/19:00
  using the local clock. Timer hidden, haptics on where supported, peer/matching
  highlights on; notes, Fill Notes, and cleanup off by default.
- Lobby styling uses a narrow column, vertically and horizontally centered when
  content fits, with scrolling for shorter screens. Labels are 16px, the mode info
  glyph is enlarged, and controls remain full-width and 56px high. Use consistent
  spacing and the existing theme palette. No added content.
- Landscape lobby uses two columns beneath the existing header: difficulty/custom
  and Puzzle source on the left, Mode and Play on the right.
- Entering either app page, including reload and browser back/forward, starts at
  the top. Normal scrolling remains available for content exceeding the viewport.
- Game menu/settings use the same restrained surface controls, spacing, and
  typography, without decorative menu glyphs, blurred backdrops, or added copy.
  Dialog Done controls have symmetrical padding and at least 44px height.
- Cells expose row, column, value/clue, notes, selection, and explicit errors.
  Dialogs manage focus. Keyboard: arrows, 1–9, N, Backspace/Delete,
  Cmd/Ctrl+Z, Shift for redo.

## Collection and generation

`site/src/data/puzzles.txt` is the canonical 8,000-puzzle resource: 2,000 each of
Easy, Medium, Hard, Expert. Format: `difficulty id 81-digit-board rating`.
`collection.json` records version, upstream revision, counts, bytes, and SHA-256.
Importer: `tools/import_puzzles.py`. Preserve IDs, published ratings, and licenses.
Prefer IDs outside the last 500 played; reuse the pool when exhausted.

Published rating buckets: Easy <1.5, Medium 1.5–<2.5, Hard 2.5–<5, Expert ≥5
(upstream Diabolical). Generated grading: naked singles, hidden singles, locked
candidates/naked pairs, then beyond these techniques respectively.

Generation removes clues only while uniqueness is proven. Standard targets: 42,
49, 54, 57 empty cells. Custom range 20–60 must hit its exact count. Limit to 100
attempts/about 15 seconds plus the current bounded solver pass; solver budget
100,000 nodes. Exhaustion never proves uniqueness. Run off the UI thread, allow
cancellation, ignore stale results, and fail explicitly rather than lowering difficulty.

## Persistence and offline operation

Preferences and a versioned game envelope use localStorage. Validate save dimensions,
values, notes, fixed clues, solution consistency, mode, strikes, limits, elapsed time,
history, and completion before restoring. Persist moves immediately and time
periodically; time excludes background, lobby, and dialogs. Errors must be visible.
No accounts, sync, backup, or guaranteed retention. Clearing/eviction/private mode,
browser/PWA storage separation, and uninstall can lose saves or cached assets.

Manifest keeps stable ID `/play/`, launches `/`, and scopes to `/`, standalone.
Ship SVG, 192/512 PNG, and Apple touch icons. Explain installation only on About/Help.
Production service worker caches lobby, game, informational pages, styles, engine,
collection, and generation worker on HTTPS/localhost. Explicitly check for updates
at startup and when returning to the foreground. Install the entire new cache
before activation; failed installs remove only their partial cache.

On an untouched startup with no other open app windows, activate a fully installed
update and reload once, saving the current game first. Once the user interacts,
defer automatic reload until a later startup. Other open windows block forced
activation; the normal worker lifecycle remains the fallback. Returning to the
foreground checks/downloads updates but does not reset an already-interactive session.

Keep older hashed assets usable until a page from the current build is the sole
window. Then remove older caches, never newer pending caches or localStorage.
No update dialog, toolbar, reinstall requirement, or site-data clearing.

## Verification and credits

Run core tests, Astro check/build, link validation, and Chromium/WebKit tests.
Physical installation/offline/update checks remain release gates; automation is
not proof of physical-device verification.

Credit Grant McLean / Sudoku Exchange, QQWing, and Sukaku Explainer on Credits,
linked from About and Settings. Dataset tools are not embedded engines. Retain
the public-domain puzzle license; code/artwork use MIT. See `puzzle-data.md`.
