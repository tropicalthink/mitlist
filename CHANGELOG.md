# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project aims to
follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Every tip in the onboarding emails links to the screen it describes (the
  title and an "Open" link on each sticky note, and an `Open:` line in the
  plain-text body), and a step carries at most three tips; the day-30 email
  drops the Home Assistant tip to fit.

- The app's sections (`/home`, `/lists`, `/money`, `/chores`, `/recipes`,
  `/calendar`, `/you`, `/scanner` and their sub-paths) are now App Link / Universal Link
  paths on app.mitlist.me, so the buttons in the onboarding tips emails open
  the installed app instead of the web app in a browser. Needs a new store
  build on both platforms; auth, `/auth/callback` and `/premium` stay
  browser-only on purpose.

- Onboarding tips: five emails over the first month after sign-up (day 1, 3,
  7, 14, 30) on households, lists, money, chores and the rest of the app, in
  the same paper / ink / orange style as the account emails. Sent by an
  hourly job to verified, non-guest accounts that have not opted out; each
  step goes out at most once and only inside a 72-hour window after it comes
  due, so accounts older than the series never get a backlog. Every email
  carries `List-Unsubscribe` / `List-Unsubscribe-Post` headers and a footer
  link to the new public `GET|POST /email/unsubscribe?token=` endpoint (an
  HMAC over the user id, no session needed); the account screen has a "Tips
  by email" switch, exposed as `tips_emails_enabled` on `/auth/me`. Requires
  `PUBLIC_API_URL`; off otherwise, or with `ONBOARDING_EMAILS_ENABLED=false`.
  Migration 65.

- Outgoing mail shows a display name, "mitlist <noreply@mitlist.me>", set by
  `MAIL_FROM_NAME`.

- Branded verification and password reset emails: HTML in the app's paper /
  ink / orange style with a plain-text alternative, the code on a sticky note,
  and a button that opens the app (`/verify?token=`, `/reset-password?token=`).
  Both paths are new app routes and App Link / Universal Link paths; in a
  phone browser the landing page offers to hand over to the installed app.

### Changed

- Confirming a password reset signs the person in. `POST
  /auth/password-reset/confirm` now answers with a session (user, access and
  refresh token) instead of a message, and the app saves it and goes home
  rather than asking for the password that was just chosen. Older sessions
  are still revoked.

- Native In-App Purchase for premium on iOS and Android (App Store + Play
  Store), alongside the existing Polar web checkout. Purchases are verified
  server-side (Apple StoreKit 2 JWS chain to Apple Root CA - G3; Google Play
  Developer API), with App Store Server Notifications V2 and Play RTDN handled
  idempotently. Opt-in via `APPLE_IAP_*` / `GOOGLE_PLAY_*` config. Annual is +€2
  on mobile to cover the store cut; monthly unchanged. See
  `docs/iap-subscriptions-plan.md`.

### Fixed

- Polar checkout and webhooks work in production again. Every checkout had
  been refused since launch because all three Polar products were still
  *Draft* (Polar prices a draft normally, so the paywall rendered, then
  answers `POST /v1/checkouts/` with "Product is a draft."); they are now
  Private. The webhook secret can be pasted from the Polar dashboard
  verbatim: Polar signs with the UTF-8 bytes of the whole `whsec_…` string
  for secrets issued before 2026-09-08 and with a real Standard Webhooks key
  after, and the API now verifies under both, so the secret that crash-looped
  the API on 2026-08-21 (and was then unset, leaving every delivery answered
  503) no longer needs an encoding guessed for it. A draft-product refusal is
  logged with the fix, next to the existing messages for a token without
  `checkouts:write` and a rejected discount.
- Polar checkout no longer dies on an email Polar will not prefill. Polar
  validates `customer_email` down to whether the domain can receive mail,
  which is stricter than sign-up ever was, and answered 422 for such an
  account — the paywall then showed "Could not start checkout" with a bare
  500 behind it. The API now retries once without the prefill (the hosted
  page asks for an address; the external customer id still ties the purchase
  to the account) and logs the address it dropped. Same for the supporter
  pack.
- Coming back from a Polar checkout no longer strands you. Polar returns to
  `/you?customer_session_token=…`, a fresh page load of a screen that lives
  outside the tab shell, so there was neither a back button nor tabs. The
  account screen now shows a home button whenever there is nothing to go
  back to (the OAuth callback and bookmarks land the same way), drops the
  token from the address bar, and refetches billing so the supporter
  thank-you appears as soon as the webhook has landed.
- A new supporter on the default accent found every other colour still
  locked. The perks flag is only created when something first reads it, and
  with Clementine chosen the theme never does, so the accent picker created
  it long after `/billing/status` had answered — and its listener waited for
  the *next* answer. It now takes the current one too, and a stored value
  can no longer overwrite a fresh server answer that landed first.
- Any household member can edit, delete and re-zone a chore, not only an
  admin. `PATCH /chores/{id}`, `DELETE /chores/{id}` and a `PATCH
  /groups/{id}` that carries only `chore_zones` now need membership, in
  line with create; renaming a group, its description and currency stay
  admin-only. The detail sheet offered delete to everyone, so members saw
  "permission denied".
- Confirmation dialogs opened from a tab screen (delete chore, delete list,
  delete recipe, clear OCR data, and the rest) return their answer again.
  The dialog sits on the root navigator while its buttons popped the tab's
  own navigator, which threw away the tab's only page instead: a go_router
  assertion in debug and a null check in release, so nothing happened.
- Any household member can add a chore. `POST /chores` required the admin
  role while the app offered the button to everyone, so a member's create
  came back as "permission denied" (or, on older builds, sat as a phantom row
  that never got an assignee).
- Adding a zone from the chore sheet no longer throws when the dialog closes:
  the zone field's text controller was disposed while the keyboard was still
  flushing its final value into it.

## [1.0.0] - 2026-XX-XX

### Added

- Shared shopping lists with offline-first sync (outbox + Drift), item embeddings, and OCR scanner
- Meal planning and pinwall (framed cork board with real-time SSE presence and shared notes)
- Household calendar
- Expense splitting: equal, exact, percentage, and shares modes with settlement tracking
- Chore rotation: round-robin, fixed-assignee, and cron-scheduled chores with subtask support
- Multi-household support; users may belong to multiple households
- Multi-currency support with unified currency formatting
- Grocery intelligence pipeline: on-device OCR ensemble + household-specific item prior
- Five languages (i18n): English, German, French, Spanish, Dutch
- Backend crash reporting via Sentry/GlitchTip (opt-in, env-driven)
- Frontend crash reporting via sentry_flutter (opt-in)

### Changed

- Production docker-compose secured by default: database credentials are
  env-driven and its port is loopback-bound
- Backend integration availability (SMTP, Sentry) logged at startup via
  `LogIntegrationStatus`

### Fixed

- Offline banner correctly localizes conflict state
- Email status gated on credentials rather than defaulted SMTP host
- Pending offline items restored in original insertion order
