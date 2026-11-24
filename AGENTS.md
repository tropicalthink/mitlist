# mitlist — Agent Reference

## Project Overview
Shared household coordination app (lists, money, chores, recipes). Flutter frontend + Go backend.

## Repository Layout

```
frontend/     Flutter app (Dart, Riverpod, go_router, Drift)
backend/      Go API server (chi, pgx, S3/R2)
PRODUCT.md    Product and design context
```

## Common Commands

### Frontend
```bash
cd frontend
dart analyze lib/           # Type check all Dart
flutter test                # Run tests
```

### Regenerating generated code (Drift)

Generated files (`*.g.dart`, e.g. `lib/storage/app_database.g.dart`) are
committed, so normal builds, `dart analyze`, and `flutter test` work without
running codegen. To regenerate after changing Drift tables:

```bash
cd frontend
dart run build_runner build
```

CI runs the same command and fails if generated files are stale.

### Backend
```bash
cd backend
go build ./...              # Compile
go test ./...               # Run all tests
docker compose up -d        # Start postgres
```

### Self-hosting
`./scripts/selfhost-setup.sh && docker compose up -d --build` (guide: `docs/SELF_HOSTING.md`). One public URL (`MITLIST_URL`) serves the web app and the API: a web build without `API_BASE_URL` calls its own origin and the web image's nginx (`frontend/nginx/default.conf.template`) proxies `/api` to the backend. Attachments use local disk (`STORAGE_LOCAL_PATH`) without S3; without an email provider, sign-up skips verification. Keep new required config optional for a self-host, or add it to the setup script and the guide.

## Architecture

### Frontend
- **State**: Riverpod (`flutter_riverpod`)
- **Routing**: `go_router` — see `frontend/lib/router.dart`
- **Local DB**: Drift (SQLite) — caching layer
- **Theme**: `frontend/lib/theme/` — design tokens (`colors.dart`, `spacing.dart`, `typography.dart`, `theme.dart`)
- **Widgets**: `frontend/lib/widgets/` — design system components
- **Hub Widgets**: `frontend/lib/widgets/hub/` — `pinwall_section`, `activity_wall`, `stats_grid`, `hub_skeleton`, `quick_add_sheet`, `hub_create_actions` (shared "create a list / add to a list / add an expense" launchers: use these from Home, checklists and empty states instead of re-implementing them)
- **Screens**: `frontend/lib/screens/` — one subfolder per feature area
- **Sheets**: `frontend/lib/sheets/` — bottom sheet creation/detail forms
  - **Sheet vs. Page threshold**: If a form has >3 distinct sections or >6 interactive fields, push a full-page route instead of a bottom sheet. Bottom sheets are for focused, single-purpose actions. Complex creation/edit flows (recipe creation, household settings) should be full screens.
- **Services**: `frontend/lib/services/` — API clients (Dio)
- **Offline outbox**: `frontend/lib/repositories/outbox_drainer.dart` + `services/outbox_coordinator.dart`. Never start a drain (`drainOutboxOnce()`) or other fire-and-forget DB work from inside a `_db.transaction(...)` callback: Drift binds every query in that async chain to the transaction, which has committed by the time the network call returns, and the local bookkeeping then fails with "transaction was used after being closed" while the server has already applied the write (`test/repositories/list_repository_checkoff_drain_test.dart`). Local writes do not drain on their own: repositories call their injected `onLocalWrite` hook (production wires it through `SyncScheduler` to `OutboxCoordinator.noteLocalWrite()`; with no hook and `autoSync` on they still drain immediately, which the repository tests rely on), and the coordinator flushes that *sync session* once per screen visit, on a route change, app pause, connectivity restore or retry, or after `kSyncSessionIdleWindow` (20 s) without a new write. **Holds**: `SyncScheduler.hold(reason)` (reference-counted, `services/sync_scheduler.dart`; the coordinator gets the same scheduler) keeps the outbox from draining on its own: while any hold is active the idle timer is not armed, and local writes, route changes, connectivity restores, app resumes, the retry timer and plain `drain()` only note that a flush is owed; releasing the last hold always flushes. Only explicit flushes pass a hold: `flushSession` (app pause, which keeps the hold; meal plan and recipe share) and the manual retries (`retryFailed`/`retryOp`, `drain(force: true)`). The list detail screen is the only holder: it holds while the router location is its own (sheets, dialogs and the scanner pushed over it keep the location) and releases on leaving it and in `dispose`, so housemates and widgets see a visit's list changes when the person leaves the list or backgrounds the app. Server-only actions there send just what they need through the hold (`ListRepository.sendQueuedOpsNow`): a photo on an item added this visit sends that item's create first, a reminder op goes out at once (the server schedules it), and generating an expense drains the list's ops first. The shopping trip does not hold: its ticks keep the normal session. The banner shows "Syncing" only while a drain is actually running; queued-but-deferred ops only appear in the sync-status sheet.
- **Lists** (`screens/lists/`): tapping a line's words edits it in place (`widgets/list/list_item_line.dart`) with the detail row pinned above the keyboard (`list_item_edit_accessory.dart`: amount, unit, price, note, photo, delete); a commit diffs against the item as the edit began (`utils/list_item_edit.dart`) and makes one `updateItemFields` call, none when nothing changed; an emptied name deletes. Undo/redo: per-visit, in-memory history (`list_undo_stack.dart`, driven by `list_detail_controller.dart`), dropped on leaving the list; the arrows commit an open edit first and skip a step a housemate has since changed. Because the screen holds the outbox (see Offline outbox), a visit's ops are normally still queued, and undo takes them back instead of sending a correction: an undone tick withdraws its queued `updateItem` and `recordPurchase` and puts every local count back (purchase history, bought-together pairs, the unrecognised-word tally, and a promotion it minted while its alias upload, now sent with the next drain, has not gone out; `ListRepository.withdrawQueuedPurchases`, journal in memory); an undone add of a never-sent item drops its queued create (and edits), which redo queues again unchanged; an undone delete or clear withdraws its op and puts the exact rows back (same id, position, photos). Only when something was already sent (the app was paused mid-visit, a photo or expense needed the server) does undo fall back: a `restoreItem` op calls `POST /lists/{id}/items/{item_id}/restore` (an older server without it, 404/405, gets the row re-created under a new id, at the end of the list and without photos), and a purchase already sent stays counted. An open edit follows its line when the item's create syncs (`itemIdChanges` is synchronous; `ListDetailController.onItemIdAdopted`). Not undoable: photos. Item notes are cached in Drift (`list_items_table.note`, schema v18), filled from the API, SSE refetches and the outbox, so an edit starts from the real note and undo restores it.
- **Home screen widgets** (plans/047): the widget UI is native (Jetpack Glance under `android/app/src/main/kotlin/me/mitlist/widgets/`; WidgetKit in the `MitlistWidgets` extension plus `ios/WidgetShared/`, compiled into both iOS targets). The app talks to it over the `me.mitlist/widgets` method channel through `lib/services/widgets/`: it issues the device's widget credential, writes the server snapshot (`GET /widget/snapshot`), and imports ops widgets queued (`repositories/widget_ops_repository.dart`, replayed as `widgetRequest` outbox ops with the widget's exact bytes). Formats and golden fixtures: `contracts/widgets/`. A session with "Remember me" off gets no widget credential: `HomeWidgetsController.start()` calls `clearAll(reason: 'not_remembered')` and the widgets show "Widgets need Remember me"; sign-out clears with no reason ("Sign in"). The **Widgets page** (`screens/you/widgets_screen.dart`, route `/you/widgets`, deep link `mitlist:///you/widgets`, linked from the You screen, redirects to `/you` where widgets are unsupported) previews every kind (`services/widgets/home_widget_kind.dart`; quick add on both platforms) with `widgets/home_widget_preview.dart`, marks the ones `installedWidgets` reports (unknown kind strings are ignored), and pins in one tap where the Android launcher supports it, else shows the steps. The **promo sheet** (`widgets/hub/widget_promo_sheet.dart`, rules in `services/widgets/widget_promo.dart`) is offered on the first Home visit after onboarding, then again every 42 days while no widget is installed (never twice when native cannot tell); last shown in pref `widget_promo_last_shown_at`, kept across sign-out. The FCM/APNs push token is registered at sign-in without waiting for notification permission (`FcmService.init` via `PushTokenRegistrar`), so the silent widget refresh pushes (C6) arrive for people who never allowed notifications.
- **Shared calendars** (`screens/you/shared_calendars_screen.dart`, route `/you/calendars`, linked from You and the calendar app bar): a member connects their own calendars and chooses what each household sees. Two kinds: `device` (the phone's calendars, read on device through `services/device_calendar/`: the `device_calendar_plus` plugin on iOS, the native `me.mitlist/device_calendar` channel on Android, which needs only READ_CALENDAR and exposes the private flag) and `ics` (a private iCal link the server polls; works on web). Per calendar and household: Not shared (default) / Busy only / With titles; per event: Hidden / Busy / With title. The rule lives once per side: `utils/external_calendar_visibility.dart` (what a housemate sees, and `buildDeviceUpload`: no events from unshared calendars, hidden events never uploaded, a title only when it could be shown) and `ResolveExternalEventView` in `backend/internal/services/external_calendar_visibility.go` (the server enforces it; membership is checked at query time). `DeviceCalendarSync` runs after a settings change and on start/resume at most every 15 minutes; before every upload it reads `GET /calendar/external/overrides` and sends pending local choices, and uploads nothing if either fails, so a reinstall cannot re-upload a hidden event. The household calendar asks for `include=external` (old builds read unknown event types as meal plans, so the server only sends `external_event` on request and never to widget or integration credentials), shows housemates' events and a "who's around" card for the selected day (`utils/household_availability.dart`), and refetches on SSE `calendar:external_changed`. Server side: `internal/services/ical/` is an in-repo iCal parser with bounded recurrence expansion; the ICS URL is encrypted at rest with a key derived from `SECRET_KEY` (changing it breaks existing links) and is never returned or logged; job `external-calendar-refresh` polls every 30 minutes with backoff; stored window is now-1 day to now+90 days.
- **Models**: `frontend/lib/models/` — data classes with `fromJson`/`toJson`
- **Providers**: `frontend/lib/providers/` — Riverpod async providers for services
- **Error Handling**: `frontend/lib/services/error_reporter.dart` — GlitchTip/Sentry-compatible error reporter

### Backend
- **Router**: `backend/cmd/api/main.go` — all route registration
- **Handlers**: `backend/internal/api/handlers/`
- **Services**: `backend/internal/services/`
- **Migrations**: `backend/migrations/` — PostgreSQL (golang-migrate)
- **Jobs**: `backend/internal/jobs/` — cron (chore scheduler, reminders, recurring expenses, weekly summary)
- **Infrastructure**: `docker-compose.yml` — postgres:16-alpine

## Design System

Brand: warm, punchy, organized. Orange primary (`mitlistColors.primary500` = `#F97316`).
- Typography: Space Grotesk (headings) + JetBrains Mono (mono)
- Borders: 2px outlines, square geometry (`BorderRadius.zero`)
- Components: `AppCard`, `AppButton`, `AppIcon`, `mitlistAppBar` — use these instead of raw Material widgets
- Spacing: Use `mitlistSpacing` tokens (xs=4, sm=8, md=16, lg=24, xl=32, xxl=48)
- Colors: Use `mitlistColors` — never hardcode `Color(0x...)`
- Both light and dark mode must be supported

## Anti-Patterns to Avoid
- Raw `AppBar()`, `Card()`, `FloatingActionButton()`, `OutlinedButton()`, `FilledButton()` — use design system components
- `Color(0x...)` — use `mitlistColors` tokens
- Hardcoded pixel values — use `mitlistSpacing`
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
| `/you/calendars` | sharedCalendars | Shared calendars: connect own calendars, choose what each household sees |
| `/you/widgets` | widgets | Home screen widgets page (also `mitlist:///you/widgets`; Android/iOS only) |
| `/scanner` | scanner | OCR scanner for receipts, lists, recipes, chores |

### Route Notes
- `/home` renders `HouseholdHubScreen` directly (no `_HomeEntryScreen`/`_GroupResolver` wrapper)
- Group switching happens via `currentGroupIdProvider` state, not route navigation
- Bottom nav Home button navigates to `/home` (no group path param)
- `currentGroupIdProvider` defined in `router.dart` as `StateProvider<String?>`
- The `:groupId/hub` sub-route was removed to avoid back-button issues when switching households

## AI / OCR

The mobile scanner uses bundled **PP-OCRv6 ONNX models** and an on-device grocery resolution pipeline. Images and recognised text are processed locally; no hosted AI service is called. Scanning is available on iOS and Android and is currently unavailable on web.

- Service: `frontend/lib/services/scan/scan_pipeline_service.dart`
- Screen: `frontend/lib/screens/scanner/scanner_screen.dart`
- One engine for every photo: `ocrServiceProvider` (`providers/ocr_provider.dart`). Lists read with `OcrPageKind.list` (household vocabulary + catalog); receipts and recipes read with `OcrPageKind.document` (text as printed, up to 240 boxes) through `screens/scanner/document_photo_reader.dart`.
- Receipts: the Money screen's camera button → `screens/money/receipt_scan.dart` → `services/scan/receipt_parser.dart` (store, date, total, priced lines; checks the lines add up to the total) → the expense sheet, prefilled with the photo attached and the lines in the notes. Eval: `samples/receipts/` + `test/fixtures/receipts/`. A switch in that sheet (remembered in prefs, default on) records the receipt's purchases on save: `ReceiptPurchaseMatcher` only accepts lines the household-aware resolver links confidently to an item the household already tracks (`getHouseholdCanonicalIds`): receipt shorthand links confidently to wrong catalog items, so a receipt confirms purchases but never introduces items. `ListRepository.recordReceiptPurchases` writes them like check-offs (one `recordPurchase` op, bought-together pairs once) and skips anything already recorded within 12 h. A second switch (pref `receipt_tick_list_items`, default on) ticks off the open shopping-list items those purchases cover (`ReceiptPurchaseMatcher.openListItems`): same canonical id only (never name similarity), one item per receipt line, preferring the list the receipt covers most, skipping items added after the receipt day. Ticked items go through `completeItemsOfflineFirst` and so record their own purchase; the receipt then records only the rest.
- Recipes: "Read a photo" on recipe creation → `services/scan/recipe_text_parser.dart` (title, two-column ingredients, method split into sentences, ½ fractions repaired). Eval: `samples/recipes/` + `test/fixtures/recipes/`.

## Cross-Feature Integration

### Calendar Aggregate Types
The calendar (`GET /calendar`) aggregates these event types:
- `meal_plan` — Meal plans with recipe title
- `chore` — Chore assignments with due dates
- `recurring_expense` — Recurring expense due dates
- `expense` — One-time expense dates (added: `ListExpensesByDateRange`)
- `pinwall_reminder` — Pinwall posts with `remind_at` set (added: `ListPostsByGroupAndRemindAtRange`)
- `external_event` — a member's synced calendar event, only with `include=external` (see Shared calendars)

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

## In-App Feature Requests (reqtrack)

Users can submit feature requests from the You screen ("Send feedback" row) to the
studio's request tracker (the `reqtrack` repo, Cloudflare Worker at
`reqtrack.tropicalthink.com`). Not routed through the Go backend.

- Config: `frontend/lib/config/feedback_config.dart` — build with
  `--dart-define=REQTRACK_APP_KEY=...` (and optionally `REQTRACK_URL=...`);
  the entry point is hidden when no key is baked in.
- Service: `frontend/lib/services/feedback_service.dart` — own Dio instance
  (different host; sends `X-App-Key`, never the user's Bearer token).
- Sheet: `frontend/lib/sheets/feedback_sheet.dart` — captures the current route
  as `sourcePage` (plus the prior route as `metadata.previousPage` via
  `utils/route_history.dart`) so the team can replicate the submitter's context.

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
| 000023–000027 | Offline/outbox, canonical grocery graph, and intelligence sync support |
| 000028–000033 | List item canonical ids, finance additions, chore zones, notification preferences, pinwall positioning |
| 000034 | Attachment storage accounting and quota reservations |
| 000035 | PostgreSQL-backed refresh-token sessions |
| 000036–000067 | Settlement approval, billing, auth hardening, integrations, recipe sharing, and launch consent |
| 000068 | Onboarding email attempt reservation |
| 000069 | Batched activity notifications |
| 000070–000072 | Calendar range-query indexes for expenses, recurring expenses, and pinwall reminders |
| 000073 | List reminders |
| 000074 | `invited_at` on `testing_signups` (store invitation email) |
| 000075 | `users.last_active_at`, `users.language` (app UI language, reported by the app) + `reengagement_email_sends` (feedback check-in after 7 days away) |
| 000076 | `integration_credentials.kind` (`integration` / `widget`), `device_id`, `expires_at`: device-bound home screen widget credentials (plans/047) |
| 000077 | `integration_credentials.push_token`: iOS 26 WidgetKit push token of a device's widgets (plans/047) |
| 000078 | `product_events`: first-party onboarding-funnel and Home events (plans/048 stage 8); no IP, user agent or free text |
| 000079 | `group_invites.created_by`: who minted an invite code, for the signed-out preview (plans/048 stage 7) |
| 000080 | `users.email_unproven`: password account created verified on a server with no email provider; never linked to an OAuth identity by email until an emailed code proves the address |
| 000081 | `store_aisles.store_key` (a shipped store layout's slug) and a unique index that treats a missing store as one value, so aisle feedback updates in place; dedupes the NULL-store rows that piled up |
| 000082 | Shared calendars: `calendar_connections`, `external_calendars`, `external_calendar_shares`, `external_events`, `external_event_overrides` |

Latest migration: `000082_external_calendars`.

## Key API Endpoints Added

| Method | Route | Added When |
|--------|-------|-----------|
| `GET` | `/expenses/{id}/splits` | Calendar density — list expense splits |
| `GET` | (via calendar) `ListExpensesByDateRange` | Calendar density — one-time expenses in calendar |
| `GET` | (via pinwall) `ListPostsByGroupAndRemindAtRange` | Pinwall reminders in calendar |
| `POST` | `/testing/signups` (Staffroom/reqtrack, not this API) | Public Turnstile-attested mobile-beta signups; see the staffroom repo's `apps/api` |
| `POST`/`DELETE` | `/auth/widget-credential` | Home screen widgets — issue/revoke this install's widget credential (session auth only) |
| `GET` | `/widget/snapshot` | Home screen widgets — households, open list items, due chores, tonight's meal, balance (plans/047) |
| `PUT` | `/widget/push-token` | Home screen widgets — an iOS widget extension registers its WidgetKit push token (widget credential only) |
| `GET` | `/invites/{code}/preview` | Signed-out invite preview (plans/048 stage 7): `household_name`, `inviter_name` (first name, omitted if unknown or gone), `member_count`, `status`; no ids or emails; public, 20/min per IP |
| `POST` | `/lists/{id}/items/{item_id}/restore` | List undo: puts a deleted item back with its id, position, checked state and photos; idempotent; publishes `list:item_created` only when a row came back |
| various | `/calendar/external/*` | Shared calendars (session auth only): `connections` (GET/POST/PATCH/DELETE, `/{id}/sync`, `/{id}/device-sync`), `calendars/{id}/shares` (PUT), `events/mine` (GET), `overrides` (GET/PUT); `GET /calendar?include=external` adds housemates' events |
| `POST` | `/events` | First-party product events (plans/048 stage 8): public, optional session; app client `lib/services/product_events.dart` sends only when built with `--dart-define=MITLIST_PRODUCT_EVENTS=true` (off until the privacy policy covers it) |
