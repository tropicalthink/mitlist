# Plan 035: Collapse the duplicated `_handleError` wrappers into one path

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- frontend/lib/services`
> If the service files changed, re-grep the `_handleError` sites (below) before editing.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

The identical 3-line method
`Exception _handleError(DioException e) => ApiException(ApiErrorMapper.fromDio(e));`
is copy-pasted into at least 8 services, wrapped by ~169 hand-written
`try { … } on DioException catch (e) { throw _handleError(e); }` blocks. The
wrapper adds nothing over calling `ApiErrorMapper` directly, and each hand-written
catch is a place someone can forget to map and leak a raw `DioException` (an
AGENTS.md anti-pattern). Consolidating to a single helper (or a Dio interceptor)
removes the boilerplate and the forget-to-map risk.

## Current state

The duplicated method (identical body) appears in, at minimum:
`list_service.dart`, `chore_service.dart`, `auth_service.dart`,
`finance_service.dart`, `group_service.dart`, `meal_plan_service.dart`,
`calendar_service.dart`, `recipe_service.dart`. Example:

```dart
// frontend/lib/services/list_service.dart:394 (and 7 identical siblings)
Exception _handleError(DioException e) {
  return ApiException(ApiErrorMapper.fromDio(e));
}
```
`ApiErrorMapper.fromDio` and `ApiException` live in
`frontend/lib/services/api_error_mapper.dart`:

```dart
// api_error_mapper.dart:3-8
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override String toString() => message;
}
class ApiErrorMapper { static String fromDio(DioException e) { ... } }
```

Confirm the exact site list before editing:
`grep -rn "Exception _handleError(DioException" frontend/lib/services`.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Analyze | `cd frontend && dart analyze lib/` | `No issues found!` |
| Test | `cd frontend && flutter test` | pass (sqlite-env note may apply) |

## Scope

**In scope**:
- `frontend/lib/services/api_error_mapper.dart` (add the shared helper)
- The service files that define `_handleError` (listed above — confirm by grep)

**Out of scope**:
- Rewriting all ~169 catch blocks to use a Dio interceptor — that is a larger,
  riskier change. This plan does the **minimal** consolidation: one shared helper,
  delete the per-service duplicates, repoint their call sites. The interceptor
  approach is noted as a deferred follow-up.
- Changing `ApiErrorMapper.fromDio` behavior — messages must stay identical.

## Git workflow

- Branch: `advisor/035-dart-error-mapper-dedup`
- Conventional commit: `refactor(services): single error-mapping helper, drop duplicates`.

## Steps

### Step 1: Add one shared helper next to the mapper

In `api_error_mapper.dart`, add a top-level function (or static method):

```dart
Exception apiException(DioException e) => ApiException(ApiErrorMapper.fromDio(e));
```
Behavior is byte-identical to every `_handleError`.

**Verify**: `cd frontend && dart analyze lib/` → `No issues found!`

### Step 2: Delete the per-service duplicates and repoint call sites

In each service that defines `_handleError`, delete the method and replace every
`throw _handleError(e)` with `throw apiException(e)` (import the helper). Do this
mechanically, one file at a time, running analyze after each to catch a missed
import.

**Verify after each file**: `cd frontend && dart analyze lib/` → `No issues found!`

### Step 3: Confirm no duplicates remain

**Verify**: `grep -rn "Exception _handleError(DioException" frontend/lib/services`
→ no matches.

## Test plan

- Behavior is unchanged, so existing service tests are the regression guard: run
  the full suite. No new tests required (this is a pure refactor). If any service
  had a test asserting on `_handleError` directly (unlikely), repoint it.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd frontend && dart analyze lib/` exits 0
- [ ] `grep -rn "Exception _handleError(DioException" frontend/lib/services` → no matches
- [ ] `grep -rn "apiException(" frontend/lib/services | wc -l` → ≥ the number of former call sites
- [ ] `cd frontend && flutter test` passes (only the known welcome-screen case may fail)
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- A `_handleError` has a subtly different body in some service (not the identical
  3-liner) — do NOT collapse that one; report it.
- The catch blocks are more varied than `throw _handleError(e)` (e.g. some add
  context) — leave those, consolidate only the identical ones, and report the count.

## Maintenance notes

- Deferred follow-up: a `Dio` interceptor that throws `ApiException` on error
  would remove the ~169 try/catch blocks entirely. Larger change; own plan.
- Reviewer: confirm no message text changed and every repointed site imports the
  helper.
