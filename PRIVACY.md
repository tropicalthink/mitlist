# Privacy Statement

**mitlist** is self-hosted, open-source software. This document describes what data the software handles, where it goes, and what controls exist — written for operators who deploy an instance and for the people who use it.

---

## Where your data lives

All household data — shopping lists, expenses, chores, meal plans, recipes, photos, and account information — is stored on the **operator's own server** (a self-hosted PostgreSQL database and optional S3-compatible object storage).

The project authors (the mitlist contributors) operate no central service. They receive no user data, no analytics, and no telemetry from any self-hosted instance. The only network connections the app makes are to the URL the operator configures.

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

---

## Account controls

- **Guest mode** — you can use mitlist without providing an email address.
- **Data export** — download your expenses as CSV or JSON at any time from within the app.
- **Account deletion** — deleting your account removes your data from the operator's server. Export first if you want a copy.

---

## Third-party services the operator may configure

Each of the following is optional and disabled unless the operator provides credentials. When enabled, data is sent to that provider only for the specific function described. The operator supplies their own credentials and is responsible for that provider's terms.

| Service | Purpose | Configured via |
|---------|---------|----------------|
| CrofAI / OpenRouter | OCR for receipt scanning | `OPENROUTER_API_KEY` |
| Resend | Transactional email | `RESEND_API_KEY` |
| SendGrid / Brevo SMTP | Transactional email (SMTP fallback) | `SENDGRID_SMTP_*` / `BREVO_SMTP_*` |
| Firebase / FCM | Mobile push notifications | `FIREBASE_PROJECT_ID` + `FIREBASE_SERVICE_ACCOUNT_JSON` |
| Web Push (VAPID) | Browser push notifications | `VAPID_PRIVATE_KEY` + `VAPID_PUBLIC_KEY` |
| AWS S3 / Cloudflare R2 | File and photo storage | `AWS_ACCESS_KEY_ID` + `S3_BUCKET_NAME` |
| FX rate feed | Live exchange rates for expenses | `FX_RATE_API_URL` |

None of these services are enabled in a default deployment.

---

## Who is the data controller

For a self-hosted instance, **the operator is the data controller**. The people who use that instance are the operator's responsibility. The mitlist project provides the software; it has no visibility into, or control over, data stored on any self-hosted instance.

---

## Contact

For questions about a specific deployment, contact the operator of that instance. For questions about the software itself, open an issue at the project repository.
