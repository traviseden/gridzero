# GridZero go-live checklist

Owner-facing release guide for **iOS/iPadOS, Android, and Web/PWA**. Updated
October 12, 2026. Check boxes are intentionally not marked done just because
source code exists. Never paste passwords, keystore passwords, `.p8` files,
private keys, or recovery codes into chat or commit them.

Read the [shared product spec](SPEC.md) and [puzzle provenance](puzzle-data.md)
before releasing. All releases must use the same collection and product rules.
For a fresh/replacement Mac and old signing-key transfer, start with
[LAPTOP-SETUP.md](LAPTOP-SETUP.md).

## What is ready, and what remains

- Gameplay is implemented on all three platforms; the shared bank now has 8,000
  puzzles. Medium is the fresh-install default; valid saves/last choices are retained.
- Web has a manifest, standalone installation, PNG/touch icons, local saves, and
  production offline caching. Public hosting/physical installed-PWA tests remain.
- iOS simulator builds/tests have worked on this Mac. Team configuration exists,
  and an Apple Development signing identity is now present. **A distribution-signed
  archive, successful upload, App Store Connect app, and phone verification have
  not been established.** A certificate alone does not prove App Store access.
- Android code was tested on physical devices on the other machine (see its
  verification report). This Mac currently has no working `java` command. The
  expanded bundle/default changes need Kotlin and device retesting. Release builds
  now require local signing configuration to produce a signed binary; the original
  setup used a debug key, which may be needed to update existing sideload installs.
- Web preview is stopped. Nothing in this checklist authorizes publishing secrets,
  buying memberships, submitting reviews, or enabling paid hosting automatically.

## 1. Shared release gates

- [ ] Agree on version `1.0.0` or next release; increase native build numbers for
  every uploaded binary. Record commit and collection version/hash.
- [ ] Verify 8,000 records, 2,000 per difficulty, stable original IDs, retained license.
- [ ] Test fresh Medium startup, resume, last-choice New Puzzle defaults, cancellation,
  Challenge/Classic, strikes, notes/cleanup/fill/undo/redo, completion, generation,
  settings, restart, and storage failures on each platform.
- [ ] Test phone/tablet portrait/landscape, small windows, keyboard/accessibility,
  Reduce Motion/disabled animation, light/dark/themes, and background timer pauses.
- [ ] Verify no ads/accounts/tracking, accurate privacy disclosures, and credit links.
- [ ] Publish reachable `/privacy/`, `/support/`, `/credits/`; choose a real support
  contact email for store listings. Do not invent contact information.
- [ ] Prepare honest screenshots, app icon, descriptions, age/content ratings,
  copyright/seller details, support/privacy URLs, and release notes.
- [ ] Document known limitations and unresolved failures, not just passing tests.

Run from the repository root:

```sh
swift test
npm --prefix site ci
npm --prefix site test
npm --prefix site run build
python3 tools/check_site.py
```

```sh
cd site
npx playwright install chromium webkit
npm run test:ui
```

Android commands are below. Automated WebKit checks do not replace actual Safari
home-screen installation/offline checks. No GitHub Actions subscription is required.

## 2. Web / PWA — publish first if desired

### Accounts and configuration

- [ ] Use an existing/free static-hosting account (Cloudflare Pages is the current
  documented target); do not enable paid Workers or paid add-ons for this app.
- [ ] Own/configure `gridzero.win` DNS and HTTPS. Domain registration is a separate
  possible cost; don't confuse a free hosting tier with a free domain.
- [ ] Connect the repository, or upload built `site/dist` through your host's supported
  deployment workflow. GitHub Actions is not needed to deploy through Pages' Git integration.
- [ ] If repo root is the Pages root, configure:

| Setting | Value |
|---|---|
| Framework | Astro or None (explicit command below is authoritative) |
| Node | 24+ |
| Build | `npm --prefix site ci && npm --prefix site run build` |
| Output | `site/dist` |
| Domain | `gridzero.win` |

If you set the hosting root to `site`, use `npm ci && npm run build` and output
`dist` instead. Do not leave the old `exit 0` / output `site` configuration.

### Production checks

- [ ] Open `/`, `/play` and `/play/`, privacy, support, credits, and a missing page.
- [ ] Confirm `_headers` is applied, bundles/worker load under CSP, no third-party
  gameplay requests or console errors, and `/sw.js` is not long-term cached.
- [ ] iPhone/iPad Safari: Share → Add to Home Screen → Add; enable Open as Web App
  if offered. Launch from icon, play/save, close/reopen, switch offline, reopen,
  and generate a Custom puzzle offline.
- [ ] Android browser: menu → Install app / Add to home screen; repeat those checks.
- [ ] Check PNG icons, standalone window, safe areas, portrait/landscape, and touch.
- [ ] Test an update with an existing saved game. Close all old game windows/tabs
  to activate a waiting service-worker update; do not clear site data as an update step.
- [ ] Confirm documented limits: browser storage can be evicted/cleared, private mode
  may not persist, installed app and browser may use separate storage, no native sync.

PWA installation needs **no Apple/Google store membership or fee**. HTTPS is
required for production offline caching. An HTTP LAN preview is online-only.

## 3. iOS / iPadOS — what is left to publish

### Owner authentication and setup

- [ ] Confirm active paid Apple Developer Program membership for your team. Apple's
  listed price is **US$99/year**, subject to region/eligible fee waivers.
- [ ] Sign into Xcode → Settings → Accounts with that account; complete 2FA and
  approve Keychain prompts locally. Team is in gitignored `Signing.local.xcconfig`.
- [ ] Register/confirm bundle ID `win.gridzero.app` belongs to your team. Do not change
  it after launch; if unavailable, choose the permanent ID before uploading.
- [ ] Create the GridZero app record in App Store Connect using that bundle ID,
  platform iOS, primary language, and your own stable SKU.
- [ ] Accept pending program/App Store agreements; verify account role permits uploads.
- [ ] Confirm the Xcode/SDK release is accepted for App Store uploads **today**. The
  installed Xcode 27.0 build was `27A266a`; don't assume beta SDKs can be submitted.

### Build and sign

- [ ] Rebuild/test current source and collection. Deployment target is iOS 26.0;
  verify a physical iPhone and iPad/minimum supported OS, not only an iOS 27 simulator.
- [ ] For direct development installs: connect/unlock phone, approve Trust, enable
  Developer Mode, choose device. TestFlight does **not** need Developer Mode or USB.
- [ ] Archive with automatic provisioning after account access is healthy:

```sh
xcodebuild -project GridZero.xcodeproj -scheme GridZero \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/GridZero.xcarchive -allowProvisioningUpdates archive
```

- [ ] Obtain required Apple Distribution signing/profile assets through Xcode's
  automatic signing/distribution flow. Do not revoke another machine's certificates.
- [ ] Open Xcode → Window → Organizer → Archives. Select archive → Distribute App
  → App Store Connect → upload. CLI export/upload can be added later using a local
  export-options file and secure authentication, not secrets in repository files.
- [ ] Confirm archive validation, privacy manifest, universal iPhone/iPad support,
  bundle/version/build, app icon, and no Debug-only layout probes in Release.

### TestFlight and store review

- [ ] Wait for processing in App Store Connect; resolve export-compliance/encryption
  questions truthfully. Don't tick exemptions just to bypass a warning.
- [ ] Add yourself to an internal TestFlight group, install Apple's TestFlight on your
  phone, accept invitation, and install GridZero. External testers/public links may
  require Beta App Review; internal testing and public release are different steps.
- [ ] Test gameplay/offline/save restoration/upgrade on the actual TestFlight build.
- [ ] Complete listing, required device-size screenshots, age rating, categories,
  privacy answers (no app data collection as currently implemented), support contact,
  review contact/notes, price Free, regions, and release policy.
- [ ] Submit for App Review. After approval, publish as chosen and replace only the
  real approved native store/beta links on the homepage.

**No new core gameplay feature is required solely to produce an iOS build.** The
remaining work is release signing/authentication, current-build verification,
App Store Connect setup, listing material, beta validation, and approval.

## 4. Android — signed APK and optional Google Play

### Build machine and permanent key

- [ ] Run `bash tools/setup_android.sh` to install JDK 17, SDK/build tools and adb;
  review SDK license prompts. See `android/README.md`.
- [ ] Locate the existing permanent release/upload keystore, its alias, and passwords
  locally. If this app has ever shipped, preserve signing identity; don't casually
  generate a replacement. Back up the keystore securely offline.
- [ ] Put the original keystore in gitignored `android/signing/` and fill
  `android/Signing.local.properties` from its example. Gradle signing is wired to
  that file; without it, release output is unsigned, not silently debug-signed.
  Use `bash tools/android.sh build` to require signing and verify the fingerprint.
  To preserve the old repo's sideload signature, copy its old `~/.android/debug.keystore`
  as `android/signing/previous-debug.keystore`; do not publish that legacy key to stores.
- [ ] Do not commit keys/passwords or pass them in logged build commands. Confirm
  the resulting certificate fingerprint matches the intended release identity.
- [ ] Debug → permanent-signature APK cannot normally update in place. Uninstalling
  a debug installation loses local game data; warn testers before doing it.

```sh
source android/env.local.sh
./android/gradlew -p android :app:testDebugUnitTest :app:lintDebug
./android/gradlew -p android :app:assembleRelease :app:bundleRelease
```

After signing is configured, APK is under `android/app/build/outputs/apk/release/`
and AAB under `android/app/build/outputs/bundle/release/`. Verify actual filenames;
never upload a debug-signed release just because Gradle calls it "release".

- [ ] Install intended signed APK on real Android devices; verify offline behavior,
  no Google services dependency, minimum API, tablets/layout/accessibility/save upgrades.
- [ ] Retest the expanded 8,000-bank changes; the older physical-device report covered 400.
- [ ] Keep application ID `win.gridzero.android` stable; increase `versionCode` per upload.

### Choose distribution

**Signed APK on your website/GitHub Releases:** no Google Play publishing fee.
Provide the real HTTPS APK, version, SHA-256, signing fingerprint, source/license
links, and installation instructions. Native APK distribution and a PWA shortcut
are different options. Keep using the same release key for updates.

**Google Play (optional):**

- [ ] Play Console developer account, identity/device verification, and **US$25
  one-time registration fee** (check regional terms/current rules).
- [ ] Create app record; complete listing/screenshots/icon/feature graphic/support
  contact, content rating, audience, ads declaration, access declaration, and Data
  safety/privacy policy. Recheck the current target-API requirement; code targets 36.
- [ ] Configure Play App Signing and distinguish the upload key from the Play app
  signing key. Understand signature differences if also distributing direct APKs.
- [ ] Upload the signed **AAB** to internal testing; test from Play, not only adb.
- [ ] New personal accounts may need a closed test: currently **12 testers opted in
  continuously for 14 days**, then an application for production access. Check your
  console: these requirements depend on account type/creation date and can change.
- [ ] Complete review and staged production rollout; publish the real Play link only
  when available. F-Droid is a separate optional review/build path, not automatic.

## 5. GitHub Actions, cost control, and zero-GitHub-bill policy

Actions are automated checks on pushes/pull requests: Swift correctness, Android
tests/lint/build, and web build/browser tests. They do not publish to stores, bill
users, or require a GitHub paid subscription.

- Standard GitHub-hosted runners are **free for public repositories**.
- Private repositories have a free allowance (GitHub Free currently 2,000 minutes /
  500 MB artifact storage), then may bill overages when payment is configured.
- Larger runners are billed even for public repositories. This project uses only
  standard `macos-15` / `ubuntu-latest`, no larger runners or artifact uploads.
- Each job now has `if: github.event.repository.private == false`. In a private
  copy these jobs are skipped, so this workflow does not consume private-runner minutes.
  Automatic dependency caches were removed; concurrency cancels obsolete runs.
- You can disable this workflow or all Actions in repository Settings → Actions.
  Everything can run locally. That does not prevent Cloudflare Pages from building.
- Account-wide safety: in GitHub Billing → Budgets and alerts, use a **$0 Actions
  budget with usage stopped at the limit** where that control is offered. Check
  other repositories/workflows too; this repo cannot set account-wide budgets.
- No paid GitHub product is needed. Apple/Google publisher fees and domain/hosting
  costs are separate and must be consciously approved by you.

## 6. Launch, updates, and rollback

- [ ] Record released commit, collection hash/version, native build numbers, APK hash
  and signing fingerprint, and deployed web build.
- [ ] Replace Coming soon only with actual approved links; keep browser Play available.
- [ ] Smoke-test production links/downloads on iPhone, Android, desktop and tablet.
- [ ] Collect issues through the documented support channel without adding analytics.
- [ ] For web regressions, redeploy the last working static build; retain local save
  schema compatibility and test service-worker update behavior.
- [ ] For native regressions, stop staged rollout where possible and submit a fixed
  higher build/version. You cannot make installed native binaries magically roll back.

## Official references (review again before publishing)

- [Apple enrollment and fees](https://developer.apple.com/programs/enroll/)
- [App Store Connect help](https://developer.apple.com/help/app-store-connect/)
- [Apple upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)
- [Google Play setup and fee](https://support.google.com/googleplay/android-developer/answer/6112435)
- [Google Play testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465)
- [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
