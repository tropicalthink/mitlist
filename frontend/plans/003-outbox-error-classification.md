# Plan 003: Classify sync failures — transient retries, permanent dead-letters, no head-of-line blocking

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" occurs, stop and report. When done, update the
> status row for this plan in `plans/README.md`.
>
> **Drift check (run first, from `frontend/`)**:
> `git diff --stat 6c868661..HEAD -- lib/repositories/outbox_drainer.dart lib/services/api_error_mapper.dart lib/storage/app_database.dart`
> This plan assumes plan 002 has landed and `lib/repositories/outbox_drainer.dart`
> exists. If it does not exist, STOP — 002 must be done first.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (changes sync retry semantics; data-integrity sensitive)
- **Depends on**: `plans/002-shared-outbox-drainer.md`
- **Category**: bug
- **Planned at**: commit `6c868661`, 2026-06-13

## Why this matters

Today every sync failure is treated identically: the drainer's single `catch`
block calls `markOutboxAttempt(op.id, error: 'Something went wrong.')` then
`return`s. Two concrete harms:

1. **Silent data loss on permanent errors.** A write the server will *always*
   reject (HTTP 400/422 — malformed, validation, references a deleted parent)
   gets retried up to 10 times (`maxAttempts` in
   `getOutboxBatchByTypes`/`outboxPendingCount`), then silently becomes a
   "failed" op that sits in the outbox forever while the optimistic local row
   stays visible. The user thinks the change saved; it never will. There is no
   distinction between "the network is down, try later" and "this will never
   succeed."
2. **Head-of-line blocking.** On any failure the loop `return`s, so a single
   poison op blocks every later queued op in that domain. A bad op can stall an
   entire list's sync until backoff lets it retry — and it fails again.

This plan classifies the error in the **one** place plan 002 created and:
- **transient** (network down, timeout, 5xx, 429) → record an attempt, stop the
  pass (don't hammer a struggling server) — unchanged from today, correct.
- **permanent** (4xx that isn't 409/429) → **dead-letter immediately** (don't
  waste 10 retries) and **continue** to the next op (no head-of-line blocking).
- **conflict** (409) → for this plan, treat as permanent (dead-letter +
  continue). Plan 004 adds the real conflict-routing branch.

"Dead-letter" reuses existing infrastructure with **no schema change**: set the
op's `attempt_count` to the failure threshold so it's excluded from future
drains (`getOutboxBatchByTypes` filters `attempt_count < maxAttempts`) and
counted by `outboxFailedCount` — which already drives the banner's "Couldn't
sync N changes" state. The op also stores the *real* error message for
debugging instead of the generic string.

## Current state

After plan 002, `lib/repositories/outbox_drainer.dart` contains:
```dart
try {
  await handler(fresh, payload);
} catch (e) {
  // PLAN 003 will replace this block with error classification.
  await _db.markOutboxAttempt(op.id, error: 'Something went wrong.');
  return;
}
```

Relevant existing pieces:
- `lib/services/api_error_mapper.dart` — `ApiErrorMapper.fromDio(DioException)`
  returns a clean user-facing message; it already switches on
  `e.response?.statusCode` (400, 401, 403, 404, 409, 422, 429, 5xx) and on
  `DioExceptionType` (connectionTimeout/receiveTimeout/sendTimeout →
  timeout; connectionError → network). Use it for the stored message.
- `lib/storage/app_database.dart`:
  - `markOutboxAttempt(String id, {String? error})` (line 496) — increments
    `attempt_count`, sets `last_attempt_at`, stores `error` in `last_error`.
  - `getOutboxBatchByTypes(...)` (line 474) filters
    `attemptCount.isSmallerThanValue(maxAttempts)` with default `maxAttempts: 10`.
  - `outboxFailedCount({maxAttempts = 10})` (line 530) counts
    `attempt_count >= maxAttempts`.
  - `OutboxOps` table: column `attemptCount` (`attempt_count`, default 0),
    `lastError` (`last_error`).
- The op handlers throw `DioException` (from Retrofit/Dio) on HTTP errors. They
  may also throw non-Dio exceptions (e.g. a cast/parse error in handler logic),
  which are permanent (will never succeed) → classify as permanent.
- The default `maxAttempts` used across queries is **10**. Use a single shared
  constant for the dead-letter threshold so it stays in sync. There is currently
  no named constant; introduce `kOutboxMaxAttempts = 10` (see Step 1) and prefer
  referencing it, but do NOT go change every existing `maxAttempts: 10` call
  site in this plan (out of scope) — just ensure the dead-letter value matches.

## Commands you will need

| Purpose   | Command (from `frontend/`)                          | Expected |
|-----------|------------------------------------------------------|----------|
| Analyze   | `dart analyze lib/`                                 | `2 issues found.` (pre-existing); no new issues |
| Tests     | `flutter test`                                      | all pass |
| Targeted  | `flutter test test/repositories/outbox_drainer_test.dart` | all pass |

## Scope

**In scope**:
- `lib/repositories/outbox_error_classifier.dart` (create)
- `lib/storage/app_database.dart` (add ONE method: `markOutboxPermanentFailure`)
- `lib/repositories/outbox_drainer.dart` (edit the catch block only)
- `test/repositories/outbox_error_classifier_test.dart` (create)
- `test/repositories/outbox_drainer_test.dart` (extend)

**Out of scope** (do NOT touch):
- Any DB **schema** change (no new columns, no `schemaVersion` bump). The
  dead-letter mechanism deliberately reuses `attempt_count`. If you think a
  column is needed, STOP and report.
- 409/conflict routing into the `Conflicts` table — that is plan 004. Here, 409
  is classified as `permanent`.
- The repositories' `_sync*` handler bodies and `*OfflineFirst` methods.
- The banner UI (`lib/widgets/offline_banner.dart`) — it already reacts to
  `outboxFailedCount`.

## Git workflow

- Branch: `advisor/003-outbox-error-classification`.
- Conventional Commits, e.g. `fix: dead-letter permanent outbox failures`.

## Steps

### Step 1: Add the error classifier

Create `lib/repositories/outbox_error_classifier.dart`:

```dart
import 'package:dio/dio.dart';

/// Shared dead-letter threshold. Mirrors the default `maxAttempts` used by
/// AppDatabase.getOutboxBatchByTypes / outboxFailedCount. An op at or above
/// this attempt count is excluded from future drains and counted as failed.
const int kOutboxMaxAttempts = 10;

/// How the drainer should treat a failed outbox op.
enum OutboxErrorDisposition {
  /// Worth retrying later (network down, timeout, server 5xx, 429). Record an
  /// attempt; stop the current pass to avoid hammering a struggling server.
  transient,

  /// Will never succeed as-is (HTTP 4xx other than 409/429). Dead-letter the
  /// op immediately and continue with the next op.
  permanent,

  /// Server reports a version/state conflict (HTTP 409). Plan 004 routes this
  /// to the Conflicts table; until then the drainer treats it like permanent.
  conflict,
}

/// Classifies an exception thrown while syncing an outbox op.
OutboxErrorDisposition classifyOutboxError(Object error) {
  if (error is! DioException) {
    // Non-network exceptions (parse/cast errors in handler logic) never
    // succeed on retry.
    return OutboxErrorDisposition.permanent;
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return OutboxErrorDisposition.transient;
    case DioExceptionType.cancel:
      return OutboxErrorDisposition.transient;
    case DioExceptionType.badCertificate:
      return OutboxErrorDisposition.permanent;
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break; // fall through to status-code handling
  }

  final status = error.response?.statusCode;
  if (status == null) {
    // No response (e.g. socket error surfaced as unknown) — retry later.
    return OutboxErrorDisposition.transient;
  }
  if (status == 409) return OutboxErrorDisposition.conflict;
  if (status == 408 || status == 429) return OutboxErrorDisposition.transient;
  if (status >= 500) return OutboxErrorDisposition.transient;
  if (status >= 400) return OutboxErrorDisposition.permanent;
  return OutboxErrorDisposition.transient;
}
```

**Verify**: `dart analyze lib/repositories/outbox_error_classifier.dart` → no issues.

### Step 2: Add the dead-letter DB method

In `lib/storage/app_database.dart`, next to `markOutboxAttempt` (around line
496-509), add:

```dart
/// Marks an op as permanently failed (dead-lettered) without burning retry
/// budget: sets attempt_count to the failure threshold so it is excluded from
/// future drains (getOutboxBatchByTypes filters attempt_count < maxAttempts)
/// and counted by outboxFailedCount, and stores the real error for debugging.
Future<void> markOutboxPermanentFailure(
  String id, {
  String? error,
  int threshold = 10,
}) async {
  await (update(outboxOps)..where((t) => t.id.equals(id))).write(
    OutboxOpsCompanion(
      lastAttemptAt: Value(DateTime.now()),
      attemptCount: Value(threshold),
      lastError: Value(error),
    ),
  );
}
```

(Keep the default `threshold` at 10 to match `maxAttempts`. The drainer will
pass `kOutboxMaxAttempts`.)

**Verify**: `dart analyze lib/storage/app_database.dart` → no new issues. (Note:
`app_database.g.dart` is generated; this change uses only existing generated
symbols — `OutboxOpsCompanion`, `outboxOps` — so **no codegen run is required**.
If analysis reports a missing generated symbol, STOP — something is off.)

### Step 3: Apply classification in the drainer's catch block

In `lib/repositories/outbox_drainer.dart`, add
`import 'package:dio/dio.dart';` (only if needed),
`import '../services/api_error_mapper.dart';`, and
`import 'outbox_error_classifier.dart';`. Replace the catch block:

```dart
      try {
        await handler(fresh, payload);
      } catch (e) {
        final message =
            e is DioException ? ApiErrorMapper.fromDio(e) : 'Sync failed.';
        switch (classifyOutboxError(e)) {
          case OutboxErrorDisposition.transient:
            // Worth retrying — record an attempt and stop the pass so we don't
            // hammer a struggling server. Backoff in getOutboxBatchByTypes
            // gates the next attempt.
            await _db.markOutboxAttempt(op.id, error: message);
            return;
          case OutboxErrorDisposition.permanent:
          case OutboxErrorDisposition.conflict:
            // Will never succeed as-is. Dead-letter immediately and keep going
            // so one poison op does not block the rest of the queue.
            // (Plan 004 adds a real conflict branch here.)
            await _db.markOutboxPermanentFailure(op.id,
                error: message, threshold: kOutboxMaxAttempts);
            continue;
        }
      }
```

**Verify**: `dart analyze lib/` → `2 issues found.`, no new issues.

### Step 4: Extend the drainer tests

In `test/repositories/outbox_drainer_test.dart`, add cases (the file already
uses an in-memory DB and the `fakeDioException(statusCode:)` helper is available
from `test/support/fakes.dart`):

1. **Permanent failure dead-letters and does NOT block the queue**: two ops;
   the first handler throws `fakeDioException(statusCode: 422)`, the second
   handler records a call. After `drain`: the first op has
   `attemptCount == kOutboxMaxAttempts` (10) — i.e. counted by
   `db.outboxFailedCount()` (→ 1) and excluded by
   `db.outboxPendingCount()` — **and the second handler ran** (call-count 1,
   its op deleted). This is the key regression-prevention test versus today's
   head-of-line block.
2. **Transient failure records one attempt and stops the pass**: two ops; first
   handler throws `fakeDioException(statusCode: 503)`. After `drain`: first op
   `attemptCount == 1`, `lastError != null`, **second handler did NOT run**.
3. **Non-Dio exception is permanent**: handler throws `StateError('x')` →
   op ends with `attemptCount == kOutboxMaxAttempts`.

**Verify**: `flutter test test/repositories/outbox_drainer_test.dart` → all pass.

### Step 5: Unit-test the classifier

Create `test/repositories/outbox_error_classifier_test.dart`. Pure unit tests
using `fakeDioException(statusCode:)`:
- 400, 401, 403, 404, 422 → `permanent`
- 409 → `conflict`
- 408, 429 → `transient`
- 500, 502, 503 → `transient`
- a `DioException` with `type: DioExceptionType.connectionError` → `transient`
- a non-Dio `Exception` → `permanent`

(If `fakeDioException` cannot set `DioExceptionType`, construct a `DioException`
directly with `requestOptions: RequestOptions(path: '/')` and the desired
`type` — `import 'package:dio/dio.dart';`.)

**Verify**: `flutter test test/repositories/outbox_error_classifier_test.dart` → all pass.

### Step 6: Full suite

**Verify**: `flutter test` → all pass.

## Test plan

- New `test/repositories/outbox_error_classifier_test.dart` (Step 5) — exhaustive
  status-code mapping.
- Extended `test/repositories/outbox_drainer_test.dart` (Step 4) — the two
  behavior changes (permanent dead-letter + no head-of-line block; transient
  still stops the pass).
- Existing repository/coordinator tests must still pass (the happy path and the
  `attemptCount == 1` transient-failure cases are unchanged for transient
  errors, which is what those tests use — `fakeDioException(statusCode: 503)`).
- Verification: `flutter test` → all pass.

## Done criteria

ALL must hold:

- [ ] `lib/repositories/outbox_error_classifier.dart` exists with `classifyOutboxError` + `OutboxErrorDisposition` + `kOutboxMaxAttempts`.
- [ ] `AppDatabase.markOutboxPermanentFailure` exists; no schema/`schemaVersion` change (`grep -n "schemaVersion" lib/storage/app_database.dart` still shows `=> 4;`).
- [ ] The drainer catch block branches on `classifyOutboxError`; `grep -n "markOutboxPermanentFailure\|classifyOutboxError" lib/repositories/outbox_drainer.dart` shows both used.
- [ ] `dart analyze lib/` → `2 issues found.`, no new issues.
- [ ] `flutter test` exits 0; the new + extended tests pass, including the "second handler still runs after a permanent failure" case.
- [ ] No files outside the in-scope list modified (`git status`).
- [ ] `plans/README.md` status row for 003 updated.

## STOP conditions

Stop and report (do not improvise) if:
- `lib/repositories/outbox_drainer.dart` does not exist (plan 002 not done).
- Editing `app_database.dart` appears to require regenerating
  `app_database.g.dart` (it should not — you only use existing generated
  symbols).
- Existing repository tests fail in a way that suggests transient errors are no
  longer retried (they must remain `transient` → attempt recorded, op kept).
- You conclude a real schema column is needed for dead-lettering — report the
  reasoning instead of bumping `schemaVersion`.

## Maintenance notes

- **Dead-lettered ops are invisible to the user beyond the banner count and are
  never auto-retried** (by design — retrying a 422 is pointless). A natural
  follow-up (not in this plan) is a "failed changes" review surface that lets
  the user discard or edit-and-resend dead-lettered ops; today the banner shows
  the count but the conflict sheet only handles conflicts, not generic
  failures. Flag this in review as a known UX gap.
- The dead-letter threshold (`kOutboxMaxAttempts`) must stay equal to the
  `maxAttempts` defaults in `getOutboxBatchByTypes` / `outboxFailedCount` /
  `outboxPendingCount`. If anyone changes those defaults, update the constant.
- Plan 004 replaces the `case OutboxErrorDisposition.conflict:` branch with real
  conflict routing. Reviewers of 004 should expect the change localized there.
