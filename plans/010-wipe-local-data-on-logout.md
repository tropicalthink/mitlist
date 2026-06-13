# Plan 010: Wipe the local Drift database and cached user data on logout

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9c9b04f3..HEAD -- frontend/lib/services/auth_service.dart frontend/lib/storage/app_database.dart frontend/lib/screens/you/account_screen.dart`
> On a mismatch with "Current state", treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW–MED (must not wipe data for the offline-pending case without warning)
- **Depends on**: plans/009-frontend-test-baseline.md (green `flutter test` gate)
- **Category**: security
- **Planned at**: commit `9c9b04f3`, 2026-06-11

## Why this matters

Logout clears tokens and a handful of SharedPreferences keys, but the Drift
sqlite database — containing the household's expenses, finance summaries, lists,
chores, and pinwall posts — survives. On a shared or handed-over device, the next
person (or anyone with the logged-out device) retains another household's
financial data on disk. The wipe function already exists (`clearAllUserData()`,
used by account deletion); logout just never calls it. This finding supersedes a
"encrypt the local DB" recommendation — wiping on logout is the cheap 90%.

## Current state

- `frontend/lib/services/auth_service.dart:103–122` — `logout()`:

  ```dart
  Future<void> logout() async {
    await FcmService.unregisterToken(_dio);
    await FcmService.reset();
    try {
      final refreshToken = _prefs.getString(ApiConfig.refreshTokenKey);
      if (refreshToken != null) {
        await _dio.post('/auth/logout', data: {'refresh_token': refreshToken});
      }
    } on DioException catch (e) {
      _logger.e('Logout failed: ${e.response?.data}');
      // Continue to clear tokens even if logout API call fails
    }
    await _clearTokens();
  }
  ```

  `_clearTokens()` (:351–360) removes token/user/UI-pref SharedPreferences keys only.
- `frontend/lib/storage/app_database.dart:722` — `clearAllUserData()` exists: a
  single transaction deleting all cache/outbox/conflict tables while preserving
  global grocery seed rows (`is_global = true`, `source == 'seed'`). It is called
  only from `frontend/lib/screens/you/account_screen.dart:275,311` (account
  deletion / explicit clear flows).
- `AuthService` does NOT currently hold an `AppDatabase` reference — check its
  constructor and how it's provided (`frontend/lib/providers/auth_provider.dart`)
  before deciding where to invoke the wipe. Two acceptable shapes:
  1. Inject `AppDatabase` (or a `Future<void> Function()` wipe callback) into
     `AuthService` via its provider, call it inside `logout()` after `_clearTokens()`.
  2. Call the wipe at the provider/notifier layer that orchestrates logout
     (wherever `authService.logout()` is awaited — find with
     `grep -rn "\.logout()" frontend/lib/`), immediately after it resolves.
  Prefer whichever matches the existing wiring with the smallest diff.
- **Pending-outbox caveat**: `clearAllUserData()` deletes `outboxOps` — any
  unsynced offline writes are lost on logout. That is acceptable and standard,
  but check whether the logout UI already warns; if there is a pending-ops count
  readily available (see `outbox_provider.dart`'s pending count query), gate the
  wipe behind the existing confirm dialog text if one exists. Do NOT build new
  UI; at most extend an existing confirmation string. If no confirmation exists,
  proceed with the wipe and note it.

## Commands you will need

| Purpose | Command (run in `frontend/`) | Expected on success |
|---------|------------------------------|---------------------|
| Deps    | `flutter pub get`            | exit 0              |
| Analyze | `dart analyze lib/`          | exit 0              |
| Tests   | `flutter test`               | all pass            |

## Scope

**In scope**:
- `frontend/lib/services/auth_service.dart`
- `frontend/lib/providers/auth_provider.dart` (wiring only)
- The logout call site if the provider-layer shape is chosen
- New test in `frontend/test/` (see Test plan)

**Out of scope**:
- `clearAllUserData()` itself — its table list is account-deletion-vetted; reuse as-is.
- SQLcipher / database encryption — explicitly rejected this cycle.
- Login/session-restore flows.

## Git workflow

- Branch: `fix/wipe-local-data-on-logout` off `new-main-fr`.
- One conventional commit (`fix: wipe local database and caches on logout`).
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Locate the logout orchestration

`grep -rn "logout()" frontend/lib/` — identify every caller of
`AuthService.logout()` and where navigation/post-logout cleanup happens.

### Step 2: Invoke the wipe

Add the `clearAllUserData()` call per one of the two shapes above, AFTER the
token clear (so a wipe failure can't leave tokens behind). Wrap in try/catch
that logs but does not block logout completion (`_logger.e(...)` convention).

**Verify**: `dart analyze lib/` → exit 0.

### Step 3: Test

Write a widget/unit test (pattern: the harness in
`frontend/test/frontend_flows_test.dart:~995` — in-memory `AppDatabase`,
`ProviderScope` overrides): seed one row into `expensesTable` and one into
`listsTable`, run the logout path, assert both tables are empty and the seeded
global grocery rows survive.

**Verify**: `flutter test` → all pass including the new test.

## Done criteria

- [ ] `dart analyze lib/` exits 0; `flutter test` exits 0
- [ ] Logout path calls `clearAllUserData()` (grep confirms a call site outside account_screen.dart)
- [ ] New test proves tables empty post-logout
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `AuthService`/provider wiring makes injection genuinely awkward (e.g. circular
  provider dependency) — report the dependency shape instead of restructuring DI.
- An existing logout confirmation flow exists whose UX the wipe would
  contradict — report it.

## Maintenance notes

- Anyone adding a new cache table must add it to `clearAllUserData()` — that
  function is now the logout boundary too, not just account deletion.
- Reviewer: confirm wipe ordering (after token clear), and that failure to wipe
  doesn't abort logout.
- Deferred: warning UI for pending unsynced outbox ops at logout.
