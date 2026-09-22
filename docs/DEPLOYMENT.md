# Production deployment checklist

This runbook covers the Redis-free Go API using replicated PostgreSQL and
S3-compatible attachment storage such as Cloudflare R2. Run commands from
the repository root unless a step says otherwise.

## 1. Before the maintenance window

- [ ] Record the currently deployed backend image tag and Git commit.
- [ ] Confirm both PostgreSQL replicas are healthy and a recent twice-daily backup can be read.
- [ ] Confirm the R2 bucket, lifecycle policy, and credentials are healthy.
- [ ] Confirm `DATABASE_URL` targets the intended PostgreSQL writer and keeps
      its required TLS parameters intact.
- [ ] Confirm `SECRET_KEY` and `SESSION_SECRET_KEY` are unchanged. Rotating
      either during this release would invalidate more sessions than intended.
- [ ] Confirm `MAX_STORAGE_PER_GROUP_GB=1` and
      `MAX_FILE_SIZE_BYTES=10485760` for official hosting.
- [ ] Confirm `FIREBASE_APP_CHECK_REQUIRED=true` for the official API and
      that `FIREBASE_PROJECT_NUMBER` identifies the same Firebase project used
      by the released mobile clients. The
      official service must reject missing or invalid App Check tokens.
- [ ] Confirm the database can accommodate the API pool. One API process opens
      at most 20 PostgreSQL connections today.
- [ ] Build an immutable backend image from the release commit; do not deploy a
      moving `latest` tag without also recording its digest.

Refresh sessions are PostgreSQL-backed. Keep `SECRET_KEY` and
`SESSION_SECRET_KEY` stable during a normal deploy so existing sessions remain
valid.

## 2. Database preflight

Check the migration state before replacing the API:

```bash
cd backend
DATABASE_URL="$DATABASE_URL" go run ./cmd/migrate version
```

The release artifact and database must agree on their migration head. This
checkout's head is `72`. Verify the filenames in `backend/migrations` before
every release rather than relying on an older image's recorded head.

If the database reports `dirty: true`, stop. Take a backup and inspect the
failed migration before using `force`; never force a production version merely
to make the deploy continue.

Apply the additive migrations once, from the release artifact or checkout:

```bash
DATABASE_URL="$DATABASE_URL" go run ./cmd/migrate up
DATABASE_URL="$DATABASE_URL" go run ./cmd/migrate version
```

- [ ] The resulting version is `72`, `dirty: false`.
- [ ] `groups.storage_used_bytes` and `groups.storage_reserved_bytes` exist.
- [ ] `auth_sessions` exists.
- [ ] `billing_subscriptions` and `billing_webhook_events` exist.
- [ ] `billing_subscriptions.primary_group_id` exists and is nullable.
- [ ] `request_idempotency` exists.
- [ ] `idx_notifications_scheduled_dedupe` exists.
- [ ] `users.guest_last_seen_at` and `users.guest_locked_at` exist.
- [ ] `idx_expenses_group_date`, `idx_recurring_expenses_group_next_due_active`,
      and `idx_pinwall_posts_group_remind_at` exist.

## 3. Cut over the API

- [ ] Deploy the new backend image with the production PostgreSQL `DATABASE_URL`.
- [ ] Remove `REDIS_URL`, `REDIS_PASSWORD`, and `WARM_CACHE_ON_STARTUP` from
      runtime configuration. They are no longer read.
- [ ] Start one API replica first.
- [ ] Confirm startup logs show a successful database connection and migration
      version 72, with no panic or repeated connection retries.
- [ ] Keep coarse IP abuse protection enabled at the edge. Fine-grained API
      rate-limit buckets are process-local, so replicas do not share them.

### Sign-in methods

The API offers three doors and reports which are open at
`GET /api/v1/oauth/providers`, so the app only shows what will work:

- **Google / Apple OAuth** — on whenever the provider's credentials are set.
  This is how the official service signs people in.
- **Email + password** — on only with `PASSWORD_AUTH_ENABLED=true`. It
  defaults to off because it exposes register, login, reset and
  change-password on the public API, and the hosted service has no need for
  it. A self-hosted instance without OAuth credentials needs it on;
  `backend/.env.example` ships with it set. Turning it off on a server that
  already has password accounts locks those people out until it is on again.
- **Guest** — on only with `GUEST_AUTH_ENABLED=true`, and then subject to
  the attestation below. It defaults to off because an unauthenticated
  endpoint that mints working accounts is the easiest thing on the API to
  abuse; the hosted service keeps it off. Turning it off never strands an
  existing guest: refresh, upgrade and provider linking stay open, only the
  creation of new guests is refused. The app reads the flag and hides the
  guest button when it is off.

  **Upgrading an existing deployment:** guests used to be always on, and the
  flag is read from the stack's environment with no fallback. A stack that
  never set `GUEST_AUTH_ENABLED` therefore stops offering guest sign-up the
  moment it runs this version. If that is not what you want, add
  `GUEST_AUTH_ENABLED=true` to the stack secrets alongside `MITLIST_TAG`
  before, or together with, the image bump; the hosted anansi stack does not
  set it on purpose.

```dotenv
PASSWORD_AUTH_ENABLED=true
GUEST_AUTH_ENABLED=false
```

The API logs a warning at startup when neither OAuth nor passwords are
configured: with guests on, accounts can still be created but nobody can sign
back in on a second device; with guests off as well, nobody can get in at
all.

### Sign-up attestation

Two unauthenticated routes take public input: guest creation and the landing
page's testing signup. They are handled in different places:

- **Mobile guest creation** presents a Firebase App Check token (Play Integrity
  / App Attest).
- **Web guest creation** presents a Cloudflare Turnstile token. App Check's
  only web provider is reCAPTCHA Enterprise, which would add a GCP billing
  dependency to protect one endpoint, so the browser solves an invisible
  Turnstile challenge instead.
- **Testing signups** never reach this API. The landing page posts straight to
  Staffroom (reqtrack) at
  `/api/v1/public/apps/<slug>/testers`, which verifies its own Turnstile token
  with the per-app secret in the `TURNSTILE_SECRETS` Wrangler secret. See
  Staffroom's `apps/api` docs.

The API accepts either guest proof, and rejects a caller that presents neither
while the relevant check is enforced. Turnstile needs one runtime variable:

```dotenv
TURNSTILE_SECRET_KEY=0x...
```

Leave it unset and web guests are unattested — the correct default for a
self-hosted instance, and not acceptable for the official service.

#### App Check enforcement (mobile)

The official hosted service runs with Firebase App Check required. Configure
the API runtime before admitting traffic:

```dotenv
ENVIRONMENT=production
FIREBASE_PROJECT_ID=your-firebase-project
FIREBASE_PROJECT_NUMBER=123456789012
FIREBASE_APP_CHECK_REQUIRED=true
FIREBASE_APP_CHECK_ALLOWED_APP_IDS=1:...:android:...,1:...:ios:...
# Required separately only when FCM push is enabled:
FIREBASE_SERVICE_ACCOUNT_JSON={...}
```

The Firebase project must contain the exact Android (`me.mitlist`) and iOS
(`me.mitlist`) apps shipped by the beta/production workflows. Android release
builds use Play Integrity, iOS release builds use App Attest, and the
web app is not registered with an App Check provider at all — it uses
Turnstile, above. Do not put a
Firebase App Check debug token in a production secret or artifact. If the
project number, or required flag is absent, stop the cutover — a
hosted API must not silently accept unauthenticated mobile traffic.
For the official service, populate `FIREBASE_APP_CHECK_ALLOWED_APP_IDS` with
the exact Android and iOS App IDs from Firebase Console; the web App ID no
longer belongs there, because web builds ship no App Check provider. The API refuses
to start with App Check required and an empty allowlist.

Self-hosted instances are intentionally opt-in: `FIREBASE_APP_CHECK_REQUIRED`
defaults to `false` in `backend/.env.example`. Operators enabling it must use
their own Firebase project and register their own application IDs; they should
build a matching client with `--dart-define=APP_CHECK_ENABLED=true`. The
client half of every such setting — App Check, Turnstile, crash reporting, the
feature board — is listed in [build-configuration.md](build-configuration.md);
the variables on this page are the API's runtime environment and are a
separate set.

The production Compose profile accepts a complete `DATABASE_URL` from the root
`.env`. When it is present, it overrides the bundled Postgres URL:

```dotenv
DATABASE_URL=postgresql://...planet-scale-url-with-tls-parameters...
```

## 4. Verify before normal traffic

Run the read-only probe first:

```bash
cd backend
go run ./cmd/smoke -base-url https://your-api.example.com
```

Then run the disposable full journey. This performs one real tiny object upload,
removes the object, list, and household, and deletes/anonymizes the account
through the normal product endpoint afterward:

```bash
go run ./cmd/smoke \
  -base-url https://your-api.example.com \
  -mode full \
  -allow-writes
```

- [ ] `/healthz` and `/readyz` return 200.
- [ ] Refresh rotation and logout revocation pass.
- [ ] The list write passes.
- [ ] Quota reservation, upload finalization, deletion, and byte release pass.
- [ ] The command ends with `resources cleaned up`.
- [ ] Error monitoring shows no new backend failures.
- [ ] PostgreSQL connection use and replication lag remain within the operating thresholds.

Only after these checks pass should additional API replicas receive traffic.

## 5. Remove the old Redis service

- [ ] Stop the old Redis container/service.
- [ ] Confirm the new API remains ready after Redis is stopped.
- [ ] Remove Redis from infrastructure monitoring and backup jobs.
- [ ] After the acceptance window, delete the obsolete Redis volume and secret.

The application, tests, CI, and Compose stack no longer require Redis.

## Rollback

Prefer an application rollback without rolling the database down. Before
rollback, verify that the previous image tolerates schema version 72; migrations
40, 45, and 47 include destructive security cleanup and cannot be reversed into
the deleted credentials or duplicate device ownership records.

If the full smoke fails before normal traffic:

1. Remove the new API replica from traffic.
2. Capture its logs and the smoke command's failing step.
3. Restore the previous image and its matching runtime services.
4. Leave migrations in place unless a tested rollback procedure proves one is
   the cause and its down migration is data-safe.
5. Re-run the previous release's health checks.

Do not run `migrate down` as a routine rollback. Dropping `auth_sessions` logs
out every session created by the new release; dropping idempotency state can
allow queued mutations to execute twice; reversing storage accounting without
reconciling attachment rows can make quota data misleading.
