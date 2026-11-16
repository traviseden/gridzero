# iOS adversarial review follow-up

November 16, 2026. Scope: iOS/iPadOS and the Swift core.

## Implementation plan and changes

1. **Restoration:** distinguish missing files from failed reads/invalid saves.
   Retry loads again; New Puzzle uses the existing chooser. A replacement first
   preserves the original as `game-recovery-<UUID>.json` beside `game-v1.json`.
   Failed preservation prevents replacement of the file.
2. **Validation:** bound numeric fields, reject completed history snapshots,
   enforce the combined history limit, and verify the saved puzzle has exactly
   the embedded solution. Collection selection uses the same bounded uniqueness
   check. Keep legacy 10-strike/unlimited games supported.
   Formatting and strike increments are safe independently of validation.
3. **Preferences:** decode and validate fields independently; missing or invalid
   fields no longer discard valid remembered choices.
4. **Persistence:** perform file reads, validation, encoding, and atomic writes
   in `GameStore`. Chain immutable snapshots so older writes cannot overwrite
   newer moves. Keep errors visible until a subsequent write succeeds; extend
   background execution while a pause save drains.
5. **Timing:** monotonic elapsed time, 15-second checkpoints, fractional pause
   accounting, and one view-level active-gameplay predicate covering alerts,
   sheets, generation, completion, and scene activity.
6. **Feedback:** deliver each rule result's announcement/haptic immediately.
   Animations only defer completion/strike-out presentation.
7. **Accessibility:** scale gameplay labels, wrap errors, and use an owner-approved
   scrolling layout at accessibility text sizes. Standard gameplay remains
   non-scrolling; a long storage error can scroll within its status area.
8. **Regression protection:** add an app-hosted model/storage test target,
   per-test UI sandboxes with a deterministic board, reliable menu-row activation,
   in-flight cancellation coverage, and an iOS Release-build/simulator-test CI job.

## Verification

- Swift core tests cover numeric/history corruption, ambiguous saves, full history,
  actual in-flight generation cancellation, and enlarged standard-text layout.
- Model/storage tests cover recovery, field migration, blocked/failed writes,
  stale/parent-cancelled generation, replacement failure, timer accounting,
  checkpointing, and rapid-entry feedback.
- UI tests cover recovery, persisted notes/history, mode selection, strikes,
  restart-alert timing, accessibility text, rotation, and resized iPad windows.
- CI is configured for Xcode 26.0.1 and iOS 26.0-family phone/tablet simulators;
  this Mac has iOS 27. The new CI job has not been executed on GitHub yet.
- Physical-device VoiceOver/haptics, storage latency, and minimum-OS checks remain
  release checks. Simulator results do not mark those go-live gates complete.

### Local results

| Check | Result |
|---|---|
| `swift test` | 18 passed |
| `GridZeroModelTests` on iPhone 18 Pro / iOS 27 | 14 passed |
| Five gameplay UI tests on iPhone 18 Pro / iOS 27 | Passed, including targeted rerun of Challenge |
| iPhone accessibility text and portrait/landscape layout | Passed; accessibility test passed on targeted rerun |
| All three layout UI tests on iPad Pro 13-inch (M5) / iOS 27 | Passed, including 10 resized windows |
| Release builds for generic iOS device and Simulator, signing disabled | Passed |
| All 8,000 collection records through the bounded Swift uniqueness solver | Passed |
| Privacy/Info plist lint and workflow YAML parsing | Passed |

Initial test runs exposed issues subsequently corrected: an elapsed-time
exclusive-access conflict, cancellation-sensitive test fixtures, and iOS 27
automation activation-point/identifier differences. The accessibility test now
injects the SwiftUI accessibility text-size environment through a DEBUG-only
launch flag, analogous to the existing viewport harness. Rotation and standard
gameplay still use the real window proposal.
