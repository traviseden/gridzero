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

## Startup updater follow-up (deployed)

- Added explicit uncached worker checks on startup and foreground return.
- An untouched startup can activate a fully cached update and reload once after
  saving. Interaction blocks reload; another open window blocks forced activation.
- Old bundles remain cached for old pages. Cleanup requires a sole current-build
  page and deletes only older caches, never an installing/waiting newer cache.
- Partial failed installations are removed; current caches and localStorage stay.
- Initial migration from the previously deployed updater uses its normal worker
  lifecycle: visit online, close all GridZero windows/tabs, then reopen. Reinstalling
  or clearing site data should not be necessary for application code updates.
- A suspended already-interactive PWA checks on foreground return but defers reload
  to a fresh startup. This avoids interrupting gameplay or pending lobby choices.
- New Chromium tests serve two real worker releases on isolated local servers:
  successful activation/save preservation/offline use, failed installation, and
  multiple-window deferral. Physical iPhone update testing remains required.
- Astro check/build passed; full browser suite: 36 passed, four service-worker
  tests skipped on WebKit. Included a regression check that old-client cleanup
  cannot delete a newer waiting cache.
- Deployed at the owner's request without committing:
  https://dba4a769.gridzero.pages.dev / https://gridzero.win/.
  Verified live lobby/game HTML, worker, and referenced CSS/JS against the local
  build after initial edge propagation. Source changes intentionally remain uncommitted.

## Number focus and in-game options

- New/restored/restarted games choose the least-filled digit, randomly among ties.
  Initial focus is a number, not a cell. Filled-cell taps highlight every match
  with the same border/background; empty-cell taps select an input cell.
- Accepted entries switch to number focus. Entry on filled cells is ignored by
  both UI and core engine, including Classic: no strike, overwrite, or history.
  Explicit Erase still acts on the editable cell tapped/entered.
- Simplified game-menu action rows and restyled Settings with the lobby's
  spacing, full-width selectors, and restrained surfaces. Dialog titles receive
  initial focus without a decorative focus outline; controls retain keyboard outlines.
- Verified 13 core tests, 40 browser tests (four WebKit service-worker skips),
  Astro check/build, link checks, plus 14 targeted dialog/focus checks after polish.
- Production WebKit verified least-filled focus, filled-cell no-op, menu/settings,
  and no JavaScript errors. Reviewed phone screenshots.
- Latest deployment: https://df1c1a1b.gridzero.pages.dev / https://gridzero.win/.
  Owner subsequently approved committing and pushing the deployed updater,
  number-focus behavior, and menu/settings refinement.
- Next: owner reviews number focus and menu/settings on physical phones.

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

## November 18, 2026 — paper-puzzle design exploration

- Owner chose a beautifully typeset paper-puzzle direction rather than native-app
  styling. Priorities: largest practical board, viewport fit, and good phone,
  iPad, and desktop layouts. Exploring odd digits left / even digits right.
- No UI implementation yet. Clarify whether the requested side keypads and
  reported phone breakage refer to portrait or landscape, and agree on the new
  viewport-fit rule before replacing SPEC.md's unconditional full-width rule.
- Inspected production with isolated Playwright browsers: WebKit at 390×664,
  844×390, and 1024×768; Chromium at 1440×900. The board remains viewport-width
  square. Document heights were respectively 664, 1168, 1348, and 1816 pixels.
  Phone portrait fit at the tested size; landscape overflow was reproduced.
  Physical-device/browser chrome and the owner's exact portrait failure are
  not yet verified.
- Confirmed Settings opens through the game's top-right menu, and Ink/Moss/Clay
  choices are present. Lobby has no Settings entry. These themes currently change
  accent color, not the paper/background palette.
- Screenshots saved outside the repository in the session temporary directory,
  `gridzero-layout-review/`. Existing localhost:4321 belongs to another project;
  no GridZero dev server was started.
- Next: confirm orientation/layout intent and approval for lobby Settings access;
  then prototype the agreed responsive composition and typography for owner review.

### Landscape prototype and lobby Settings

- Owner confirmed the failure was landscape, portrait layout is good, and approved
  Settings beside About in the lobby.
- Added the lobby Settings button using the existing dialog. Preferences work
  without creating a game; pending puzzle choices survive opening/closing it.
  Closing restores focus explicitly for Safari. Changing the default source
  updates the lobby source, and preference-save errors use the existing lobby
  error area. Settings is disabled during generation.
- Landscape at widths of at least 560px uses CSS Grid: one compact header row,
  a viewport-fitted square board, odd digits left, even digits right, and tools
  below the even digits. The same buttons and entry animation remain in use.
  Safe-area insets and dynamic viewport height participate in sizing. Very short
  windows can scroll to preserve touch targets. Portrait retains its width-filling
  board and two keypad rows. Updated SPEC.md to replace the old unconditional
  width rule.
- Screenshot review: phone portrait 390×664; landscape 844×390 and 568×320;
  iPad-sized 1024×768; desktop 1440×900. Landscape boards measure 322, 252,
  700, and 832 pixels respectively, and each normal gameplay page fits its viewport.
  Reviewed Ink/light, Moss/light, Clay/light, and Clay/dark across these views,
  plus lobby and lobby Settings. Images are in the same temporary
  `gridzero-layout-review/` folder with `-after.png` filenames.
- Verification: all 13 core tests, Astro check/build, link validation, and diff
  whitespace checks passed. Full browser run: 42 passed, four existing WebKit
  service-worker skips, and two failures in the new Settings test. Fixed Safari
  focus restoration and the test's source selector; all eight focused Settings,
  responsive-layout, and rotation/entry checks then passed in Chromium/WebKit.
  Layout assertions cover 15 viewport sizes, touch targets, side placement,
  overlap, and scrolling. Build retains the existing large-chunk warning.
- Changes are local, not deployed. Test preview servers were stopped after use;
  the owner's other project's development server was untouched.
- Next owner checkpoint: review the landscape composition and physical-device
  rotation/browser chrome, then choose a specific paper-puzzle typography treatment.
  Typeface, grid-line, and icon redesigns are still proposals awaiting visual
  decisions; no font or asset dependencies were added.

### Landscape edge controls refinement

- Owner liked the composition and requested number buttons nearer the left/right
  edges, with Undo/Erase/Notes up top.
- Landscape digits now align to the outer safe-area padding (8px plus inset).
  Tools sit at the top of the right-hand control area, above the even digits.
  Updated SPEC.md and existing layout assertions for the new positions.
- Astro check/build and all four targeted Chromium/WebKit layout and rotation
  checks passed; diff whitespace check passed. Reviewed WebKit screenshots at
  844×390, 568×320, and 1024×768, saved as `*-landscape-edges.png` in the existing
  temporary review folder. Physical safe-area/browser-chrome checks still await
  owner review. Local changes remain undeployed.
- Next checkpoint: owner reviews this control placement, then paper typography.

### Full-height board with right-hand controls

- Owner reiterated that maximum board size is fundamental and requested moving
  game information and tools beneath GridZero on the right, with the portrait
  number arrangement transposed to the right as well.
- Removed the landscape header-height reservation. Board is now on the left;
  GridZero, difficulty/mode, timer/strikes, menu, and tools occupy the next column.
  The far-right keypad has adjacent odd/even columns with even digits centered
  between odds. All positions use the original controls and CSS only.
- Board fills the safe viewport height wherever width permits. Nearly square
  windows use remaining width after minimum usable controls. Updated SPEC.md
  and layout coverage to explicitly protect full-height board sizing.
- Reviewed screenshots at 844×390, 568×320, 1024×768, 1440×900, and 600×500.
  Board sides are respectively 390, 320, 768, 900, and 366 pixels. Normal gameplay
  fits each viewport. Screenshots: `*-full-height.png` in the temporary review
  folder. Physical device/browser safe-area verification is still pending.
- Astro check/build, Chromium/WebKit rotation/entry checks, and the updated
  15-viewport layout checks passed. Fixed a test selector ambiguity when a
  randomly focused board digit matched a keypad button's data attribute.
  Diff whitespace check passed. Changes remain local and undeployed.
- Next checkpoint: owner judges the full-height/right-panel composition before
  the paper typography pass.

### Corrected centered composition and edge-to-edge board

- Owner rejected the all-right control interpretation: the board must be centered,
  non-number controls on the left, and the transposed number keypad on the right.
  Owner also requested a gear instead of the ellipsis and reported bottom spacing.
- Landscape now uses equal-width side regions around the board. Removed vertical
  safe-area deductions and all outer padding from the board layout; safe-area
  spacing applies to the side controls only. Replaced the circular game-menu
  ellipsis with an inline SVG gear, preserving access to the existing game menu.
- Updated SPEC.md and existing layout tests to protect horizontal centering,
  top/bottom viewport contact, control placement, and touch targets. Added an
  explicit simulated 21px bottom / 44px side inset check: at 844×390 the centered
  board remains 390px square, from y=0 to y=390.
- Astro check/build passed. All six targeted settings, layout, and rotation checks
  passed across Chromium/WebKit after correcting a padded-container test assertion.
  Reviewed phone (844×390 and 568×320), simulated-inset phone, and iPad (1024×768)
  screenshots; captured desktop 1440×900 as well. Images use `*-centered.png` and
  `phone-centered-insets.png` in the temporary review folder.
- Physical device rendering still needs owner review; simulated inset coverage
  is not a physical Safari/PWA check. Changes remain local and undeployed.
- Next checkpoint: review this corrected composition before typography work.

### Bottom-left tool square and small board inset

- Owner requested matching controls in a bottom-left 2×2 block: Settings / Notes,
  then Undo / Erase. Left column should stay around wordmark width, keypad gets
  slightly more room, and board shifts a little left. Owner explicitly approved
  a tiny top/bottom board margin to explore intermittent first-row focusing.
- Grouped the existing menu button with the three tools. Landscape shows four
  matching square surface buttons with consistent inline SVG icons and a Settings
  label; the same menu button is positioned in the portrait header. Its existing
  game-menu actions remain accessible. The block respects bottom/left safe areas.
- Landscape CSS Grid now uses intrinsic left-column sizing, a flexible middle,
  and a wider right keypad. The board takes the largest square fitting that middle
  area, capped at viewport height minus 8px (4px at each edge). Width-limited
  windows can have larger vertical margins. Updated SPEC.md accordingly.
- Verified all nine first-row cells accept clicks 2px inside their top edges in
  Chromium/WebKit. This did not reproduce the owner's intermittent physical touch
  issue; native browser/OS edge gestures still require phone testing.
- Astro check/build passed. Ten targeted browser checks passed across the work:
  settings, notes/undo/persistence, keyboard/reduced motion, rotation/entry plus
  first-row targeting, and responsive layout. Corrected the compact-width sizing
  and allowed a few pixels of intrinsic Settings-label width in layout assertions.
  The final two 15-viewport layout checks passed, including simulated safe insets.
- Reviewed phone 844×390, small phone 568×320, iPad 1024×768, and portrait 390×664;
  also captured desktop 1440×900. Screenshots are `*-tool-square.png` in the
  temporary review folder. At 844×390, the board is 382px square starting at y=4.
- Changes remain local and undeployed. Next checkpoint: owner judges the tool
  block, slight leftward balance, and whether the small inset helps on the phone.

### Outlined tools, filled highlights, landscape lobby, and scroll reset

- Owner said the inset did not help and requested its removal, a stronger/outlined
  tool treatment, quieter selected/matching cells, and a landscape lobby.
  Owner explicitly chose the two-column lobby: Difficulty/custom and Play left,
  Mode and Puzzle source right, below the existing header.
- Removed the 4px board inset. Landscape tool buttons now use a 1px outline,
  transparent background, and theme-aware ink text/icons; Notes keeps its active
  accent state. Removed inset borders from both selected and matching cells,
  keeping filled highlights and a dark, visible keyboard-focus outline.
- Landscape lobby uses a capped 760px two-column form with compact existing
  spacing. Standard and custom forms fit at 568×320 and larger tested sizes.
  No new lobby copy or controls were introduced.
- Independently reproduced scroll carry-over: both Chromium and WebKit retained
  66px after starting a game from a scrolled lobby; Chromium retained 166px on
  game reload. Set manual history scroll restoration and reset to the top on
  page show and lobby/game entry. Regular scrolling remains available.
  Regression coverage includes reload, Play, New game, and browser back/forward.
- Verification: all 13 core tests, Astro check/build, link/structure checks,
  and all 48 browser tests passed (four existing WebKit service-worker skips).
  Updated layout/matching checks and added meaningful lobby-fit and scroll tests.
  Diff whitespace check passed; existing build chunk-size warning remains.
- Reviewed phone gameplay, two-column lobby, smallest-phone custom lobby,
  desktop lobby, and dark Clay/active Notes screenshots. Captured gameplay and
  lobby at 844×390, 568×320, 1024×768, and 1440×900. Images use `*-outline*.png`
  in the existing temporary review folder.
- Changes remain local and undeployed. Next checkpoint: owner reviews the
  outlined tools, fill-only highlights, landscape lobby, and physical startup
  scrolling before further typography work.

### Larger label-free icons, centered lobby, and dialog spacing

- Owner requested swapping Play and Puzzle source in landscape, larger icons
  without labels, larger lobby labels/info icon, balanced Done spacing, and a
  vertically centered lobby.
- Landscape now pairs Difficulty/custom and Puzzle source on the left, Mode and
  Play on the right. Centered the lobby vertically whenever it fits; short pages
  still grow and scroll. Compact custom-form gaps/range margins and short-screen
  header spacing keep the 568×320 custom form within the viewport.
- Play-page tool SVGs are now 32px (previously 22px) with no visible labels.
  All buttons retain accessible names. Lobby labels are 16px and the info glyph
  is 28px. Done uses 12px horizontal / 8px vertical padding and a 44px minimum
  height, consistently across dialogs.
- Found that mode info directly called showModal(), which initially focused Done
  and drew its prominent focus box. It now uses the shared dialog opener, focusing
  the heading like other dialogs. Keyboard outlines and focus return remain intact.
- Verification: Astro check/build and link checks passed. All 16 targeted
  Chromium/WebKit checks passed for lobby layout/centering, settings, mode info,
  scroll reset, gameplay tools, rotation, and first-row targeting. After the
  mode-info focus adjustment, all four affected dialog/focus checks passed again.
  Reviewed 844×390 and 568×320 landscape, 390×664 portrait, and dialog screenshots;
  captured 1440×900 desktop lobby too.
- Current screenshots in the temporary review folder:
  `phone-large-icons.png`, `portrait-large-icons.png`,
  `phone-centered-lobby.png`, `small-centered-lobby-custom.png`,
  `portrait-centered-lobby.png`, and `phone-centered-lobby-info.png`.
- Changes remain local and undeployed. Next checkpoint: owner judges icon size,
  centered lobby, and revised dialog spacing before further visual changes.

### Approved release and loss default

- Owner approved the visual changes and requested commit, push, and deployment.
- New Puzzle is now first and keyboard-focused after reaching the strike limit,
  including when restoring a lost game. Enter opens the lobby; the lost save is
  preserved until Play starts another puzzle.
- Release checks passed: Astro check/build, all 13 core tests, all 50 browser
  tests (four existing WebKit service-worker skips), local-link checks, and diff
  whitespace checks.
- Deployment verification is recorded in `docs/GO-LIVE.md`. The owner-supplied
  `astro-plain-css-ui-polish-guide.md` remains an untracked local reference.

### Desktop sizing correction

- Owner reported oversized desktop boards after deployment. Reproduced a 900px
  board at 900×1100 with the keypad below the viewport, and 900px+ boards in
  wide desktop windows. Earlier checks incorrectly required maximum sizing on
  desktops and omitted tall desktop cases.
- Owner explicitly chose a 540px cap and centered side-control layout for windows
  at least 800px wide and 600px tall, regardless of orientation. Reused the
  approved side controls, kept them close to the board, and retained phone sizing.
- Board is 540px at 900×1100 and 1440×900, and 454px at 800×600.
  Expanded responsive checks to tall, square, short, and ultrawide desktops;
  verify the cap, centering, adjacent controls, visibility, and phone dimensions.
- Astro check/build, 13 core tests, 50 browser tests (four existing skips),
  link checks, and whitespace checks passed. Reviewed tall/small desktop images;
  screenshots are `desktop-*-capped.png` in the existing temporary review folder.
- Next checkpoint: owner checks the corrected desktop layout at their actual
  window size. Deployment details follow in `docs/GO-LIVE.md`.
