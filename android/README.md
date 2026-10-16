# GridZero for Android

Native **Kotlin + Android views/canvas**, with the same game rules and visual direction as the Swift app. No Compose runtime, WebView, Google Play Services, analytics, ads, or network permission.

- Android **8.0+** (API 26), targeting **Android 16** (API 36).
- Verified on OnePlus 6 / Murena **Android 15 (API 35)** and Pixel 10 / GrapheneOS **Android 17 (API 37)**.
- Full-width portrait board; no gameplay scrolling; staggered odd/even keypad; landscape/tablet adaptation.
- Challenge / Classic, configurable strikes, X indicators, accepted-digit flights and rejection/recoil feedback.
- Manual notes by default, opt-in autofill/cleanup, undo/redo, local atomic saves.
- Ink / Moss / Clay, system/light/dark/scheduled appearance, optional timer and haptics.
- Same 8,000 independently validated public-domain collection puzzles (2,000 per difficulty), plus optional unique on-device generation and custom empty-square counts. Fresh installs start on Medium; last choices and saved games are remembered.

## Terminal-only setup

Install **JDK 17** (or set `JAVA_HOME` to an existing JDK 17 installation). On Apple Silicon macOS:

```sh
bash tools/setup_android.sh
```

The script works on Intel and Apple Silicon Macs and can be run from any directory. It installs Homebrew's JDK 17 if needed, downloads Android command-line tools into the gitignored `android/.sdk/`, installs SDK 36 / build tools 35.0.0 / platform-tools (adb), verifies the Gradle wrapper JAR checksum, and writes `android/local.properties` and `android/env.local.sh`. Android Studio is not needed. Review SDK licenses in your terminal; pass `--accept-licenses` only if you explicitly want noninteractive acceptance. Signing files are never overwritten, and no global Java configuration is changed.

On other platforms, install Android SDK 36 and point `ANDROID_HOME` at it, or create `android/local.properties` with `sdk.dir=/your/sdk/path`. The application code itself is platform-independent Kotlin/Android code; the convenience SDK installer currently downloads macOS tools.

## Build

### Bring over the old signing identity

For the builds produced by the original setup in this repository, **Release was signed with the old machine's standard debug key**. To update that existing installation without deleting its game data, copy the old machine's **`~/.android/debug.keystore`** to:

```text
android/signing/previous-debug.keystore
```

Do not substitute the new Mac's debug key: the same filename on a different machine usually means a different certificate. For a previously published/permanently signed app, copy its original `.jks` / `.keystore` to `android/signing/gridzero.keystore` instead and retain its alias/passwords. If the key is lost, we cannot manufacture an in-place update signature. The legacy debug key is for preserving sideload compatibility, **not publishing a store app**.

Copy the provided example to **`android/Signing.local.properties`** and fill it locally. Relative paths are relative to `android/`, not `app/`. For an unchanged standard old debug key, the usual settings are:

```properties
storeFile=signing/previous-debug.keystore
storePassword=android
keyAlias=androiddebugkey
keyPassword=android
```

For a private permanent key, use its real values—not those debug defaults. Java properties need escaped backslashes/special characters; avoid moving the key into a path with spaces. If the old machine already has a `Signing.local.properties` with the correct release credentials, copy it too and adjust `storeFile` to the new path. Never send passwords or key contents in chat. The signing folder and filled properties are gitignored; protect them locally:

```sh
cp android/Signing.local.properties.example android/Signing.local.properties
chmod 600 android/Signing.local.properties android/signing/previous-debug.keystore
```

Edit the copied properties before building. Do not run the `cp` over an already configured local signing file.

### Helper commands

```sh
bash tools/android.sh test
bash tools/android.sh build
bash tools/android.sh devices
bash tools/android.sh install PHONE_SERIAL
```

`build` tests, lints, cleans stale build artifacts, creates the signed APK and AAB, and prints the APK certificate fingerprint. `install` requires an explicit serial, verifies the APK, updates with `adb install -r`, and launches the app. It **never uninstalls or clears data**. Android SDK/Gradle dependencies use the network at setup/build time; gameplay does not.

From the repository root:

```sh
source android/env.local.sh
./android/gradlew -p android :app:assembleRelease
```

APK:

```text
android/app/build/outputs/apk/release/app-release.apk
```

R8 optimization and resource shrinking keep the sideload build very small. Measure the actual APK after building; debug APKs include a larger unoptimized Kotlin runtime.

**Release no longer silently falls back to a debug key.** With `Signing.local.properties`, Release uses that exact key; without it, Gradle can compile an **unsigned** release for CI. The helper refuses to build/install for your phone without the local signing configuration. Use a permanent release/upload key before publishing, and keep it backed up. Debug builds still use this Mac's debug key and may not update an older installation signed on another machine.

## Install and open

Unlock the phone, enable USB debugging, and approve the Mac's debugging key. List devices:

```sh
adb devices -l
```

Use an explicit serial when multiple phones are connected:

```sh
adb -s DEVICE_SERIAL install -r android/app/build/outputs/apk/release/app-release.apk
adb -s DEVICE_SERIAL shell am start -n win.gridzero.android/.MainActivity
```

`-r` replaces the app while retaining its local data. Package ID: `win.gridzero.android`.

## Verification

```sh
./android/gradlew -p android :app:testDebugUnitTest :app:lintDebug
./android/gradlew -p android :app:assembleDebug :app:assembleDebugAndroidTest
adb -s DEVICE_SERIAL install -r android/app/build/outputs/apk/debug/app-debug.apk
adb -s DEVICE_SERIAL install -r android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb -s DEVICE_SERIAL shell am instrument -w -r \
  win.gridzero.android.test/androidx.test.runner.AndroidJUnitRunner
```

Unit tests independently check the Kotlin solver against **all 8,000 shared collection boards**, generation uniqueness and logical grading, game-mode semantics, notes/undo, and responsive 48dp keypad geometry. The older physical-device report covered the original 400; retest the expanded release before shipping.

Three real-device instrumentation tests verify portrait layout/system-bar clearance, notes and undo, incorrect/correct entry, saved-game restoration, appearance scheduling, Classic play, landscape rotation, and absence of network permission. Instrumentation creates test puzzles in the app's local state; run it on a development installation. AndroidX libraries are test-only and are not shipped in the application APK.

See [the physical-device verification report](../docs/android-verification.md) for the checked OS versions, results, and measured APK size.

## Murena and GrapheneOS

The application uses standard Android platform APIs and local app-private files. It does not require sandboxed Google Play, microG, Play Integrity, SafetyNet, accounts, or remote services. It contains no native/JNI payload and did not require changing GrapheneOS exploit-protection compatibility mode during device checks.

System-bar/cutout insets are respected, the screen geometry is recalculated on rotation/window resizing, and Android's disabled-animation setting is honored. Scheduled colors update while foregrounded and when resuming; no alarms, location, wake locks, or background appearance service are used.

Android backup and device-transfer rules exclude the app's local data. Progress and settings stay in app-private storage.

## Source and licenses

```text
app/src/main/java/.../core/     Pure Kotlin solver, generator, game, geometry
app/src/main/java/.../         Native UI, accessibility, settings, storage
app/src/test/                  JVM correctness/geometry tests
app/src/androidTest/           Real-device instrumentation tests
```

The Gradle asset source references the existing `Sources/GridZeroCore/Resources/` collection directly, so both platforms ship identical puzzles without duplicating the bank. App code/artwork are MIT; puzzle data are public domain; packaged Kotlin runtime code is Apache-2.0. License texts and notices are included in the APK and accessible in Settings.

Puzzle credit: Grant McLean / Sudoku Exchange; upstream generation with Stephen Ostermiller's QQWing and ratings with SudokuMonster's Sukaku Explainer. See [provenance](../docs/puzzle-data.md), [shared spec](../docs/SPEC.md), and [publishing checklist](../docs/GO-LIVE.md).
