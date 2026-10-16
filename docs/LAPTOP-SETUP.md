# Set up GridZero on a laptop again

Mac recovery/setup guide · October 16, 2026. Run commands from the repository
root unless a command says otherwise. Setup does not publish anything.

## 1. Get the source and common tools

Install full Xcode from the Mac App Store for iOS development. Install Homebrew
from <https://brew.sh> if it is not already installed. Python 3 and Git must be
available; Xcode's command-line tools provide these on the current Mac.

```sh
mkdir -p ~/dev
git clone https://github.com/traviseden/gridzero.git ~/dev/gridzero
cd ~/dev/gridzero
```

If this checkout already exists, do not clone over it or reset it. Check for local
work before updating:

```sh
cd ~/dev/gridzero
git status
git pull --ff-only
```

The checked-in puzzle collection is ready to use; no import/download step is
needed to build. See [SPEC.md](SPEC.md) for the shared product contract and
[GO-LIVE.md](GO-LIVE.md) for store/hosting publication.

## 2. Android: install prerequisites

```sh
bash tools/setup_android.sh
```

This installs JDK 17 through Homebrew, project-local Android command-line tools,
SDK 36, build tools 35.0.0, and platform-tools/adb. Review the SDK license prompts.
Android Studio is not required. The script works on Intel and Apple Silicon Macs.
Rerunning is supported and does not overwrite signing files or change global Java.

Generated local files (gitignored):

| Path | Purpose |
|---|---|
| `android/.sdk/` | Android SDK and adb |
| `android/local.properties` | This laptop's SDK location |
| `android/env.local.sh` | This laptop's JDK/SDK exports for the helper |

Do not copy those machine-specific SDK/environment files from another computer.
The helper sources `env.local.sh` itself. For manual Gradle/adb/keytool commands:

```sh
source android/env.local.sh
```

## 3. Android: copy the OLD signing key

**The original setup in this repository signed local release APKs with the old
machine's standard debug key.** To update that app already installed on your phone
without losing its save, copy the old machine's exact file:

```text
OLD MACHINE: ~/.android/debug.keystore
THIS CHECKOUT: android/signing/previous-debug.keystore
```

Transfer it privately (USB, AirDrop, or authenticated file transfer). Do not upload
it to GitHub or send it in chat. A new laptop's `debug.keystore` is normally a
different key even though its name is identical.

If you previously used a permanent release key instead, transfer that original
`.jks` / `.keystore` to `android/signing/gridzero.keystore` and retain its alias,
store password, and key password. Do not generate a replacement for an already
distributed app. If an old local signing-properties file exists, transfer it
privately too and adjust its `storeFile` path.

Create a local configuration **only if it does not already exist**:

```sh
cp -n android/Signing.local.properties.example android/Signing.local.properties
```

Edit `android/Signing.local.properties` locally. For an unmodified standard OLD
debug key, the usual contents are:

```properties
storeFile=signing/previous-debug.keystore
storePassword=android
keyAlias=androiddebugkey
keyPassword=android
```

For a permanent release key, use its actual credentials and
`storeFile=signing/gridzero.keystore` instead. Paths are relative to `android/`;
do not use `~`. Follow Java-properties escaping rules for special characters.

Protect whichever key you transferred:

```sh
chmod 700 android/signing
chmod 600 android/Signing.local.properties
chmod 600 android/signing/previous-debug.keystore
# If you transferred a permanent key instead, chmod that file rather than the above.
```

The signing folder and filled properties are gitignored. Keep a secure backup
outside this repository. **The old debug key is for sideload compatibility, not
permanent store publishing.** Release builds no longer silently substitute this
laptop's debug key. Without local signing configuration Gradle can compile an
unsigned release for CI; the phone build helper requires local signing.

## 4. Android: build and update your phone

```sh
bash tools/android.sh test
bash tools/android.sh build
```

`build` runs unit tests/lint, cleans stale build artifacts, builds the signed APK
and AAB, and prints the APK's signing-certificate fingerprint. First build needs
Internet access for Gradle/dependencies. Gameplay needs no network or Google services.

- APK: `android/app/build/outputs/apk/release/app-release.apk`
- AAB: `android/app/build/outputs/bundle/release/app-release.aab`

Connect/unlock the phone, enable Developer options → USB debugging, and approve
this Mac's debugging key on the phone. A previously paired, reachable wireless
adb connection also works. List devices, then use the exact phone serial:

```sh
bash tools/android.sh devices
bash tools/android.sh install PHONE_SERIAL
```

The helper uses `adb install -r` and launches GridZero. It **never uninstalls the
old app or clears its data**. A signature mismatch means we need the actual old
signing identity; do not uninstall just to get past the error. An unauthorized adb
device requires approval on the phone. If you are remote with no adb connection,
transfer the signed APK privately and install it manually on the phone.

For Google Play/public APK publication, follow [GO-LIVE.md §4](GO-LIVE.md#4-android--signed-apk-and-optional-google-play).
A keystore alone does not create a Play Console account or complete store review.

## 5. iPhone/iPad: restore Xcode and signing

After installing Xcode:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS
```

Create `Signing.local.xcconfig` from `Signing.local.xcconfig.example` **if missing**
and set your Apple Developer Team ID. The team used on this project is
`T5FF5P8QA4`; verify it is still the right team for your account. This file is local
and gitignored. The permanent bundle ID is `win.gridzero.app`.

```sh
cp -n Signing.local.xcconfig.example Signing.local.xcconfig
```

In Xcode → Settings → Accounts, sign in to the Apple Account with team access;
complete 2FA and Keychain prompts on the Mac. A new laptop may need a new Apple
Development certificate. Existing certificates/private keys are not in Git. Xcode
automatic signing can provision through your account; if a required existing key
must be transferred, export/import its password-protected `.p12` privately through
Keychain/Xcode, never through this repository. Do not revoke the old laptop's keys.

Simulator build (no paid membership/signing needed):

```sh
swift test
xcodebuild -project GridZero.xcodeproj -scheme GridZero \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

**Direct phone install:** connect/unlock iPhone, approve Trust, enable Developer
Mode, then select it in Xcode and Run. The app requires iOS 26+.

**Remote TestFlight install:** no cable or Developer Mode needed. We need active
paid Apple Developer membership, healthy Xcode/App Store Connect access, an app
record for `win.gridzero.app`, valid distribution signing, and a successful archive
upload. Install TestFlight on the phone and add yourself as an internal tester.
Development signing alone does not prove distribution access. See the complete
[iOS upload checklist](GO-LIVE.md#3-ios--ipados--what-is-left-to-publish), including
checking that the installed Xcode/SDK is accepted for store uploads.

## 6. Web/PWA: install dependencies and preview

Install Node 24+ (for example `brew install node@24` and follow Homebrew's PATH
instructions). From the repository root:

```sh
npm --prefix site ci
npm --prefix site test
npm --prefix site run build
python3 tools/check_site.py
```

For a production-output preview with the hosting security headers:

```sh
python3 tools/serve_site.py --port 4321
```

Open `http://127.0.0.1:4321/play/`; Ctrl+C stops that foreground server. Use
`npm --prefix site run dev` for Astro development. Production PWA installation and
offline use require HTTPS (localhost is allowed for testing); an HTTP LAN preview
does not provide offline installation guarantees.

Browser regression tests:

```sh
cd site
npx playwright install chromium webkit
npm run test:ui
cd ..
```

The tests start and stop their own temporary server. Installed-PWA phone checks
are still required before launch. On production HTTPS: iPhone Safari → Share →
Add to Home Screen; Android browser → Install app / Add to home screen.

## 7. What Git does NOT restore

Git restores source, the shared 8,000-puzzle bank, dependency lockfile, example
configuration, scripts, and documentation. It does not restore signing keys,
passwords, account sessions, SDK installations, certificates/private keys, or
phone/browser game saves. Each platform keeps progress locally; there is no sync.

Before committing local work:

```sh
git status --short
git diff --cached --stat
```

Never force-add ignored signing files or SDK/build folders. Public-repository
GitHub Actions use standard free runners; this workflow skips private-repository
jobs. No paid GitHub plan is needed. Publishing fees, hosting configuration, and
release gates are detailed separately in [GO-LIVE.md](GO-LIVE.md).
