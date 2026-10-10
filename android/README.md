# GridZero for Android

Native **Kotlin + Android views/canvas**, with the same game rules and visual direction as the Swift app. No Compose runtime, WebView, Google Play Services, analytics, ads, or network permission.

- Android **8.0+** (API 26), targeting **Android 16** (API 36).
- Verified on OnePlus 6 / Murena **Android 15 (API 35)** and Pixel 10 / GrapheneOS **Android 17 (API 37)**.
- Full-width portrait board; no gameplay scrolling; staggered odd/even keypad; landscape/tablet adaptation.
- Challenge / Classic, configurable strikes, X indicators, accepted-digit flights and rejection/recoil feedback.
- Manual notes by default, opt-in autofill/cleanup, undo/redo, local atomic saves.
- Ink / Moss / Clay, system/light/dark/scheduled appearance, optional timer and haptics.
- Same 400 independently validated public-domain collection puzzles, plus optional unique on-device generation and custom empty-square counts.

## Terminal-only setup

Install **JDK 17** (or set `JAVA_HOME` to an existing JDK 17 installation). On Apple Silicon macOS:

```sh
brew install openjdk@17
python3 tools/setup_android.py
```

Run setup from the repository root. It downloads the Android command-line tools into the gitignored `android/.sdk/` directory, installs SDK 36/build tools, verifies the Gradle wrapper JAR checksum, and writes a local SDK path. Android Studio is not needed. SDK license acceptance happens during setup.

On other platforms, install Android SDK 36 and point `ANDROID_HOME` at it, or create `android/local.properties` with `sdk.dir=/your/sdk/path`. The application code itself is platform-independent Kotlin/Android code; the convenience SDK installer currently downloads macOS tools.

## Build

From the repository root:

```sh
./android/gradlew -p android :app:assembleRelease
```

APK:

```text
android/app/build/outputs/apk/release/app-release.apk
```

R8 optimization and resource shrinking keep the sideload build very small. Measure the actual APK after building; debug APKs include a larger unoptimized Kotlin runtime.

**Local release builds use the machine's standard development/debug signing key.** Configure your own private release signing key before publishing a long-term distribution. Do not commit keystores or passwords. Debug and local release builds currently share a signature, so switching between them preserves app data.

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

Unit tests independently check the Kotlin solver against **all 400 shared collection boards**, generation uniqueness and logical grading, game-mode semantics, notes/undo, and responsive 48dp keypad geometry.

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
