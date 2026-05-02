# mitlist — Agent Reference

## Project Overview
Shared household coordination app (lists, money, chores, recipes). Flutter frontend + Go backend.

## Repository Layout

```
frontend/     Flutter app (Dart, Riverpod, go_router, Drift)
backend/      Go API server (chi, pgx, Redis, S3/R2)
CLAUDE.md     Design context & brand guidelines
```

## Common Commands

### Frontend
```bash
cd frontend
dart analyze lib/           # Type check all Dart
flutter test                # Run tests
```

### Backend
```bash
cd backend
go build ./...              # Compile
go test ./...               # Run all tests
docker compose up -d        # Start postgres + redis
```

## Architecture

### Frontend
- **State**: Riverpod (`flutter_riverpod`)
- **Routing**: `go_router` — see `frontend/lib/router.dart`
- **Local DB**: Drift (SQLite) — caching layer
- **Theme**: `frontend/lib/theme/` — design tokens (`colors.dart`, `spacing.dart`, `typography.dart`, `theme.dart`)
- **Widgets**: `frontend/lib/widgets/` — `app_card`, `app_button`, `app_icon`, `mitlist_app_bar`, `empty_state`, `skeleton`, `alert`
- **Screens**: `frontend/lib/screens/` — one subfolder per feature area
- **Sheets**: `frontend/lib/sheets/` — bottom sheet creation/detail forms
- **Services**: `frontend/lib/services/` — API clients (Dio)
- **Models**: `frontend/lib/models/` — data classes with `fromJson`/`toJson`
- **Providers**: `frontend/lib/providers/` — Riverpod async providers for services

### Backend
- **Router**: `backend/cmd/api/main.go` — all route registration
- **Handlers**: `backend/internal/api/handlers/`
- **Services**: `backend/internal/services/`
- **Migrations**: `backend/migrations/` — PostgreSQL (golang-migrate)
- **Jobs**: `backend/internal/jobs/` — cron (chore scheduler, reminders, recurring expenses, weekly summary)
- **Infrastructure**: `backend/docker-compose.yml` — postgres:16-alpine, redis:7-alpine

## Design System

Brand: warm, punchy, organized. Orange primary (`MitlistColors.primary500` = `#F97316`).
- Typography: Space Grotesk (headings) + JetBrains Mono (mono)
- Borders: 2px outlines, square geometry (`BorderRadius.zero`)
- Components: `AppCard`, `AppButton`, `AppIcon`, `MitlistAppBar` — use these instead of raw Material widgets
- Spacing: Use `MitlistSpacing` tokens (xs=4, sm=8, md=16, lg=24, xl=32, xxl=48)
- Colors: Use `MitlistColors` — never hardcode `Color(0x...)`
- Both light and dark mode must be supported

## Anti-Patterns to Avoid
- Raw `AppBar()`, `Card()`, `FloatingActionButton()`, `OutlinedButton()`, `FilledButton()` — use design system components
- `Color(0x...)` — use `MitlistColors` tokens
- Hardcoded pixel values — use `MitlistSpacing`
- `VisualDensity.compact` or `MaterialTapTargetSize.shrinkWrap` on touch targets (must be ≥44dp)
- Missing `tooltip` on `IconButton` widgets
- Missing `Semantics` labels on image/gesture interactions
- Text widgets without `maxLines`/`overflow` in constrained layouts

## Key Routes

| Route | Name | Screen |
|-------|------|--------|
| `/home` | home | Household hub |
| `/chores` | chores | Chores list |
| `/recipes` | recipes | Recipes |
| `/money` | money | Expenses |
| `/lists` | lists | Shopping/todo lists |
| `/calendar` | calendar | Weekly calendar |
| `/you` | you | Account |
| `/you/notifications` | notifications | Notification inbox |
| `/you/notification-preferences` | notificationPreferences | Preference toggles |
| `/scanner` | scanner | OCR scanner for receipts, lists, recipes, chores |

## AI / OCR

The scanner uses **CrofAI** (`https://crof.ai/v1`) via OpenAI-compatible API. Set `CROFAI_API_KEY` in backend `.env`. The vision model `kimi-k2.5` processes images and returns structured JSON with type classification and extracted items/steps/amounts.

- Endpoint: `POST /assistant/scan` (multipart file upload)
- Service: `frontend/lib/services/scan_service.dart`
- Screen: `frontend/lib/screens/scanner/scanner_screen.dart`
- The old chat-based assistant has been removed.

## Testing

- Backend: Core journey tests in `backend/internal/api/handlers/` (integration-style with pgxmock)
- Frontend: `frontend/test/frontend_flows_test.dart` (mocked service integration tests)
- Lint: `dart analyze lib/` and `go build ./...` before committing
