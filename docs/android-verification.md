# Android verification

Native Kotlin implementation checked on the connected physical phones, using Terminal / ADB only.

> Historical report for the original 400-puzzle build. The October 12, 2026
> expansion to 8,000 and Medium/remembered-startup changes require a new Kotlin
> test/build and device pass. This Mac currently lacks Java setup; this report
> must not be treated as verification of the expanded release.

| Device | OS reported by device | API | Native display | Density | Result |
|---|---|---:|---:|---:|---|
| OnePlus 6 / ONEPLUS A6003 | Murena /e/OS 3.7.3, Android 15 | 35 | 1080 × 2280 | 450 dpi | Passed |
| Pixel 10 | GrapheneOS, Android 17, build 2026081301 | 37 | 1080 × 2424 | 420 dpi | Passed |

The app targets API 36 and supports API 26+. The same APK installed and launched on both phones. No Google Play Services, microG, attestation, account, native-library payload, or GrapheneOS compatibility-mode change was required.

## Checks completed

- **8 JVM tests passed:** solver uniqueness/ambiguity/invalid boards, strikes, Classic completion, notes/undo/redo, autofill, all 400 shared collection puzzles, generated difficulty/custom counts, and adaptive 48dp keypad geometry.
- **3 instrumentation tests passed on each phone:** safe-area portrait layout and staggered keys, actual note entry and undo, rejected/correct entry, atomic saved-game restoration, no network permission, appearance scheduling, Classic hypotheses, and landscape rotation.
- Debug and optimized Release builds succeeded.
- Android lint completed with zero errors. Remaining warnings concern English-only text, pinned tool/test-library versions, and programmatic view/layout allocation advice.
- Release signature verified using APK Signature Scheme v2.
- APK audit verified byte-identical shared puzzle data, included license texts, no network permission, and no native ABI libraries.
- Runtime dependency report contained only the Kotlin standard library and JetBrains annotations; AndroidX test libraries are not included in the application.
- Optimized APK: **89,992 bytes / 87.9 KiB**, including puzzle data and licenses.

## Installation

The optimized APK was installed on both phones and opened successfully. The temporary instrumentation package was removed afterward. Local development and optimized builds use the same local development signing key, allowing replacement without clearing app data.

Build / installation commands and signing notes are in [android/README.md](../android/README.md). Device screenshots were captured under the ignored `build/` directory; they are not bundled into the app.
