#!/usr/bin/env bash
# macOS prerequisite bootstrap. Re-runnable; does not overwrite signing material.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACCEPT=no
case "${1:-}" in
  "") ;;
  --accept-licenses) ACCEPT=yes ;;
  *) echo "Usage: bash tools/setup_android.sh [--accept-licenses]" >&2; exit 2 ;;
esac
if [[ "$(uname -s)" != Darwin ]]; then
  echo "This bootstrap is for macOS. See android/README.md for other systems." >&2
  exit 1
fi
if ! command -v brew >/dev/null 2>&1; then
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$candidate" ]]; then export PATH="$(dirname "$candidate"):$PATH"; break; fi
  done
fi
if ! command -v brew >/dev/null 2>&1; then
  echo "Install Homebrew from https://brew.sh, then run this script again." >&2
  exit 1
fi
command -v python3 >/dev/null 2>&1 || { echo "Python 3 is required (available with Xcode command-line tools)." >&2; exit 1; }
if ! brew list --versions openjdk@17 >/dev/null 2>&1; then
  brew install openjdk@17
fi
export JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$ROOT/android/.sdk"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
"$JAVA_HOME/bin/java" -version
if [[ "$ACCEPT" == yes ]]; then
  python3 "$ROOT/tools/setup_android.py" --accept-licenses
else
  python3 "$ROOT/tools/setup_android.py"
fi
# These exports are for our build helper, not a global shell/system Java change.
ENV_FILE="$ROOT/android/env.local.sh"
TEMP_ENV="$(mktemp "$ROOT/android/env.local.sh.XXXXXX")"
trap 'rm -f "$TEMP_ENV"' EXIT
{
  echo '# Generated local Android environment; contains paths, no signing secrets.'
  printf 'export JAVA_HOME=%q\n' "$JAVA_HOME"
  printf 'export ANDROID_HOME=%q\n' "$ANDROID_HOME"
  printf 'export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"\n'
} > "$TEMP_ENV"
chmod 600 "$TEMP_ENV"
mv "$TEMP_ENV" "$ENV_FILE"
mkdir -p "$ROOT/android/signing"
chmod 700 "$ROOT/android/signing"
echo
echo "Android prerequisites ready. No signing files were changed."
echo "Next: copy your OLD keystore into android/signing/ and fill android/Signing.local.properties."
echo "Build: bash tools/android.sh build"
echo "Devices: bash tools/android.sh devices"
echo "Install: bash tools/android.sh install PHONE_SERIAL"
