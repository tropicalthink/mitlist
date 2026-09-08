# Privacy

This file mirrors the privacy policy of the **official hosted mitlist service**
published at <https://mitlist.me/privacy> (English) and
<https://mitlist.me/datenschutz> (German, the binding version). It is kept here
so that people reading the source can see what the software does with data.
When a provider, a feature, or a retention period changes, update all three.

Last updated: 6 September 2026.

## Two situations

mitlist is free software (AGPL-3.0) that runs either on the official hosted
service or on a server somebody operates themselves.

- **Official service** (`app.mitlist.me`, `api.mitlist.me`, the store apps):
  the provider named in the [Impressum](https://mitlist.me/impressum) is the
  data controller. Everything below describes this deployment.
- **Self-hosted instance**: its operator is the controller. The mitlist
  project receives no household data, usage data, or crash reports from such
  an instance. Every outbound integration is off until the operator configures
  it; see the table at the end.

## Principles

- No ads, no selling of data.
- The apps and the web app carry no analytics or advertising trackers and
  build no usage profiles. The marketing site at `mitlist.me` uses cookieless
  Cloudflare Web Analytics for aggregated page counts; the app does not.
- Household data lives on a server we run in the European Union.
- Export and account deletion are available in the app at any time.
- Only what is needed to run the service, bill Premium, and keep it secure is
  processed.

## What the official service processes

| Area | Data | Notes |
|------|------|-------|
| Account | Email, chosen name, password hash; or the email, name, and account id from Google / Apple sign-in | Guest accounts have no email, are device-bound, are locked after 30 days of inactivity and anonymised after another 180 days |
| Sessions | Access and refresh token stored on the device / in browser storage | Invalidated on sign-out or password change |
| Household content | Lists, chores, expenses and settlements, recipes, meal plans, pinwall notes, calendar, invitations, uploaded photos and receipts, plus timestamps and authorship | Visible to every member of the household. 1 GB per household, 10 MB per file, stored in Cloudflare R2 |
| Scanner | Nothing leaves the device | Text recognition runs on-device; no AI service is called |
| Recipe import | The URL you paste is fetched by the server | The recipe site sees the server's address, not yours |
| Push | Device token (FCM / APNs / Web Push) and the notification text | Optional; token deleted on sign-out |
| Email | Address and message content, sent via Amazon SES (EU, Frankfurt) | Confirmation, password reset, invitations, optional weekly summary, and up to five getting-started tips in the first month after sign-up. The tips can be turned off in the app (You → Tips by email) or with the unsubscribe link in each one. No third-party marketing, no mailing list |
| Premium | Subscription holder, assigned household, term, status, amount paid | Web payments through Polar (merchant of record), in-app through Apple / Google. Billing records kept up to ten years by law |
| Security | IP address and connection data at Cloudflare; Turnstile result for guest sign-up on the web; Firebase App Check attestation for the mobile apps; server logs of failed sign-ins | Logs deleted after a short period |
| Crash reports | Stack trace, app / OS version, device type, environment, sent to a self-run GlitchTip instance | No household content, names, or emails; no performance or usage data |
| Feedback | Text, source screen, app version, platform, locale; on the public board also your account id and first name | Stored in the request tracker on Cloudflare Workers / D1 |

## Retention and deletion

Mobile testing signups store the email, Android/iOS selection, signup time,
and consent version privately, solely to arrange access and send testing
emails. They do not create an app account or public board post. The team may
add the email to Google Play testing or Apple TestFlight to issue invitations.
Signups are removed when testing ends or consent is withdrawn; contact the
operator listed in the Impressum from the registered address to withdraw or
request deletion.

- Account and household content stay as long as the account exists.
- **Deleting the account** in the app removes email, name, password, and
  avatar immediately, ends every session, and anonymises the account. Content
  added to a shared household stays there for the other members, no longer
  linked to the deleted account. Delete it or the household first if you do not
  want that.
- Deleting a household deletes its content.
- Guest accounts: locked after 30 days idle, anonymised after another 180 days.
- Billing records: statutory periods, up to ten years.
- Push tokens: deleted on sign-out. Logs and crash reports: after a short period.
- Backups are encrypted and overwritten after a limited period.
- Expenses can be exported as CSV or JSON from the app at any time; other data
  on request.

## Recipients and transfers

| Recipient | Purpose | Location / basis |
|-----------|---------|------------------|
| Server provider (Heerlen, NL) | Web app, API, PostgreSQL | EU |
| Cloudflare, Inc. | Website, network and protection, Turnstile, R2, feedback tracker (Workers, D1) | USA; SCCs, EU-US Data Privacy Framework |
| Google Ireland Ltd. (Firebase) | Push, App Check, Sign in with Google | Ireland; onward to Google LLC under the DPF and SCCs |
| Apple Distribution International Ltd. | Sign in with Apple, push on iOS, in-app purchase | Ireland; onward to Apple Inc. under the DPF |
| Amazon Web Services EMEA SARL | Transactional email (Amazon SES) | EU (Frankfurt); Luxembourg contracting entity |
| Polar Software Inc. | Premium payments on the web (merchant of record) | USA; independent controller |
| Google Play / Apple App Store | App distribution, in-app purchase | Store privacy policies |

## Age

The official service is for people aged 16 and over; younger people need a
parent's or guardian's consent.

## Your rights

Access, rectification, erasure, restriction, portability, objection, and
withdrawal of consent (Art. 15-21 and 7(3) GDPR). Email
<hi@tropicalthink.com>, or delete the account in the app. Complaints go to the
Hessian Commissioner for Data Protection and Freedom of Information
(<https://datenschutz.hessen.de>) or the authority where you live.

## Operator-controlled integrations (self-hosting reference)

Each of these is disabled in a default deployment until the operator provides
credentials. When enabled, data goes to that provider only for the function
described, and the operator is responsible for that provider's terms.

| Service | Purpose | Configured via |
|---------|---------|----------------|
| Amazon SES / SMTP | Transactional email | `AWS_SES_REGION` (+ `AWS_SES_ACCESS_KEY_ID`/`AWS_SES_SECRET_ACCESS_KEY`) or SMTP settings |
| Google / Apple OAuth | Sign in with Google / Apple | `GOOGLE_CLIENT_ID` + secret, `APPLE_*` |
| Firebase / FCM | Mobile push notifications | `FIREBASE_PROJECT_ID` + `FIREBASE_SERVICE_ACCOUNT_JSON` |
| Firebase App Check | Mobile app attestation | `FIREBASE_APP_CHECK_REQUIRED` + `FIREBASE_PROJECT_NUMBER` |
| Cloudflare Turnstile | Web guest sign-up abuse prevention | `TURNSTILE_SECRET_KEY` (+ `TURNSTILE_SITE_KEY` in the web build) |
| Web Push (VAPID) | Browser push notifications | `VAPID_PRIVATE_KEY` + `VAPID_PUBLIC_KEY` |
| S3 / Cloudflare R2 | File and photo storage | `AWS_ACCESS_KEY_ID` + `S3_BUCKET_NAME` + `S3_ENDPOINT_URL` |
| Polar | Premium subscriptions on the web | `POLAR_ACCESS_TOKEN` (+ product ids) |
| Apple / Google IAP | Premium subscriptions in the store apps | `APPLE_IAP_*`, `GOOGLE_PLAY_*` |
| Sentry / GlitchTip | Crash reports (backend) | `SENTRY_DSN` |
| Sentry / GlitchTip | Crash reports (web / apps) | `GLITCHTIP_DSN` build-time define |
| FlareSolverr | Recipe import from sites that block data-centre IPs | `SCRAPER_FLARESOLVER_URL` |
| FX rate feed | Live exchange rates for expenses | `FX_RATE_API_URL` |
| reqtrack | In-app feedback and feature board | `REQTRACK_APP_KEY` + `REQTRACK_URL` build-time defines |

Crash reporting is worth calling out: the SDK is configured with
`tracesSampleRate = 0.0` and no PII capture, so reports carry stack traces and
basic context but no household content by design. Point the DSN at a
self-hosted GlitchTip to keep crash data on your own infrastructure.
