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
go test ./...               # Run all tests (some pre-existing failures)
docker compose up -d        # Start postgres + redis
```

## Architecture

### Frontend
- **State**: Riverpod (`flutter_riverpod`)
- **Routing**: `go_router` — see `frontend/lib/router.dart`
- **Local DB**: Drift (SQLite) — caching layer
- **Theme**: `frontend/lib/theme/` — design tokens (`colors.dart`, `spacing.dart`, `typography.dart`, `theme.dart`)
- **Widgets**: `frontend/lib/widgets/` — design system components
- **Hub Widgets**: `frontend/lib/widgets/hub/` — `pinwall_section`, `activity_wall`, `stats_grid`, `hub_skeleton`, `quick_add_sheet`
- **Screens**: `frontend/lib/screens/` — one subfolder per feature area
- **Sheets**: `frontend/lib/sheets/` — bottom sheet creation/detail forms
  - **Sheet vs. Page threshold**: If a form has >3 distinct sections or >6 interactive fields, push a full-page route instead of a bottom sheet. Bottom sheets are for focused, single-purpose actions. Complex creation/edit flows (recipe creation, household settings) should be full screens.
- **Services**: `frontend/lib/services/` — API clients (Dio)
- **Models**: `frontend/lib/models/` — data classes with `fromJson`/`toJson`
- **Providers**: `frontend/lib/providers/` — Riverpod async providers for services
- **Error Handling**: `frontend/lib/services/error_reporter.dart` — GlitchTip/Sentry-compatible error reporter

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
- Raw `AlertDialog` — use `showAppDialog()` with optional `actions` parameter
- Raw error strings (`e.toString()`) in user-facing SnackBars — use friendly messages instead
- Semicolons after Go final-clause block types

## Key Routes

| Route | Name | Screen |
|-------|------|--------|
| `/home` | home | Household hub (directly, no sub-route) |
| `/chores` | chores | Chores list |
| `/recipes` | recipes | Recipes |
| `/money` | money | Expenses |
| `/lists` | lists | Shopping/todo lists |
| `/calendar` | calendar | Weekly calendar |
| `/you` | you | Account |
| `/you/notifications` | notifications | Notification inbox |
| `/you/notification-preferences` | notificationPreferences | Preference toggles |
| `/scanner` | scanner | OCR scanner for receipts, lists, recipes, chores |

### Route Notes
- `/home` renders `HouseholdHubScreen` directly (no `_HomeEntryScreen`/`_GroupResolver` wrapper)
- Group switching happens via `currentGroupIdProvider` state, not route navigation
- Bottom nav Home button navigates to `/home` (no group path param)
- `currentGroupIdProvider` defined in `router.dart` as `StateProvider<String?>`
- The `:groupId/hub` sub-route was removed to avoid back-button issues when switching households

## AI / OCR

The scanner uses **CrofAI** (`https://crof.ai/v1`) via OpenAI-compatible API. Set `CROFAI_API_KEY` in backend `.env`. The vision model `kimi-k2.5` processes images and returns structured JSON with type classification and extracted items/steps/amounts.

- Endpoint: `POST /assistant/scan` (multipart file upload)
- Service: `frontend/lib/services/scan_service.dart`
- Screen: `frontend/lib/screens/scanner/scanner_screen.dart`

## Cross-Feature Integration

### Calendar Aggregate Types
The calendar (`GET /calendar`) aggregates these event types:
- `meal_plan` — Meal plans with recipe title
- `chore` — Chore assignments with due dates
- `recurring_expense` — Recurring expense due dates
- `expense` — One-time expense dates (added: `ListExpensesByDateRange`)
- `pinwall_reminder` — Pinwall posts with `remind_at` set (added: `ListPostsByGroupAndRemindAtRange`)

### Pinwall Entity Linking
- Migration `000022` added `linked_entity_type` + `linked_entity_id` to `pinwall_posts`
- Composer has a link button that opens an entity picker (fetches actual chores/lists/expenses)
- Linked entity badges in note cards are tappable — navigate to the entity's screen

### Chore → Shopping List
- Chore items with `supplies` configured show a "N supplies" badge inline
- Detailed supply management in the chore detail sheet

### Shopping Trip → Expense
- After completing shopping trip items, if any have `priceCents`, shows a SnackBar with total + "Add expense" action

### Meal Plan → Shopping List → Money
- "Generate shopping list" creates a list from meal plan ingredients
- After generation, SnackBar includes "Track costs" action linking to money screen

### Navigation Badges
- Bottom nav: Chores tab shows due count badge, Money tab shows settlement count badge
- Data from `navBadgeCountsProvider` in `providers/nav_badge_provider.dart`

## Testing

### Frontend Tests
- Integration tests: `frontend/test/frontend_flows_test.dart` (mocked services via Riverpod)
- 15 of 15 tests pass ✅

**Riverpod override pattern** (for mocking services):
```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      groupServiceProviderAsync.overrideWith((ref) async => fakeGroupService),
      choreServiceProviderAsync.overrideWith((ref) async => fakeChoreService),
    ],
    child: MaterialApp(home: child),
  ),
);
```

**Animation-safe pump** (replace `pumpAndSettle` for shimmer/Lottie):
```dart
Future<void> _pumpAfter(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) await tester.pump(const Duration(milliseconds: 300));
}
```

**Drift in-memory DB** (for future test improvements):
```dart
final database = AppDatabase(
  DatabaseConnection(
    NativeDatabase.memory(),
    closeStreamsSynchronously: true,  // Required for widget tests
  ),
);
```

### Backend Tests
| Package | Status | Notes |
|---------|--------|-------|
| `internal/services` | ✅ Pass | Service logic (fixed: added missing mock methods) |
| `internal/db` | ✅ Pass | Database connection |
| `internal/middleware` | ✅ Pass | Auth/CORS/logging |
| `pkg/validation` | ✅ Pass | Validation utilities |
| `internal/api/handlers` | ✅ Pass | Fixed: stale test signatures, duplicated routers |
| `internal/repositories` | ✅ Pass | Fixed: notification arg count, list column mismatches |
| `internal/jobs` | ✅ Pass | Fixed: expected job count 4→5 (added pinwall-reminder) |

**Mock method pattern** (when adding methods to backend interfaces):
```go
func (m *MockListRepo) ClaimItem(ctx context.Context, itemID uuid.UUID, userID uuid.UUID) error {
	args := m.Called(ctx, itemID, userID)
	return args.Error(0)
}
```

### Lint
- `dart analyze lib/` and `go build ./...` before every commit

## Error Handling

- `ErrorReporter` singleton in `lib/services/error_reporter.dart` — init with GlitchTip/Sentry DSN
- In `app.dart`: `FlutterError.onError` + `PlatformDispatcher.instance.onError` capture all errors (release-mode only via `kReleaseMode`)
- Error boundary widget at `lib/widgets/error_boundary.dart` (fallback UI, currently unused in widget tree)
- Set `GLITCHTIP_DSN` environment variable for production; add `sentry_flutter` to pubspec.yaml
- Error reporters are guarded by `kReleaseMode` to avoid interfering with Flutter test framework

## AppDialog Actions

`showAppDialog()` now supports an optional `actions` parameter:
```dart
showAppDialog<bool>(
  context: context,
  title: 'Delete item',
  body: const Text('This cannot be undone.'),
  actions: [
    AppButton(text: 'Cancel', variant: AppButtonVariant.outline, onPressed: ...),
    AppButton(text: 'Delete', color: AppButtonColor.error, onPressed: ...),
  ],
)
```

## Migration History

| Migration | Description |
|-----------|-------------|
| 000001 | Core schema (users, groups, lists, chores, finance, recipes, etc.) |
| 000002–000021 | Various schema additions (pinwall, attachments, meal plans, chore subtasks, etc.) |
| **000022** | Added `linked_entity_type` + `linked_entity_id` to `pinwall_posts` |

## Key API Endpoints Added

| Method | Route | Added When |
|--------|-------|-----------|
| `GET` | `/expenses/{id}/splits` | Calendar density — list expense splits |
| `GET` | (via calendar) `ListExpensesByDateRange` | Calendar density — one-time expenses in calendar |
| `GET` | (via pinwall) `ListPostsByGroupAndRemindAtRange` | Pinwall reminders in calendar |
