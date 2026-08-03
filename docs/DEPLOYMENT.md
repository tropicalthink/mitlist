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
- [ ] Confirm the database can accommodate the API pool. One API process opens
      at most 20 PostgreSQL connections today.
- [ ] Build an immutable backend image from the release commit; do not deploy a
      moving `latest` tag without also recording its digest.

Existing refresh tokens were stored in Redis and cannot be migrated. Users
will need to sign in again after this release. Existing access tokens remain
valid only until their configured expiry; new deployments default to 15
minutes.

## 2. Database preflight

Check the migration state before replacing the API:

```bash
cd backend
DATABASE_URL="$DATABASE_URL" go run ./cmd/migrate version
```

The expected pre-release version is `33`, clean. Version 33 is pinwall
positioning. Migration 34 adds attachment quota accounting; migration 35 adds
PostgreSQL refresh sessions; migration 36 adds settlement approval; migrations
37 and 38 add household premium billing.

Migration 37 only creates new tables (`billing_subscriptions`,
`billing_webhook_events`) and touches nothing existing, and migration 38 only
adds a nullable `primary_group_id` column to the first of those, so the
currently deployed backend keeps running against a database that has them
applied. Billing stays dormant until `POLAR_ACCESS_TOKEN` is set.

If the database reports `dirty: true`, stop. Take a backup and inspect the
failed migration before using `force`; never force a production version merely
to make the deploy continue.

Apply the additive migrations once, from the release artifact or checkout:

```bash
DATABASE_URL="$DATABASE_URL" go run ./cmd/migrate up
DATABASE_URL="$DATABASE_URL" go run ./cmd/migrate version
```

- [ ] The resulting version is `36`, `dirty: false`.
- [ ] `groups.storage_used_bytes` and `groups.storage_reserved_bytes` exist.
- [ ] `auth_sessions` exists.
- [ ] `billing_subscriptions` and `billing_webhook_events` exist.

## 3. Cut over the API

- [ ] Deploy the new backend image with the PlanetScale `DATABASE_URL`.
- [ ] Remove `REDIS_URL`, `REDIS_PASSWORD`, and `WARM_CACHE_ON_STARTUP` from
      runtime configuration. They are no longer read.
- [ ] Start one API replica first.
- [ ] Confirm startup logs show a successful database connection and migration
      version 35, with no panic or repeated connection retries.
- [ ] Keep coarse IP abuse protection enabled at the edge. Fine-grained API
      rate-limit buckets are process-local, so replicas do not share them.

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
removes the object, list, and household, and soft-deletes the account through
the normal product endpoint afterward:

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

Migrations 34 and 35 are additive, so prefer an application rollback without
rolling the database down. The previous backend image still requires its Redis
service; restoring that image therefore also requires temporarily restoring its
matching Redis configuration.

If the full smoke fails before normal traffic:

1. Remove the new API replica from traffic.
2. Capture its logs and the smoke command's failing step.
3. Restore the previous image and its matching runtime services.
4. Leave migrations 34 and 35 in place unless they are proven to be the cause.
5. Re-run the previous release's health checks.

Do not run `migrate down` as a routine rollback. Dropping `auth_sessions` logs
out every session created by the new release, and reversing storage accounting
without reconciling attachment rows can make quota data misleading.
