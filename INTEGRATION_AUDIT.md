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

- **INT-CRIT-001 Vault feature unreachable (backend unmounted)**
  - **Backend**: `vault.go` handler exists but is not mounted in `backend/cmd/api/main.go`.
  - **Frontend**: `VaultScreen` calls `GET /vault?...` via `VaultService`.
  - **Impact**: Entire Vault feature area is unreachable in production (systemic 404s).
  - **Fix owner**: backend (mount routes) *or* frontend (remove/feature-flag screens); backend preferred if feature intended.
  - **Status**: OPEN

- **INT-CRIT-002 Error envelopes inconsistent; Flutter 400 parsing expects different shape**
  - **Backend**: Mixed usage of `handlers.respondError`, `api.WriteError`, and `api.RespondError` yields incompatible JSON bodies (sometimes `error` is a string, sometimes message is suppressed).
  - **Frontend**: `AuthService` and `GroupService` try to read `data['error']['message']` for `400`.
  - **Impact**: Users receive generic errors; some validation failures may be misrepresented; debugging is impeded. (Also violates “every error response shape” completeness.)
  - **Fix owner**: frontend (tolerant parsing) AND/OR backend (standardize). Source-of-truth is backend contract; recommend backend standardization with a single error envelope.
  - **Status**: OPEN

- **INT-CRIT-003 Session invalidation does not reliably force logout/redirect**
  - **Frontend**: Many services create Dio clients without Riverpod `Ref`, so `TokenRefreshInterceptor` can clear tokens without setting `authStateProvider=false`.
  - **Impact**: User can remain on protected screens with invalid session; behavior depends on which service triggers refresh failure. This is a “401 not handled (user stuck)” class issue.
  - **Fix owner**: frontend (centralize client creation with `Ref` or global auth controller).
  - **Status**: OPEN

#### HIGH

- **INT-HIGH-001 Refresh-token rotation + concurrent 401s can log user out**
  - **Backend**: refresh token is rotated (revoked then re-issued).
  - **Frontend**: per-request refresh attempt has no single-flight coordinator; concurrent 401s can cause one request to succeed then another to fail and clear tokens.
  - **Impact**: sporadic forced logout under token expiry bursts; hard-to-reproduce auth flakiness.
  - **Fix owner**: frontend (single-flight refresh queue).
  - **Status**: OPEN

- **INT-HIGH-002 Pagination not implemented in UI; lists truncate at 50**
  - **Backend**: most list endpoints support `limit/offset` with default `limit=50`.
  - **Frontend**: screens/providers only fetch first page; no “load more”/infinite scroll.
  - **Impact**: data sets > 50 rows are invisible.
  - **Fix owner**: frontend.
  - **Status**: OPEN

- **INT-HIGH-003 Group-scoped list endpoints may be called with invalid empty `group_id`**
  - **Frontend**: multiple screens fall back to `''` for `group_id`; `LivingThingsScreen` calls `listLivingThings('')` unconditionally.
  - **Backend**: validates `group_id` as UUID; returns validation error.
  - **Impact**: feature surfaces can fail even on happy path (fresh account/no groups).
  - **Fix owner**: frontend (require group selection / create-first flow / guard before calling).
  - **Status**: OPEN

#### MEDIUM

- **INT-MED-001 Group model expects fields backend doesn’t provide (`is_personal`, `member_count`)**
  - **Impact**: UI silently defaults (`false`, `1`) and may mislead users.
  - **Fix owner**: frontend (do not assume fields) *or* backend (add fields if contract intends).
  - **Status**: OPEN

- **INT-MED-002 List model expects `item_count` but backend doesn’t provide it**
  - **Impact**: UI shows `0` items unless it separately loads items.
  - **Fix owner**: frontend (remove count or compute client-side) or backend (add count).
  - **Status**: OPEN

- **INT-MED-003 Collections expect `recipe_count` but backend doesn’t provide it**
  - **Impact**: UI/counts show `0`.
  - **Fix owner**: frontend or backend.
  - **Status**: OPEN

- **INT-MED-004 Nullable string fields sent as `null` decode into empty strings on backend**
  - Examples: `CreateRecipeRequest.image_url`, living thing `location`/`image_url`, care log `notes`.
  - **Impact**: semantic drift (null vs empty) that can break “unset” logic.
  - **Fix owner**: frontend (omit null keys) preferred.
  - **Status**: OPEN

#### LOW

- **INT-LOW-001 Finance `amount` uses `int64` backend vs `int` frontend**
  - **Impact**: range/precision mismatch risk (esp. Flutter web).
  - **Fix owner**: frontend (use 64-bit safe representation) and/or backend docs.
  - **Status**: OPEN

### Fixed findings

(none yet)

