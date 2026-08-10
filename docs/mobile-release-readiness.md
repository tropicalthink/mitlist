# Mobile App-Store Release Readiness

> Updated 2026-08-10. Mobile beta builds are now defined in
> `.gitea/workflows/mobile-beta.yml`; protected signing and Firebase files are
> injected at build time and are never committed.

---

## Drift Check

```
git diff --stat e8c991f3..HEAD -- frontend/android frontend/ios .gitea/workflows
```

Result: no output — zero drift. The files the plan targeted are unchanged since the
plan was written.

---

## 1. What Already Exists

### Android

| Item | Status | Source |
|------|--------|--------|
| `applicationId` | `me.mitlist` | `frontend/android/app/build.gradle` line 34 |
| `namespace` | `me.mitlist` | `frontend/android/app/build.gradle` line 18 |
| Release signing wired | Yes — loads `android/key.properties` and fails release builds if signing is absent | `build.gradle` |
| `minifyEnabled` | `true` | `build.gradle` line 57 |
| `shrinkResources` | `true` | `build.gradle` line 58 |
| ProGuard | `proguard-android-optimize.txt` + `proguard-rules.pro` | `build.gradle` line 59; rules file present |
| ProGuard rules | Flutter embedding, TFLite, Play Core suppression, ML Kit suppression | `frontend/android/app/proguard-rules.pro` |
| `key.properties.example` | Present — documents `storePassword`, `keyPassword`, `keyAlias`, `storeFile` | `frontend/android/key.properties.example` |
| `key.properties` (actual) | Gitignored, not present | `frontend/android/.gitignore` |
| Keystore file (`.jks`) | Gitignored, not present | `frontend/android/.gitignore` |
| App label | `mitlist` | `frontend/android/app/src/main/AndroidManifest.xml` |
| `google-services.json` | Not tracked, not present on disk | `git ls-files` confirmed absent |
| Google Services Gradle plugin (`com.google.gms`) | Declared | `build.gradle` |
| App version | `1.0.0+1` (versionName=1.0.0, versionCode=1) | `frontend/pubspec.yaml` |
| App icon | `frontend/assets/icon/icon.png`, 1024×1024 PNG (16-bit sRGB) | `file` + `identify` |
| Foreground icon | `frontend/assets/icon/icon_foreground.png` | present |

### iOS

| Item | Status | Source |
|------|--------|--------|
| Bundle identifier (Runner) | `me.mitlist` | `frontend/ios/Runner.xcodeproj/project.pbxproj` line 371 |
| Bundle identifier (RunnerTests) | `me.mitlist.RunnerTests` | `project.pbxproj` lines 388, 405, 420 |
| iOS deployment target | 12.0 | `project.pbxproj` lines 349, 476, 527 |
| Swift version | 5.0 | `project.pbxproj` |
| MARKETING_VERSION | `1.0` | `project.pbxproj` (Debug/Profile/Release build configs) |
| CURRENT_PROJECT_VERSION | Tied to `$(FLUTTER_BUILD_NUMBER)` in Release config | `project.pbxproj` |
| CODE_SIGN_STYLE | `Automatic` (all configs) | `project.pbxproj` lines 384, 401, 416 |
| CODE_SIGN_IDENTITY (device) | `iPhone Developer` (not `iPhone Distribution`) | `project.pbxproj` lines 335, 456, 513 |
| DEVELOPMENT_TEAM | **Not set** — no `DEVELOPMENT_TEAM` key in pbxproj | Grep confirmed absent |
| PROVISIONING_PROFILE | **Not set** | Grep confirmed absent |
| Entitlements | Associated domains and production APNs are declared | `Runner/Runner.entitlements` |
| `GoogleService-Info.plist` | Not tracked, not present on disk | `git ls-files` confirmed absent |
| APNs configuration | Push entitlement and remote-notification background mode are declared; credentials remain protected CI inputs | entitlements + `Info.plist` |
| Podfile | Standard Flutter Podfile; no explicit `platform :ios` line (inherits from Flutter) | `frontend/ios/Podfile` |

### Push notifications (FCM)

- `firebase_messaging: ^15.2.5` and `firebase_core: ^3.13.1` are declared in `pubspec.yaml`.
- `FcmService.init()` calls `Firebase.initializeApp()` wrapped in a try/catch; if it fails (missing config) it logs a warning and returns — the app does not crash.
- FCM is **not available without `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)**; push notifications simply won't work.
- The Google Services Gradle plugin is enabled. Release builds fail fast when
  the native Firebase configuration is missing.
- No `firebase_options.dart` exists — Firebase is initialised without explicit `FirebaseOptions`, relying solely on the native config files.

### Crash reporting (Sentry/GlitchTip)

- `sentry_flutter: ^8.14.2` in `pubspec.yaml`.
- Sentry only initialises when a `GLITCHTIP_DSN` dart-define is injected at build time (`frontend/lib/main.dart` lines 27–42). If the define is absent (the default), Sentry is never started — **opt-in by the operator, not the user**.
- `tracesSampleRate = 0.0` — no performance tracing data sent.
- No PII or user-identity fields are set.

### Store listing assets

- `store/` directory is tracked in git and contains:
  - `store/fastlane/Appfile` — `app_identifier("me.mitlist")`; `apple_id("")` empty
  - `store/fastlane/Fastfile` — single iOS lane (`screenshots`) using `capture_screenshots`; no `deliver`, no Android lane, no signing lane
  - `store/fastlane/metadata/android/en-US/full_description.txt` and `short_description.txt` — Play Store copy, ready
  - `store/fastlane/metadata/en-US/description.txt` — App Store description + metadata (title, subtitle, keywords, categories, copyright) — ready
  - `store/fastlane/metadata/en-US/release_notes.txt` — v1 release notes stub ready
  - `store/google_play_full.txt`, `store/google_play_short.txt`, `store/app_store_full.txt`, `store/app_store_short.txt` — listing copy ready
  - `store/screenshot_spec.txt` — spec for 6-8 screenshots per store, device sizes, layout guide
  - `store/README.md` — manual submission procedure documented
- **No actual screenshot images** are present.
- No feature graphic (Play Store 1024×500 px) exists.
- Fastlane `Gemfile` / `Gemfile.lock` are absent — Fastlane is not yet installable as a project dependency.

### CI / Deploy workflows

- `.gitea/workflows/deploy-prod.yml` builds Flutter web and Go backend.
- `.gitea/workflows/mobile-beta.yml` builds signed Android and iOS beta artifacts on demand.
- `.gitea/workflows/ci.yml` — runs `dart analyze` + `flutter test` on an `ubuntu-latest` runner. No mobile build. No signing. No `workflow_dispatch`.

### In-app account deletion

- `frontend/lib/screens/you/account_screen.dart` — `_confirmDeleteAccount()` present (line 285), wired to UI button (line 864).
- Backend: `DELETE /me` handler present (`backend/internal/api/handlers/auth.go` line 63); `user_service.go` line 242 documents soft-delete.
- **App Store requirement satisfied**: account deletion is reachable in-app without contacting support.

---

## 2. What's Missing, Per Platform

### Android / Google Play

- [ ] **Google Play Console developer account** — $25 one-time; requires a valid business or personal identity.
- [ ] **Release keystore** — generate with `keytool` (see `key.properties.example`); store file and `key.properties` are operator secrets, never committed.
- [ ] **Keystore custody + backup plan** — losing the upload keystore permanently locks the app off of future Play updates (unless Play App Signing is enrolled before first upload).
- [ ] **Play App Signing decision** — enroll at first upload to delegate key custody to Google; strongly recommended for new apps. Must be decided before the first AAB upload.
- [ ] **`google-services.json`** — must be created in Firebase Console (one project per target environment), dropped into `android/app/` at build time (CI secret or local file), and **never committed**.
- [ ] **`com.google.gms.google-services` Gradle plugin** — must be added to `android/app/build.gradle` (plugin block) before Firebase works at runtime. This is a build-config change, deferred to the implementation plan.
- [ ] **Store listing completion**:
  - [ ] Feature graphic (1024×500 px PNG, no alpha)
  - [ ] Screenshots (min 2, up to 8; 1080×1920 minimum) — spec in `store/screenshot_spec.txt`
  - [ ] Short description (already drafted in `store/fastlane/metadata/android/en-US/short_description.txt`)
  - [ ] Full description (already drafted in `store/fastlane/metadata/android/en-US/full_description.txt`)
  - [ ] App icon uploaded to Play Console (1024×1024 PNG — `frontend/assets/icon/icon.png` meets spec)
- [ ] **Content rating** — IARC questionnaire in Play Console (household/productivity app, no objectionable content expected; should be "Everyone").
- [ ] **Data safety form** — must disclose:
  - Firebase Messaging (device identifiers — FCM token — are sent to Google; declared under "Device or other IDs").
  - Sentry/GlitchTip crash reporting: only active when operator injects `GLITCHTIP_DSN` at build time; if the Play Store build omits the DSN define, this is not collected. Decide whether the published binary includes the DSN.
  - Expense CSV export: user-initiated, no automatic data collection.
  - No location, contacts, microphone (camera used for OCR only, no upload to third parties).
- [ ] **Internal testing → production track** — create an internal test track, upload first AAB, validate, then promote.
- [ ] **Fastlane `Gemfile`** — add so `bundle exec fastlane` is reproducible; the current `store/fastlane/` has no `Gemfile`.
- [ ] **Android Fastlane lane** — `store/fastlane/Fastfile` has no Android lane; a `supply` or `gradle`/`upload_to_play_store` lane needs to be added for automated upload.

### iOS / App Store

- [ ] **Apple Developer Program account** — $99/year; requires Apple ID, identity verification, D-U-N-S number for organizations. Enrollment can take 1–3 business days.
- [ ] **Bundle ID registration** — register `me.mitlist` in App Store Connect / Certificates, Identifiers & Profiles.
- [ ] **Signing certificate + provisioning profile** — generate a Distribution certificate and App Store provisioning profile for `me.mitlist`; configure in Xcode or via Fastlane `match`.
  - Currently `CODE_SIGN_IDENTITY` is `iPhone Developer` (development only) and `DEVELOPMENT_TEAM` is not set. Must be updated before an App Store build compiles.
- [ ] **`GoogleService-Info.plist`** — create in Firebase Console, drop into `ios/Runner/` at build time; never commit.
- [ ] **APNs key** — generate an APNs Authentication Key (.p8) in the Apple Developer portal; upload to Firebase Console so FCM can deliver to iOS devices.
- [ ] **Push Notifications + Background Modes capabilities** — must be enabled in Xcode for the `me.mitlist` App ID (`fcm_service.dart` line 28 notes this requirement).
- [ ] **App Store Connect app record** — create the app in App Store Connect (bundle ID, name, primary language, SKU).
- [ ] **App Privacy "nutrition label"** — declare data collected:
  - Firebase Messaging (Device ID — used for push delivery — "not linked to identity" unless you link it).
  - Sentry/GlitchTip (Crash Data — if DSN baked into the IPA; decide before submission).
  - No location, no contacts, no camera upload to third parties.
  - User-initiated data export doesn't trigger a disclosure.
- [ ] **Screenshots per device size** — App Store requires at minimum 6.9" (iPhone 16 Pro Max: 1320×2868) and optionally 6.5" (1242×2688). No screenshots exist yet; spec is in `store/screenshot_spec.txt`.
- [ ] **App icon alpha channel** — App Store rejects icons with alpha; `frontend/assets/icon/icon.png` is 16-bit sRGB — verify no alpha channel before submission.
- [ ] **App Review: account deletion** — satisfied (in-app `DELETE /me` confirmed above).
- [ ] **App Review: account creation / guest mode** — review requires a demo account or guest access; the app requires a backend URL and registration. Prepare a demo account or document self-hosted setup for reviewers.
- [ ] **`apple_id` in `store/fastlane/Appfile`** — currently empty string; must be filled before Fastlane `deliver` can be used.
- [ ] **Fastlane delivery lane** — `store/fastlane/Fastfile` only has a `screenshots` lane; a `beta` and `release` lane (using `deliver` or `upload_to_app_store`) need to be added.
- [ ] **macOS CI runner** — iOS builds require Xcode; Gitea CI currently uses `ubuntu-latest` only. A macOS runner or a macOS-based CI service (e.g. Codemagic, Bitrise, self-hosted Mac) is needed.

---

## 3. Build & CI Recommendation

The on-demand closed-beta workflow requires these Gitea secrets:

- `BETA_API_BASE_URL` — required, HTTPS API origin (the workflow fails before
  building if it is missing or malformed).
- `ANDROID_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`,
  `ANDROID_KEY_ALIAS`, and `GOOGLE_SERVICES_JSON_B64` — Android signing/Firebase
  inputs.
- `IOS_DISTRIBUTION_CERTIFICATE_B64`, `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`,
  `IOS_PROVISIONING_PROFILE_B64`, `IOS_EXPORT_OPTIONS_PLIST_B64`,
  `IOS_DEVELOPMENT_TEAM`, and `GOOGLE_SERVICE_INFO_PLIST_B64` — iOS
  signing/Firebase inputs.
- `GLITCHTIP_DSN_BETA` — optional crash-reporting DSN. `BETA_ENVIRONMENT` is
  also optional and defaults to `beta`.

Both artifacts receive the same numeric `${{ gitea.run_number }}` as their
Flutter build number, so successive workflow runs produce increasing Android
version codes and iOS bundle versions. The URL, DSN, and signing material are
only passed through protected workflow environment variables; they are never
written to artifacts or repository files.

### Android (no macOS required)

Trigger: `workflow_dispatch` or push of a `v*` tag.

```
flutter build appbundle --release \
  --dart-define=ENVIRONMENT=production \
  # omit GLITCHTIP_DSN if the published binary should not phone home
```

CI secrets required:
- `KEYSTORE_BASE64` — base64-encoded `.jks` file
- `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD` — from `key.properties`

Runner step: decode `KEYSTORE_BASE64` to a temp file, write `android/key.properties`,
run `flutter build appbundle --release`, upload the `.aab` from
`build/app/outputs/bundle/release/app-release.aab` as a CI artifact or push via
`fastlane supply` (once the Android lane is added).

**Prerequisite fix before this works**: add the `com.google.gms.google-services`
plugin to `android/app/build.gradle` and inject `google-services.json` as a CI
secret (base64-encoded, decoded to `android/app/google-services.json` before build).

### iOS (macOS runner required)

Trigger: same `workflow_dispatch` / `v*` tag.

```
flutter build ipa --release \
  --dart-define=ENVIRONMENT=production
```

CI secrets required:
- Apple Distribution certificate (P12 base64 + password)
- App Store provisioning profile (base64)
- `GoogleService-Info.plist` (base64-decoded to `ios/Runner/` before build)

Gitea does not have a macOS runner today. Options:
1. Add a self-hosted macOS Gitea runner (Mac mini or VM).
2. Use a third-party CI (Codemagic free tier supports Flutter IPA builds).
3. Build locally on a Mac and upload manually for the first release; add CI later.

The `store/fastlane/Fastfile` needs delivery lanes before CI submission is automated.

---

## 4. Open Questions for the Maintainer

These decisions are blocked on the maintainer; nothing in the repo answers them.

1. **Is `me.mitlist` the final bundle ID for both stores?** It is set consistently in `android/app/build.gradle` (applicationId) and `ios/Runner.xcodeproj/project.pbxproj` (PRODUCT_BUNDLE_IDENTIFIER), and in `store/fastlane/Appfile`. Confirm before registering in Play Console / App Store Connect — changing it later requires a new app record.

2. **Who holds the release keystore and how is it backed up?** The Android upload keystore is permanent — losing it and not being enrolled in Play App Signing means you can never update the app. Recommend: Play App Signing enrollment at first upload + keystore backed up in a password manager or cold storage.

3. **Use Play App Signing?** Recommended for new apps. Must be enrolled at first AAB upload. Decide before upload.

4. **Is there an Apple Developer account?** None found in the repo. If not, enrollment must start now (can take 1–3 days). A macOS machine or CI runner will also be needed.

5. **Does the published binary include `GLITCHTIP_DSN`?** If yes, the Data Safety form (Android) and App Privacy label (iOS) must disclose crash data collection. If the DSN is omitted from the store build, no disclosure is needed for crash reporting. This is a product/privacy decision.

6. **Who produces screenshots?** The spec is defined (`store/screenshot_spec.txt`) but no images exist. This is typically 1–2 days of work with a simulator and a design tool.

7. **Fastlane or manual upload?** `store/fastlane/` is present but incomplete (no delivery lanes, no `Gemfile`, empty `apple_id`). For a first release, manual upload via App Store Connect web UI and Play Console web UI is simpler. Fastlane adds value once there are repeat submissions.

8. **Does the privacy "Data Safety / App Privacy" disclosure need legal review?** Given the AGPL-3.0 open-source nature, no ads, no analytics by default, and opt-in crash reporting, the disclosure should be straightforward — but confirm with the operator/legal contact if the hosted instance bakes in a DSN.

9. **Demo account for App Review (iOS)?** The iOS reviewer needs to log in. Prepare a demo account or document the self-hosted setup in the review notes.

10. **Feature graphic for Play Store?** Not present. Needs a 1024×500 px PNG (no alpha). The app icon alone is not sufficient.

---

## 5. Recommended Sequence & Definition of Done

Gate: complete the OSS/self-host v1 (plans 011–013) first. Mobile store submission is a subsequent track.

### Phase 1 — Accounts & keys (maintainer-only, ~1 week)

- [ ] Create / confirm Google Play Console developer account
- [ ] Create / confirm Apple Developer Program account (start early — can take days)
- [ ] Generate Android release keystore; enroll in Play App Signing
- [ ] Create Firebase project; download `google-services.json` and `GoogleService-Info.plist`
- [ ] Generate APNs Authentication Key in Apple Developer portal; upload to Firebase
- [ ] Register `me.mitlist` bundle ID in App Store Connect
- [ ] Create app records in Play Console and App Store Connect

### Phase 2 — Build plumbing (engineering, ~2 days)

- [ ] Add `com.google.gms.google-services` plugin to `android/app/build.gradle` (required for FCM)
- [ ] Set `DEVELOPMENT_TEAM` and update `CODE_SIGN_IDENTITY` to `iPhone Distribution` in `ios/Runner.xcodeproj/project.pbxproj` (or configure via Xcode)
- [ ] Add CI secrets (keystore, `key.properties` values, FCM config files)
- [ ] Add `workflow_dispatch`-triggered mobile build jobs to `.gitea/workflows/`
- [ ] Validate a signed Android AAB builds cleanly (local or CI)
- [ ] Validate a signed iOS IPA builds cleanly (requires macOS)

### Phase 3 — Store assets (design, ~2 days)

- [ ] Produce 6–8 screenshots per store per device size (spec: `store/screenshot_spec.txt`)
- [ ] Produce Play Store feature graphic (1024×500 px PNG)
- [ ] Verify app icon has no alpha channel (App Store requirement)

### Phase 4 — Compliance (maintainer, ~1 day)

- [ ] Complete Data Safety form in Play Console (FCM device ID, optional crash reporting)
- [ ] Complete App Privacy label in App Store Connect (same disclosures)
- [ ] Complete IARC content rating questionnaire in Play Console
- [ ] Confirm listing copy is final (`store/fastlane/metadata/` is ready as a starting point)

### Phase 5 — Submit & iterate (~1–2 weeks buffer for review)

- [ ] Upload AAB to Play Console internal testing track; validate on device
- [ ] Promote to production track on Play Console
- [ ] Submit IPA to TestFlight; validate on device
- [ ] Submit to App Store review (allow 1–3 business days; rejections add time)

### Definition of Done

Mobile release is done when ALL of the following hold:

- [ ] Android app is live on Google Play (production track, not just internal)
- [ ] iOS app is live on the App Store (not just TestFlight)
- [ ] Both apps launch, authenticate, and receive a push notification on a real device
- [ ] `google-services.json` and `GoogleService-Info.plist` are confirmed not in git (`git ls-files | grep -iE "google-services|GoogleService"` returns empty)
- [ ] CI produces a signed AAB on a `v*` tag push (Android minimum)
- [ ] Data Safety and App Privacy labels are published and accurate

---

## Files Verified During Investigation

| File | Key finding |
|------|-------------|
| `frontend/android/app/build.gradle` | Signing wired, minify on, `applicationId = "me.mitlist"` |
| `frontend/android/key.properties.example` | Keystore template present; actual file gitignored |
| `frontend/android/.gitignore` | `key.properties`, `**/*.keystore`, `**/*.jks` all ignored |
| `frontend/android/app/proguard-rules.pro` | Flutter + TFLite + Play Core rules present |
| `frontend/ios/Runner.xcodeproj/project.pbxproj` | Bundle ID `me.mitlist`, `CODE_SIGN_STYLE=Automatic`, no `DEVELOPMENT_TEAM` |
| `frontend/ios/Runner/Runner.entitlements` | `applinks:app.mitlist.me` associated domain only |
| `frontend/pubspec.yaml` | `version: 1.0.0+1`, `firebase_messaging: ^15.2.5`, `sentry_flutter: ^8.14.2` |
| `frontend/lib/main.dart` | Sentry opt-in via `GLITCHTIP_DSN` dart-define; Firebase init without `firebase_options.dart` |
| `frontend/lib/services/fcm_service.dart` | FCM init wrapped in try/catch; documents `google-services.json` requirement |
| `frontend/lib/services/error_reporter.dart` | Sentry no-op when DSN absent |
| `frontend/lib/screens/you/account_screen.dart` | `_confirmDeleteAccount()` present (line 285) |
| `backend/internal/api/handlers/auth.go` | `DELETE /me` endpoint confirmed (line 63) |
| `.gitea/workflows/deploy-prod.yml` | Web + backend Docker only; no mobile |
| `.gitea/workflows/ci.yml` | `dart analyze` + `flutter test` on ubuntu only; no mobile build |
| `store/fastlane/Appfile` | `app_identifier("me.mitlist")`; `apple_id("")` empty |
| `store/fastlane/Fastfile` | Screenshots lane only; no delivery lanes; no Gemfile |
| `store/fastlane/metadata/` | Listing copy (Android + iOS) ready; no screenshot images |
| `store/screenshot_spec.txt` | Device sizes and content spec defined |
| `frontend/assets/icon/icon.png` | 1024×1024 PNG, 16-bit sRGB (verify no alpha before iOS submission) |
