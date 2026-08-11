# Privacy Statement

**mitlist** is open-source software that can be used on the official hosted service or on an independently operated server. This document describes what the software handles in both cases.

---

## Where your data lives

Household data — shopping lists, expenses, chores, meal plans, recipes, photos, and account information — is stored by the operator of the server selected in the app. The official service uses managed PostgreSQL and S3-compatible object storage; a self-hoster chooses their own database and storage.

The mitlist project receives hosted household data only when someone chooses the official service. It receives no household content, analytics, or telemetry from an independently self-hosted instance.

---

## No first-party telemetry by default

mitlist does not collect usage analytics, behavioral data, or any form of "phone home" telemetry. This is true by default and requires no configuration to preserve.

---

## Optional, operator-controlled crash reporting

An operator may enable error reporting to help diagnose crashes. This is **opt-in and off unless explicitly configured**:

- **Backend**: set the `SENTRY_DSN` environment variable. If unset (the default), no error reports are sent.
- **Web/Flutter client**: supply a `GLITCHTIP_DSN` build-time define (`--dart-define=GLITCHTIP_DSN=...`). If unset (the default), no error reports are sent.

When enabled, crash reports contain stack traces and basic context (OS version, app version, environment label). They do **not** contain household content (list items, expenses, names, or any user-generated data) by design — the Sentry SDK is configured with `tracesSampleRate = 0.0` and no PII capture.

Reports are sent to whatever endpoint the operator configures in the DSN. We recommend pointing this at a **self-hosted GlitchTip** instance so crash data stays on the operator's own infrastructure and is not sent to a third party.

## Official-service abuse prevention (Firebase App Check)

The official mobile builds use Firebase App Check to attest that requests come
from an unmodified mitlist app: Play Integrity on Android and App Attest on
iOS. The official API verifies the attestation and rejects missing or invalid
tokens. This is an abuse-prevention signal, not analytics, advertising, or a
household-content feed. Firebase/Google and Apple may receive device/app
integrity signals needed to issue the attestation token; mitlist receives only
the verification result and does not use it to build a user profile.

App Check is an attestation signal, not a persistent unique-device
fingerprint. Tokens rotate; the service combines verified app attestation with
an app-generated installation identifier used only
for short-lived abuse quotas; the service does not turn that value into a
cross-service identity or advertising profile.

App Check is disabled by default for independently self-hosted deployments.
A self-hoster who opts in is responsible for configuring their own Firebase
project, reviewing that provider's privacy terms, and disclosing it to their
users. Debug App Check providers and debug tokens are never appropriate for a
released official artifact.

---

## Account controls

- **Guest mode** — you can use mitlist without providing an email address.
- **Data export** — download your expenses as CSV or JSON at any time from within the app.
- **Account deletion** — deleting your account revokes every session, removes
  credentials and personal profile data, and anonymizes authorship that must
  remain in shared household history. Export first if you want a copy.

---

## Third-party services the operator may configure

Each of the following is optional and disabled unless the operator provides credentials. When enabled, data is sent to that provider only for the specific function described. The operator supplies their own credentials and is responsible for that provider's terms.

| Service | Purpose | Configured via |
|---------|---------|----------------|
| Resend | Transactional email | `RESEND_API_KEY` |
| PlanetScale | Managed PostgreSQL for the official service | `DATABASE_URL` |
| SendGrid / Brevo SMTP | Transactional email (SMTP fallback) | `SENDGRID_SMTP_*` / `BREVO_SMTP_*` |
| Firebase / FCM | Mobile push notifications | `FIREBASE_PROJECT_ID` + `FIREBASE_SERVICE_ACCOUNT_JSON` |
| Firebase App Check | Mobile app/device attestation for official-service abuse prevention | `FIREBASE_APP_CHECK_REQUIRED=true` + `FIREBASE_PROJECT_NUMBER` + Firebase project credentials |
| Web Push (VAPID) | Browser push notifications | `VAPID_PRIVATE_KEY` + `VAPID_PUBLIC_KEY` |
| AWS S3 / Cloudflare R2 | File and photo storage | `AWS_ACCESS_KEY_ID` + `S3_BUCKET_NAME` |
| FX rate feed | Live exchange rates for expenses | `FX_RATE_API_URL` |

These integrations are disabled in a default self-hosted deployment unless its operator configures them. The official service publishes its active infrastructure on the transparency page.

---

## Who is the data controller

For the official service, the provider named in the landing site's Impressum is the data controller. For an independently self-hosted instance, its operator is the controller and is responsible for the people using it.

---

## Contact

For the official service, email `hi@tropicalthink.com`. For another deployment, contact its operator. Software issues can be filed in the public repository.
