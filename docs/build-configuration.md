# Frontend build configuration (`--dart-define`)

Every optional feature in the Flutter app is gated on a build-time
`--dart-define`. Dart compiles these in via `String.fromEnvironment`, so they
are fixed when the binary is produced — there is no runtime `.env`, and the
only value a user can change afterwards is the server URL (see
`API_BASE_URL` below).

A define that is absent does not crash the app. It silently removes whatever
depends on it: the feature board card disappears, crash reporting never
starts, guest sign-up loses its challenge. That is deliberate — self-hosted
builds stay free of Firebase, Cloudflare, and the studio's tracker — but it
also means **a missing define looks exactly like a bug you did not write**. If
a feature is "not showing up" in a local build, check this table first.

## The full list

| Define | Read by | Default when unset | What you lose without it |
| --- | --- | --- | --- |
| `API_BASE_URL` | `lib/config/api_config.dart:20` | Debug: `http://localhost:8000` (`http://10.0.2.2:8000` on Android emulators). Release: **empty** | In release builds, nothing works until the user picks a server on the login screen. |
| `REQTRACK_APP_KEY` | `lib/config/feedback_config.dart:16` | `''` | **The whole feature board and feedback card.** `FeedbackConfig.isConfigured` is false, so the account-screen card renders `SizedBox.shrink()` and there is no way into `/you/feature-board`. |
| `REQTRACK_URL` | `lib/config/feedback_config.dart:26` | `https://reqtrack.tropicalthink.com` | Nothing — the default is the real tracker. Override only to point at a different reqtrack instance. |
| `TURNSTILE_SITE_KEY` | `lib/config/turnstile_config.dart:21` | `''` | Web-only. Guest sign-up runs unchallenged; the API then accepts unattested guests. |
| `APP_CHECK_ENABLED` | `lib/config/app_check_config.dart:14` | `''` (disabled) | Mobile-only. Play Integrity / App Attest is not enforced. Must be the literal string `true`; any other value is off, and it is ignored on web regardless. |
| `GLITCHTIP_DSN` | `lib/main.dart:42`, `lib/app.dart:50` | `''` | Sentry/GlitchTip is never initialised — no crash reports. |
| `ENVIRONMENT` | `lib/main.dart:43`, `lib/app.dart:51` | `development` | Only tags crash reports. Harmless locally; set it to `production` for store and web builds. |
| `WEB_APP_URL` | `lib/utils/invite_link.dart:10` | `https://app.mitlist.me` | Shareable invite links point at the official web app instead of your host. |
| `TERMS_URL` | `lib/config/iap_config.dart:32` | `https://mitlist.me/terms` | Store paywall links to the official terms page. |
| `PRIVACY_URL` | `lib/config/iap_config.dart:36` | `https://mitlist.me/privacy` | Store paywall links to the official privacy page. |

Nothing else in `lib/` reads the environment — `grep -rn fromEnvironment lib/`
is the authoritative check, and it should return exactly the rows above.

### Not actually read by the app

`FIREBASE_PROJECT_ID` is passed as a `--dart-define` by
`.forgejo/workflows/mobile-beta.yml`, but no Dart code reads it. Native builds
take their Firebase settings from `google-services.json` and
`GoogleService-Info.plist`; the define is vestigial. `FIREBASE_PROJECT_NUMBER`
is a workflow-level variable only — the beta job validates it is numeric and
never passes it to Flutter.

Both names are also real *backend* variables (`backend/.env.example:73`,
`docs/DEPLOYMENT.md`), where they are load-bearing for App Check verification.
Do not read a value from one side as configuring the other: the API's
`FIREBASE_PROJECT_ID` is used, the app's is not.

## Recipes

### Local run against production API, with every feature on

```
flutter run \
  --dart-define=API_BASE_URL=https://api.mitlist.me \
  --dart-define=REQTRACK_APP_KEY=sk_...
```

`REQTRACK_URL` is omitted on purpose: `FeedbackConfig.baseUrl` already falls
back to the production tracker. `APP_CHECK_ENABLED` is best left off locally —
a debug build has no Play Integrity attestation to offer.

### Everything, explicitly

```
flutter run \
  --dart-define=API_BASE_URL=https://api.mitlist.me \
  --dart-define=REQTRACK_APP_KEY=sk_... \
  --dart-define=REQTRACK_URL=https://reqtrack.tropicalthink.com \
  --dart-define=TURNSTILE_SITE_KEY=0x... \
  --dart-define=APP_CHECK_ENABLED=true \
  --dart-define=GLITCHTIP_DSN=https://...@glitchtip.../1 \
  --dart-define=ENVIRONMENT=development \
  --dart-define=WEB_APP_URL=https://app.mitlist.me
```

On PowerShell, either keep it on one line or continue with a backtick (`` ` ``)
rather than `\`.

## What CI actually passes

The two official pipelines do **not** pass the same set, and the difference is
load-bearing.

**Web PWA** — `.forgejo/workflows/build-prod.yml` → `Dockerfile.prod` (as
`ARG`s, forwarded to `flutter build web`):
`API_BASE_URL`, `GLITCHTIP_DSN`, `ENVIRONMENT=production`, `REQTRACK_APP_KEY`,
`REQTRACK_URL`, `TURNSTILE_SITE_KEY`.

**Mobile beta** — `.forgejo/workflows/mobile-beta.yml` (Android appbundle and
iOS, identical defines):
`API_BASE_URL`, `GLITCHTIP_DSN`, `ENVIRONMENT`, `APP_CHECK_ENABLED=true`,
`FIREBASE_PROJECT_ID`.

> **Known gap:** the mobile workflow does not pass `REQTRACK_APP_KEY`, so the
> feature board is invisible in every beta build shipped to testers. Web has
> it; mobile does not. Add the define to both build steps in
> `mobile-beta.yml` — and the corresponding secret — when the board should
> reach mobile testers.

Secrets live in the Forgejo repo settings at `git.tropicalthink.com`; the web
deploy also reads `hosts/anansi/stacks/mitlist/secrets.sops.env` in the infra
repo.

## Adding a new define

1. Read it through a small config class in `lib/config/`, not inline at the
   call site — that is where the "unset means disabled" rule gets enforced
   once instead of everywhere.
2. Default to the *disabled* value, and gate the UI on an `isConfigured` /
   `enabled` getter so a self-hosted build degrades instead of breaking. Note
   the `REQTRACK_URL` comment in `feedback_config.dart:22`: a CI secret that
   is unset arrives as an empty-but-*defined* value, which shadows a non-empty
   `defaultValue`. Resolve fallbacks in a getter, not in `defaultValue`.
3. Add it to `Dockerfile.prod` (both the `ARG` and the `flutter build web`
   line) and to the relevant workflow.
4. Add a row to the table above.

## Related

- [`DEPLOYMENT.md`](DEPLOYMENT.md) — backend environment variables, which are
  a separate set read at runtime.
- [`mobile-release-readiness.md`](mobile-release-readiness.md) — store-build
  specifics and the privacy implications of shipping `GLITCHTIP_DSN`.
- [`iap-subscriptions-plan.md`](iap-subscriptions-plan.md) — `TERMS_URL` /
  `PRIVACY_URL` in the paywall context.
