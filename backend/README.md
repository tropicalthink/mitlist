# mitlist — Backend

Go API server for shared household coordination (lists, money, chores, recipes).

## Tech Stack

- **Router**: chi (Go)
- **Database**: PostgreSQL 16 (via pgx)
- **Cache**: Redis 7 (session revocation, rate limiting)
- **Storage**: S3-compatible (Cloudflare R2)
- **Auth**: JWT (access + refresh tokens), OAuth (Google, Apple)
- **Push**: Web push (VAPID)
- **AI**: CrofAI (OpenAI-compatible, vision OCR)
- **Jobs**: robfig/cron (chore scheduler, reminders, summaries)

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
| `REDIS_URL` | No | `localhost:6379` | Redis address |
| `JWT_SECRET` | Yes | — | Token signing key |
| `CROFAI_API_KEY` | No | — | AI vision API key |
| `S3_BUCKET_NAME` | No | — | R2 bucket for attachments |
| `S3_ENDPOINT_URL` | No | — | R2 S3 endpoint |
| `GLITCHTIP_DSN` | No | — | Error reporting DSN |

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
| `POST /assistant/scan` | OCR scan | Process receipt/list photo |

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
go test ./...                       # All tests (some pre-existing failures)
go test ./internal/services/        # Service-layer tests
go test ./internal/api/handlers/    # Handler integration tests
```

### Test Status

| Package | Status | Notes |
|---------|--------|-------|
| `internal/services` | ✅ Pass | Service logic tests |
| `internal/db` | ✅ Pass | Database utilities |
| `internal/middleware` | ✅ Pass | Auth/CORS/logging |
| `pkg/validation` | ✅ Pass | Validation utilities |
| `internal/api/handlers` | ❌ Build failure | Pre-existing (stale mocks/test conflicts) |
| `internal/repositories` | ❌ Fails | Pre-existing (arg count mismatch) |
| `internal/jobs` | ❌ Fails | Pre-existing (assertion failures) |

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
  redis/                     # Redis client
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
    ai/                      # CrofAI vision client
    image/                   # Image resizing
migrations/                  # golang-migrate SQL
```
