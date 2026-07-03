# Plan 020: A transient network error during token refresh no longer force-logs-out the user

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- frontend/lib/services/token_refresh_coordinator.dart frontend/lib/services/api_client.dart frontend/lib/services/sse_service.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

`TokenRefreshCoordinator._run()` catches **every** exception — including a
`connectTimeout` or a dropped connection on `/auth/token/refresh` — and returns
`null`, which is indistinguishable from a genuine 401 (refresh token rejected).
The Dio auth interceptor treats that `null` as an auth failure: it clears the
token store, wipes user data, and flips `authStateProvider` to `false`, forcing
a full re-login. So a one-second network blip while the access token happens to
be expired evicts the user's session. The same `null` also silently kills the
SSE reconnect loop. Distinguishing "auth rejected" (clear tokens) from
"transport failed" (keep tokens, let the caller retry/back off) fixes a bad,
common, and hard-to-reproduce UX failure.

## Current state

- `frontend/lib/services/token_refresh_coordinator.dart` — process-wide
  single-flight refresh. The bug is in `_run()`:

```dart
// token_refresh_coordinator.dart:78-103
Future<TokenPairResult?> _run() async {
  final refreshToken = await _store.getRefreshToken();
  if (refreshToken == null) return null;

  try {
    final response = await _dio.post(
      '/auth/token/refresh',
      data: {'refresh_token': refreshToken},
    );
    final data = response.data;
    if (response.statusCode == 200 && data is Map<String, dynamic>) {
      final access = data['access_token'];
      final refresh = data['refresh_token'];
      if (access is String && refresh is String) {
        await _store.save(accessToken: access, refreshToken: refresh);
        return TokenPairResult(accessToken: access, refreshToken: refresh);
      }
    }
  } catch (e) {
    if (kDebugMode) {
      final status = e is DioException ? e.response?.statusCode : null;
      _logger.e('Token refresh failed (status: $status)');
    }
  }
  return null;   // ← network error and 401 both land here
}
```

- `frontend/lib/services/api_client.dart` — the interceptor consumes the result:

```dart
// api_client.dart:104-110
final attemptedRefreshToken = await _tokenStore.getRefreshToken();
final tokenPair = await _coordinator.refresh();
if (tokenPair == null) {
  await _onRefreshFailure(attemptedRefreshToken);   // ← clears tokens on ANY null
  handler.next(err);
  return;
}
```
`_onRefreshFailure` (`api_client.dart:132-145`) calls `_tokenStore.clear()`,
removes user data, and sets `authStateProvider = false`. Its change-detection
guard only skips the wipe if the stored refresh token was rotated by another
path — a network error does **not** rotate it, so the guard does not fire.

- `frontend/lib/services/sse_service.dart:92-95` — the SSE reconnect loop calls
  the same coordinator; a `null` result `break`s the loop.

### Convention to follow

Return a small sealed-style result the callers can switch on. The repo uses
plain classes (no `freezed` in this file); mirror the existing `TokenPairResult`
class style already in `token_refresh_coordinator.dart:8-16`. Keep the public
`refresh()` return type backward-compatible by adding a *new* method rather than
breaking the existing one if that reduces blast radius (see Step 1 options).

## Commands you will need

| Purpose   | Command                                                        | Expected on success |
|-----------|----------------------------------------------------------------|---------------------|
| Analyze   | `cd frontend && dart analyze lib/`                             | `No issues found!`  |
| Test one  | `cd frontend && flutter test test/services/`                  | all pass            |
| Full test | `cd frontend && flutter test`                                 | pass (1 pre-existing `welcome_screen` invited-guest fail is expected — ignore it) |

Note: `flutter test` needs native `libsqlite3`. If it errors with
`Failed to load dynamic library 'libsqlite3.so'`, that is environmental: create
a symlink `ln -sf /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /tmp/sqlitelib/libsqlite3.so`
and run with `LD_LIBRARY_PATH=/tmp/sqlitelib flutter test`. CI has the lib.

## Scope

**In scope**:
- `frontend/lib/services/token_refresh_coordinator.dart`
- `frontend/lib/services/api_client.dart`
- `frontend/lib/services/sse_service.dart`
- `frontend/test/services/token_refresh_coordinator_test.dart` (create)

**Out of scope** (do NOT touch):
- `frontend/lib/services/auth_service.dart` — its explicit logout path is
  correct; only the *implicit* refresh-failure eviction is the bug.
- The backend `/auth/token/refresh` contract — unchanged.

## Git workflow

- Branch: `advisor/020-token-refresh-transient-error`
- Conventional commits, e.g. `fix(auth): keep session on transient refresh network error`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Give the coordinator a tri-state outcome

In `token_refresh_coordinator.dart`, introduce a result type that distinguishes
the three outcomes and change `_run()` to produce it:

- **success** — carries the rotated `TokenPairResult`.
- **authRejected** — the endpoint returned a 401/403 (or 200 with a malformed
  body / no refresh token to begin with). Tokens should be cleared.
- **transportError** — a `DioException` whose `type` is a connection/timeout
  error, or `response == null` (no HTTP response was received). Tokens must be
  kept.

Concretely: keep the existing `refresh()` returning `Future<TokenPairResult?>`
for any callers that only care about success, **and** add
`Future<TokenRefreshOutcome> refreshDetailed()` that the interceptor and SSE
loop switch on. Classify inside the `catch`:

```dart
} on DioException catch (e) {
  if (e.response == null ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.connectionError) {
    return const TokenRefreshOutcome.transportError();
  }
  return const TokenRefreshOutcome.authRejected();
}
```
Only a real HTTP error response (401/403/500…) is treated as `authRejected`;
`500` from the auth server is debatable but treat non-null-response as
authRejected for now (documented in Maintenance notes). Coalescing via
`_inFlight` must still work — store the detailed future and derive the simple
`TokenPairResult?` from it.

**Verify**: `cd frontend && dart analyze lib/` → `No issues found!`

### Step 2: Only clear tokens on `authRejected` in the interceptor

In `api_client.dart`, replace the `_coordinator.refresh()` call in the error
interceptor with `refreshDetailed()` and switch:
- `success` → retry the original request with the new access token (existing
  logic at `api_client.dart:112-121`).
- `authRejected` → `_onRefreshFailure(attemptedRefreshToken)` then `handler.next(err)`.
- `transportError` → do **not** clear tokens; `handler.next(err)` so the
  original request surfaces its network error to the caller (the user sees a
  "network" error, not a logout).

**Verify**: `cd frontend && dart analyze lib/` → `No issues found!`

### Step 3: Keep the SSE loop alive on transport error

In `sse_service.dart`, where it calls the coordinator (~line 92), on
`transportError` do not `break` — let the existing reconnect/backoff continue
(see Plan 030 for the backoff fix; if 030 already landed, keep its behavior).
On `authRejected`, breaking is correct.

**Verify**: `cd frontend && dart analyze lib/` → `No issues found!`

### Step 4: Tests

Create `frontend/test/services/token_refresh_coordinator_test.dart` modeled on
the structure of existing service tests under `frontend/test/services/` (use a
`Dio` with a `MockAdapter` or a stubbed `HttpClientAdapter`; check how other
tests in that folder stub Dio and match it). Cover:
- 200 with a valid pair → `success`, tokens saved.
- 401 → `authRejected`, tokens NOT saved.
- `DioException(type: connectionError)` → `transportError`, tokens NOT saved.
- no refresh token in store → `authRejected` (or a dedicated "no token" that the
  interceptor treats as authRejected — document which).

**Verify**: `cd frontend && flutter test test/services/token_refresh_coordinator_test.dart` → all pass.

## Test plan

- New file `token_refresh_coordinator_test.dart` with the four cases above.
- Structural pattern: whichever existing `frontend/test/services/*_test.dart`
  stubs Dio (grep for `HttpClientAdapter` or `DioAdapter` in that folder).
- Verification: `cd frontend && flutter test test/services/` → all pass incl. new tests.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd frontend && dart analyze lib/` exits 0 (`No issues found!`)
- [ ] `grep -n "refreshDetailed\|TokenRefreshOutcome" frontend/lib/services/token_refresh_coordinator.dart` → present
- [ ] `grep -n "transportError" frontend/lib/services/api_client.dart frontend/lib/services/sse_service.dart` → present in both
- [ ] New test file exists and `flutter test test/services/token_refresh_coordinator_test.dart` passes
- [ ] `cd frontend && flutter test` exits 0 (only the known `welcome_screen` invited-guest case may fail)
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:
- The `_run()` body no longer matches the excerpt (drift).
- `refresh()` has callers beyond the interceptor and SSE loop that would break
  from the return-type change — report them; do not blindly edit unrelated files.
- A verification fails twice after a reasonable fix attempt.

## Maintenance notes

- Decide policy for `500` from the refresh endpoint: currently treated as
  `authRejected`. If the auth server can 500 transiently, reclassify 5xx as
  `transportError` — note it here when changed.
- If Plan 030 (SSE backoff) lands after this, re-verify the SSE loop's
  transport-error branch composes with the backoff reset.
- Reviewer: confirm `transportError` never reaches `_onRefreshFailure`.
