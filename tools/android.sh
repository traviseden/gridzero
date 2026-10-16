#!/usr/bin/env bash
# Build/test Android and safely update an explicitly selected attached phone.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND="${1:-}"
case "$COMMAND" in
  build|test|devices|install) ;;
  *) echo "Usage: bash tools/android.sh {build|test|devices|install PHONE_SERIAL}" >&2; exit 2 ;;
esac
if [[ ! -f "$ROOT/android/env.local.sh" ]]; then
  echo "Run bash tools/setup_android.sh first." >&2; exit 1
fi
source "$ROOT/android/env.local.sh"
[[ -x "$JAVA_HOME/bin/java" && -x "$ANDROID_HOME/platform-tools/adb" ]] || {
  echo "Local prerequisites are missing; rerun bash tools/setup_android.sh." >&2; exit 1;
}
SIGNING="$ROOT/android/Signing.local.properties"
APK="$ROOT/android/app/build/outputs/apk/release/app-release.apk"
GRADLE=(bash "$ROOT/android/gradlew" -p "$ROOT/android" --console=plain)
case "$COMMAND" in
  devices)
    "$ANDROID_HOME/platform-tools/adb" devices -l
    ;;
  test)
    "${GRADLE[@]}" :app:testDebugUnitTest :app:lintDebug
    ;;
  build)
    [[ -f "$SIGNING" ]] || { echo "Create android/Signing.local.properties from the example before a signed build." >&2; exit 1; }
    chmod 600 "$SIGNING"
    # Clean avoids mistaking an old signed APK for the current output.
    "${GRADLE[@]}" :app:clean :app:testDebugUnitTest :app:lintDebug :app:assembleRelease :app:bundleRelease
    [[ -f "$APK" ]] || { echo "Expected signed APK missing; do not install an unsigned artifact." >&2; exit 1; }
    "$ANDROID_HOME/build-tools/35.0.0/apksigner" verify --verbose --print-certs "$APK"
    echo "Signed APK: $APK"
    echo "AAB: $ROOT/android/app/build/outputs/bundle/release/app-release.aab"
    echo "Store publication still requires a permanent release/upload key, not the legacy debug key."
    ;;
  install)
    SERIAL="${2:-}"
    [[ -n "$SERIAL" && "$SERIAL" != -* ]] || { echo "Supply the exact phone serial shown by the devices command." >&2; exit 2; }
    [[ -f "$SIGNING" && -f "$APK" ]] || { echo "Configure signing and run bash tools/android.sh build first." >&2; exit 1; }
    "$ANDROID_HOME/build-tools/35.0.0/apksigner" verify --print-certs "$APK"
    "$ANDROID_HOME/platform-tools/adb" -s "$SERIAL" get-state
    if ! "$ANDROID_HOME/platform-tools/adb" -s "$SERIAL" install -r "$APK"; then
      echo "Install failed. This helper NEVER uninstalls the existing app or clears its data." >&2
      echo "If signatures differ, obtain the original signing key; do not uninstall just to bypass the error." >&2
      exit 1
    fi
    "$ANDROID_HOME/platform-tools/adb" -s "$SERIAL" shell am start -n win.gridzero.android/.MainActivity
    ;;
esac
