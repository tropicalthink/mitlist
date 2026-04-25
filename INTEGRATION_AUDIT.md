## Integration audit (Go backend ↔ Flutter frontend)

This audit is driven from:
- `BACKEND_SURFACE.md`
- `FRONTEND_CONSUMPTION.md`
- `INTEGRATION_MAP.md`
- `INTEGRATION_GAPS_*.md`

Severity definitions (per spec):
- **CRITICAL**: auth bypass possible, data silently corrupted by schema mismatch, entire feature area unreachable, user stuck on 401, payment/financial endpoint mismatch
- **HIGH**: schema mismatch that drops data, missing error handler for any 4xx/5xx, wrong method/path, pagination broken
- **MEDIUM**: missing feature wiring, suboptimal messages, missing loading state
- **LOW**: unused fields, minor naming inconsistencies

### Findings (open)

#### CRITICAL

- (none)

#### HIGH

- **INT-HIGH-002 Pagination not implemented in UI; lists truncate at 50**
  - **Backend**: most list endpoints support `limit/offset` with default `limit=50`.
  - **Frontend**: screens/providers only fetch first page; no “load more”/infinite scroll.
  - **Impact**: data sets > 50 rows are invisible.
  - **Fix owner**: frontend.
  - **Status**: FIXED

#### MEDIUM

- **INT-MED-001 Group model expects fields backend doesn’t provide (`is_personal`, `member_count`)**
  - **Impact**: UI silently defaults (`false`, `1`) and may mislead users.
  - **Fix owner**: frontend (do not assume fields) *or* backend (add fields if contract intends).
  - **Status**: FIXED

- **INT-MED-002 List model expects `item_count` but backend doesn’t provide it**
  - **Impact**: UI shows `0` items unless it separately loads items.
  - **Fix owner**: frontend (remove count or compute client-side) or backend (add count).
  - **Status**: FIXED

- **INT-MED-003 Collections expect `recipe_count` but backend doesn’t provide it**
  - **Impact**: UI/counts show `0`.
  - **Fix owner**: frontend or backend.
  - **Status**: FIXED

- **INT-MED-004 Nullable string fields sent as `null` decode into empty strings on backend**
  - Examples: `CreateRecipeRequest.image_url`, living thing `location`/`image_url`, care log `notes`.
  - **Impact**: semantic drift (null vs empty) that can break “unset” logic.
  - **Fix owner**: frontend (omit null keys) preferred.
  - **Status**: FIXED

#### LOW

- **INT-LOW-001 Finance `amount` uses `int64` backend vs `int` frontend**
  - **Impact**: range/precision mismatch risk (esp. Flutter web).
  - **Fix owner**: frontend (use 64-bit safe representation) and/or backend docs.
  - **Fix**: frontend now parses int64-like JSON values defensively and throws on unsafe JS number ranges on web.
  - **Status**: FIXED (frontend guard; backend still returns JSON number)

### Newly verified in this batch

- **INT-MED-005 Notifications endpoints were unmounted / preferences not wired**
  - **Backend**: mounted `GET /vapid` and protected `/notifications/*` endpoints.
  - **Frontend**: wired the “Notifications” toggle to `/notifications/preferences` and added a Notification service.
  - **Status**: FIXED (push device registration still deferred)

- **INT-MED-006 Share-target endpoints not wired in Flutter**
  - **Backend**: `/share-target/lists` and `/share-target/recipes` already mounted.
  - **Frontend**: `ShareTargetScreen` now posts to both endpoints.
  - **Status**: FIXED

- **INT-MED-007 Push subscription endpoints missing**
  - **Backend**: added protected create/list/delete endpoints under `/auth/push-subscriptions` backed by `push_subscriptions`.
  - **Frontend**: client implemented (create/list/delete) but device registration is still deferred.
  - **Status**: PARTIAL

- **INT-MED-008 Notifications inbox not present in Flutter**
  - **Backend**: `/notifications` list/get/read/read-all/delete are mounted.
  - **Frontend**: added Notifications inbox screen with pagination + mark read + delete; reachable from AccountScreen.
  - **Status**: FIXED

### Fixed findings

- **INT-CRIT-001 Vault feature unreachable (backend unmounted)** — **FIXED**
  - **Fix**: mounted vault routes in `backend/cmd/api/main.go` and wired `VaultService` into `backend/internal/container/container.go`.
  - **Verification**: `go test ./...` and `go build ./...` passed.

- **INT-CRIT-002 Error envelopes inconsistent; Flutter 400 parsing expects different shape** — **FIXED (backend-standardized)**
  - **Fix**: `api.RespondError` now delegates to `api.WriteError`; `api.WriteError` now emits stable `error` codes (`validation_error`, `unauthorized`, etc.) and includes `message` consistently.
  - **Verification**: `go test ./...` and `go build ./...` passed.

- **INT-CRIT-003 Session invalidation does not reliably force logout/redirect** — **FIXED**
  - **Fix**: all feature services now construct Dio via `createApiClient(ref)` so the refresh interceptor can always update `authStateProvider` on refresh failure.
  - **Verification**: `flutter analyze` (no errors) and `flutter test` passed.

- **INT-HIGH-001 Refresh-token rotation + concurrent 401s can log user out** — **FIXED**
  - **Fix**: added a single-flight refresh coordinator in `TokenRefreshInterceptor` so concurrent 401s await one refresh attempt instead of racing with a rotated refresh token.
  - **Verification**: `flutter analyze` (no errors) and `flutter test` passed.

- **INT-HIGH-003 Group-scoped list endpoints may be called with invalid empty `group_id`** — **FIXED**
  - **Fix**: `ListsScreen`, `ChoresScreen`, `ExpensesScreen`, `VaultScreen`, and `LivingThingsScreen` now resolve a real household before calling group-scoped list endpoints and show a “No household yet” state when none exists. Group-scoped list services also reject invalid group IDs before issuing Dio requests.
  - **Verification**: `flutter analyze` (no errors) and `flutter test` passed.

- **INT-HIGH-002 Pagination not implemented in UI; lists truncate at 50** — **FIXED**
  - **Fix**: added offset-based pagination/infinite scroll behavior to the main list screens and services where applicable; stops when a page returns < limit.
  - **Verification**: `flutter analyze` (no errors) and `flutter test` passed.

- **INT-MED-001 Group model expects fields backend doesn’t provide (`is_personal`, `member_count`)** — **FIXED**
  - **Fix**: treat these fields as unknown when omitted instead of defaulting to misleading values; UI hides/gates display accordingly.
  - **Verification**: `flutter analyze` (no errors) and `flutter test` passed.

- **INT-MED-002 List model expects `item_count` but backend doesn’t provide it** — **FIXED**
  - **Fix**: treat `item_count` as unknown when omitted; UI hides count and avoids misleading sorts when unknown.
  - **Verification**: `flutter analyze` (no errors) and `flutter test` passed.

- **INT-MED-003 Collections expect `recipe_count` but backend doesn’t provide it** — **FIXED**
  - **Fix**: treat `recipe_count` as unknown when omitted; UI hides count when unknown.
  - **Verification**: `flutter analyze` (no errors) and `flutter test` passed.

- **INT-MED-004 Nullable string fields sent as `null` decode into empty strings on backend** — **FIXED**
  - **Fix**: request DTO `toJson()` methods omit nullable string keys when null instead of sending explicit null.
  - **Verification**: `flutter analyze` (no errors) and `flutter test` passed.

