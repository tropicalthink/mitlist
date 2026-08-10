# mitlist — Backend

Go API server for shared household coordination (lists, money, chores, recipes).

## Tech Stack

- **Router**: chi (Go)
- **Database**: PostgreSQL 16 (via pgx)
- **Sessions**: PostgreSQL-backed refresh-token sessions
- **Storage**: S3-compatible (Cloudflare R2)
- **Auth**: JWT (access + refresh tokens), OAuth (Google, Apple)
- **Push**: Web push (VAPID)
- **Scanner**: on-device ML Kit OCR in the Flutter app
- **Jobs**: robfig/cron (chore scheduler, reminders, summaries)

Refresh-token rotation and revocation are durable in PostgreSQL. Access-token
revocation and API rate-limit buckets are intentionally process-local; access
tokens therefore default to 15 minutes, and multi-replica deployments should
enforce coarse abuse limits at their edge proxy as well.

## Setup

```bash
cd backend

# Start dependencies
docker compose up -d

# Copy and edit config
cp .env.example .env

# Run migrations
go run ./cmd/migrate up

# Start server
go run ./cmd/api
```

## Configuration

All config via environment variables (see `.env.example`):

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | Yes | — | PostgreSQL connection string |
| `SECRET_KEY` | Yes | — | Token signing key |
| `S3_BUCKET_NAME` | No | — | R2 bucket for attachments |
| `S3_ENDPOINT_URL` | No | — | R2 S3 endpoint |
| `MAX_FILE_SIZE_BYTES` | No | `10485760` | Maximum attachment size (10 MiB) |
| `MAX_STORAGE_PER_GROUP_GB` | No | `1` | Storage quota per household; `0` disables it for self-hosters |
| `GLITCHTIP_DSN` | No | — | Error reporting DSN |

### Production credentials (docker compose --profile prod)

The prod compose profile reads these variables via docker compose `${...}`
interpolation, which is sourced from the **root `.env`** (next to
`docker-compose.yml`) or your shell — **not** from `backend/.env`. A
service-level `env_file:` only populates the container's environment; it does
not feed compose interpolation. Copy the root example and set them there:

```bash
cp .env.example .env   # at the PROJECT ROOT, not backend/
```

These have **no insecure fallback** — the stack refuses to start if
`POSTGRES_USER` / `POSTGRES_PASSWORD` are unset.

| Variable | Required | Notes |
|----------|----------|-------|
| `POSTGRES_USER` | Yes | DB user for the bundled Postgres |
| `POSTGRES_PASSWORD` | Yes | Generate with `openssl rand -base64 24` |
| `POSTGRES_DB` | No | Defaults to `mitlist` |
| `DB_SSLMODE` | No | Defaults to `disable` (correct for same-host Postgres); set `require` if pointing at a remote Postgres over the public network |

`backend/.env` remains the app's own runtime config (`SECRET_KEY`,
`SESSION_SECRET_KEY`, OAuth, API keys). In the bundled prod profile,
`DATABASE_URL` is assembled by compose from the root `.env`, so you do not set
it in `backend/.env` for that path.

The `dev` profile (`docker compose up`, no profile flag) uses the convenience
defaults shipped in the root `.env.example` (`mitlist:mitlist`) — intentional
for local development.

### PlanetScale Postgres

The hosted service can use PlanetScale Postgres without a database-specific
code path. Create a Postgres database, copy its connection string into the
backend's `DATABASE_URL` (the root `.env` for the prod Compose profile), and
keep the TLS parameters supplied by PlanetScale. The Go API uses pgx and runs
the existing PostgreSQL migrations normally.

For this deployment, run only the API service; do not start the bundled
Postgres container. Keep `RUN_MIGRATIONS_ON_STARTUP=true` for the first
deployment, then verify `/healthz` and `/readyz` before directing app traffic to
the server.
PlanetScale's managed backups cover the database; attachment objects remain in
R2 and need their own lifecycle/retention policy.

## Enable error reporting (optional)

Error reporting is **off by default**. Enable it only if you want crash visibility.
A self-hosted [GlitchTip](https://glitchtip.com) instance is the privacy-preserving
option — it keeps crash data on your own infra, consistent with mitlist's self-host ethos.

### Backend

Set `SENTRY_DSN` in `backend/.env` (or the container's runtime env) to a
Sentry-compatible project DSN. No rebuild is required — this is a runtime variable
only.

```
SENTRY_DSN=https://<key>@<your-glitchtip-host>/<project-id>
```

### Web / PWA

The web build bakes the DSN in at compile time via a dart-define. To enable it:

- **CI (Gitea Actions):** create a CI secret named `GLITCHTIP_DSN_WEB` pointing at
  your GlitchTip/Sentry web project DSN. The deploy workflow reads it automatically.
- **Manual build:** pass it as a build-arg to the Docker build:
  ```bash
  docker build --build-arg GLITCHTIP_DSN=<your-dsn> --build-arg ENVIRONMENT=production \
    -f frontend/Dockerfile.prod ./frontend
  ```

The client DSN is designed to be public (it only allows event ingestion), so baking
it into the web bundle is expected and safe.

### Mobile apps (Android / iOS)

The mobile apps use the **same** dart-define. Build with the DSN passed directly:

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-api-host \
  --dart-define=GLITCHTIP_DSN=<your-dsn> \
  --dart-define=ENVIRONMENT=production
```

(Likewise `flutter build apk` / `flutter build ipa`.) Mobile CI builds are manual
today; when the mobile CI job lands (plan 014) it must pass the same
`--dart-define=GLITCHTIP_DSN` and `--dart-define=ENVIRONMENT`. You may reuse the
web DSN or use a separate GlitchTip/Sentry project per platform.

An empty `GLITCHTIP_DSN` (the default when the secret/build-arg is unset) keeps
reporting off — the app falls back to running without Sentry.

## API

All routes under `/api/v1/`, registered in `cmd/api/main.go`.

### Key Endpoints

| Method | Route | Description |
|--------|-------|-------------|
| `POST /auth/register` | Register | Create account |
| `POST /auth/login` | Login | Get JWT tokens |
| `POST /auth/refresh` | Refresh | Rotate tokens |
| `GET /groups` | List groups | User's households |
| `POST /groups` | Create group | New household |
| `GET /chores/current` | Current chores | Due assignments |
| `GET /finance/summary` | Finance summary | Balances + reimbursements |
| `GET /calendar` | Calendar | Aggregated events |
| `GET /pinwall/posts` | Pinwall posts | Household notes |
| `GET /expenses/{id}/splits` | Expense splits | Per-user breakdown |
| `GET /attachments/storage-usage` | Storage usage | Household quota and remaining bytes |

### Aggregated Calendar (`GET /calendar`)

Returns events from 4 sources:
- `meal_plan` — Meal plans with recipe title
- `chore` — Chore assignments with due dates
- `recurring_expense` — Recurring expense due dates
- `expense` — One-time expense dates via `ListExpensesByDateRange`
- `pinwall_reminder` — Pinwall posts with `remind_at` set

## Testing

```bash
go build ./...                      # Compile
go test ./...                       # All tests
go test ./internal/services/        # Service-layer tests
go test ./internal/api/handlers/    # Handler integration tests
```

### Deployed API smoke test

The smoke command defaults to safe, read-only health checks:

```bash
go run ./cmd/smoke -base-url https://api.example.com
```

Full mode creates a unique disposable account and household, then verifies
register/login/refresh/logout, a list write, an actual object upload, storage
quota reservation/finalization/release, and cleanup. Writes require an explicit
second flag to prevent accidental production mutations:

```bash
go run ./cmd/smoke \
  -base-url https://api.example.com \
  -mode full \
  -allow-writes
```

Set `MITLIST_SMOKE_BASE_URL` instead of `-base-url` when running it from CI.
Use `-email-domain your-domain.example` if the production email validator or
provider rejects the default `example.invalid` domain. The command never prints
the generated password or tokens and attempts cleanup if a step fails. Account
cleanup uses the product's normal soft-delete endpoint.

### Test Status

| Package | Status | Notes |
|---------|--------|-------|
| `internal/services` | ✅ Pass | Service logic tests |
| `internal/db` | ✅ Pass | Database utilities |
| `internal/middleware` | ✅ Pass | Auth/CORS/logging |
| `pkg/validation` | ✅ Pass | Validation utilities |
| `internal/api/handlers` | ✅ Pass | HTTP handler integration tests |
| `internal/repositories` | ✅ Pass | Repository tests |
| `internal/jobs` | ✅ Pass | Scheduled job tests |

## Project Layout

```
cmd/api/main.go              # Entry point, route registration
internal/
  api/handlers/              # HTTP handlers
  config/config.go           # Environment config
  container/container.go     # DI container
  db/                        # Connection pool + migrations
  jobs/                      # Cron jobs
  middleware/                # Auth, CORS, logging, rate limiting
  models/                    # Data structs
  repositories/              # PostgreSQL queries
    mocks/                   # Test mocks (testify)
  server/                    # HTTP server setup
  services/                  # Business logic
    jwt/                     # JWT token service
    password/                # bcrypt hashing
    mail/                    # SMTP email
    push/                    # Web push (VAPID)
    storage/                 # S3/R2 object storage
    oauth/                   # Google/Apple OAuth
    image/                   # Image resizing
migrations/                  # golang-migrate SQL
```
