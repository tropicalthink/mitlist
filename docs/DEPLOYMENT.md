# Production deployment checklist

This runbook covers the Redis-free Go API using managed PlanetScale Postgres
and S3-compatible attachment storage such as Cloudflare R2. Run commands from
the repository root unless a step says otherwise.

## 1. Before the maintenance window

- [ ] Record the currently deployed backend image tag and Git commit.
- [ ] Confirm a recent PlanetScale backup or restore point exists.
- [ ] Confirm the R2 bucket, lifecycle policy, and credentials are healthy.
- [ ] Confirm `DATABASE_URL` is the PlanetScale Postgres URL with its supplied
      TLS parameters intact.
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
checkout's head is `54`. Migrations 39–47 harden authentication and push-device
ownership; 48–51 add reminder delivery state, notification group scoping and
list notification batching; 52 adds authenticated request replay protection;
53 deduplicates scheduled notification retries; 54 adds recoverable guest
account locking and retirement timestamps.

If the database reports `dirty: true`, stop. Take a backup and inspect the
failed migration before using `force`; never force a production version merely
to make the deploy continue.

Apply the additive migrations once, from the release artifact or checkout:

```bash
DATABASE_URL="$DATABASE_URL" go run ./cmd/migrate up
DATABASE_URL="$DATABASE_URL" go run ./cmd/migrate version
```

- [ ] The resulting version is `54`, `dirty: false`.
- [ ] `groups.storage_used_bytes` and `groups.storage_reserved_bytes` exist.
- [ ] `auth_sessions` exists.
- [ ] `billing_subscriptions` and `billing_webhook_events` exist.
- [ ] `billing_subscriptions.primary_group_id` exists and is nullable.
- [ ] `request_idempotency` exists.
- [ ] `idx_notifications_scheduled_dedupe` exists.
- [ ] `users.guest_last_seen_at` and `users.guest_locked_at` exist.

## 3. Cut over the API

- [ ] Deploy the new backend image with the PlanetScale `DATABASE_URL`.
- [ ] Remove `REDIS_URL`, `REDIS_PASSWORD`, and `WARM_CACHE_ON_STARTUP` from
      runtime configuration. They are no longer read.
- [ ] Start one API replica first.
- [ ] Confirm startup logs show a successful database connection and migration
      version 54, with no panic or repeated connection retries.
- [ ] Keep coarse IP abuse protection enabled at the edge. Fine-grained API
      rate-limit buckets are process-local, so replicas do not share them.

### App Check enforcement

The official hosted service runs with Firebase App Check required. Configure
the API runtime before admitting traffic:

```dotenv
ENVIRONMENT=production
FIREBASE_PROJECT_ID=your-firebase-project
FIREBASE_PROJECT_NUMBER=123456789012
FIREBASE_APP_CHECK_REQUIRED=true
FIREBASE_APP_CHECK_ALLOWED_APP_IDS=1:...:android:...,1:...:ios:...,1:...:web:...
# Required separately only when FCM push is enabled:
FIREBASE_SERVICE_ACCOUNT_JSON={...}
```

The Firebase project must contain the exact Android (`me.mitlist`) and iOS
(`me.mitlist`) apps shipped by the beta/production workflows. Android release
builds use Play Integrity, iOS release builds use App Attest, and the
production web app must be registered with the reCAPTCHA provider and its
generated web app ID. Do not put a
Firebase App Check debug token in a production secret or artifact. If the
project number, or required flag is absent, stop the cutover — a
hosted API must not silently accept unauthenticated mobile traffic.
For the official service, populate `FIREBASE_APP_CHECK_ALLOWED_APP_IDS` with
the exact Android, iOS, and web App IDs from Firebase Console. The API refuses
to start with App Check required and an empty allowlist.

Self-hosted instances are intentionally opt-in: `FIREBASE_APP_CHECK_REQUIRED`
defaults to `false` in `backend/.env.example`. Operators enabling it must use
their own Firebase project and register their own application IDs; they should
build a matching client with `--dart-define=APP_CHECK_ENABLED=true`.

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
- [ ] PlanetScale connection use remains below the plan limit.

Only after these checks pass should additional API replicas receive traffic.

## 5. Remove the old Redis service

- [ ] Stop the old Redis container/service.
- [ ] Confirm the new API remains ready after Redis is stopped.
- [ ] Remove Redis from infrastructure monitoring and backup jobs.
- [ ] After the acceptance window, delete the obsolete Redis volume and secret.

The application, tests, CI, and Compose stack no longer require Redis.

## Rollback

Prefer an application rollback without rolling the database down. Before
rollback, verify that the previous image tolerates schema version 54; migrations
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
