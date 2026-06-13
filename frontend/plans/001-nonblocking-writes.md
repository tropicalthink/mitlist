# Plan 001: Writes never block on the network; opportunistic sync is fire-and-forget

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> anything in "STOP conditions" occurs, stop and report — do not improvise.
> When done, update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first, from `frontend/`)**:
> `git diff --stat 6c868661..HEAD -- lib/repositories/list_repository.dart lib/repositories/finance_repository.dart lib/repositories/recipe_repository.dart`
> If any of those files changed since this plan was written, compare the
> "Current state" excerpts below against the live code; on a mismatch, treat it
> as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (changes when sync happens relative to the write; adds a re-entrancy guard)
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `6c868661`, 2026-06-13
- **Revised**: 2026-06-13 — first execution attempt found that naively making
  the inline drain `unawaited` makes the existing outbox tests race the
  fire-and-forget drain (a one-shot fake throw is consumed non-deterministically,
  and two overlapping drains double-send). This version adds a **re-entrancy
  guard** (production correctness) and an **`autoSync` constructor seam** (test
  determinism). Do not revert to a bare `unawaited` change.

## Why this matters

Every offline-first write currently ends with `await drainOutboxOnce()`, which
fires the network request **inline and blocks the caller until it returns**. On
a spotty connection where the OS reports an interface as "connected" but there
is no real internet (captive portals, dead uplinks, weak signal), Dio waits the
full 30-second timeout (`lib/config/api_config.dart` → `requestTimeout`) before
the write method's `Future` resolves — so "add item" can hang the caller for 30s
even though the row already appeared locally.

The fix makes opportunistic immediate-sync **fire-and-forget**: the optimistic
local write already updated the Drift `watch` streams (UI correct instantly),
and the `OutboxCoordinator` already re-drains on connectivity changes, app
resume, and a retry timer. Precedent: `ChoreRepository` already uses
`unawaited(_drainAndRefresh(groupId))`.

Two complications this plan must handle (learned from the first attempt):

1. **Re-entrancy / double-send.** Rapid writes (e.g. toggling checkboxes) would
   each fire an `unawaited` drain; with no guard, two drains read the same op
   and both POST it — a duplicate server write. The fix adds a per-repository
   `_isDraining` guard (mirrors the one `OutboxCoordinator` already has).
2. **Test determinism.** You cannot deterministically assert on the result of a
   fire-and-forget side effect. The fix adds an `autoSync` constructor flag
   (default `true`); tests construct repos with `autoSync: false` and drive
   `drainOutboxOnce()` explicitly, so they observe a single, awaited drain.

## Current state

Offline-first write methods that block on an inline drain (verified at
`6c868661`):
- `lib/repositories/list_repository.dart`
  - `createItemOfflineFirst` line 120, `updateItemOfflineFirst` line 165,
    `deleteItemOfflineFirst` line 235: `await drainOutboxOnce();`
  - `drainOutboxOnce` defined at line 238.
  - Constructor (lines 20-26): `ListRepository({required AppDatabase db,
    required ListService remote, Uuid? uuid})`.
  - Already imports `unawaited`:
    `import 'dart:async' show StreamSubscription, unawaited;` (line 1).
- `lib/repositories/finance_repository.dart`
  - `createExpenseOfflineFirst` line 93, `updateExpenseOfflineFirst` line 127,
    `deleteExpenseOfflineFirst` line 143. Constructor lines 16-22. Does **not**
    import `dart:async`.
- `lib/repositories/recipe_repository.dart`
  - drains at lines 63, 99, 118. Check imports; add `dart:async` if needed.
  - (No dedicated test file exists for recipe — production change only.)

Already non-blocking — **do not change**: `chore_repository.dart` (already
`unawaited`), `pinwall_repository.dart` (only enqueues, never drains inline).

Re-entrancy guard exemplar — `OutboxCoordinator` (`lib/services/outbox_coordinator.dart:67-96`):
```dart
Future<void> drain() async {
  if (_isDraining) return;
  _isDraining = true;
  try {
    // ...
  } finally {
    _isDraining = false;
  }
}
```

Test setup exemplar — `test/repositories/list_repository_outbox_test.dart:39-42`:
```dart
setUp(() {
  db = _memoryDb();
  remote = FakeListService();
  repo = ListRepository(db: db, remote: remote);
});
```
`FakeListService.throwOnCreateItem` (and `FakeFinanceService.throwOnCreate`,
`throwOnUpdate`) are **one-shot**: they throw once then reset to null
(`test/support/fakes.dart`). This is exactly why an un-guarded double drain
corrupts the failure-path tests.

## Commands you will need

| Purpose   | Command (from `frontend/`)                                          | Expected |
|-----------|---------------------------------------------------------------------|----------|
| Deps      | `flutter pub get`                                                   | exit 0 (fresh worktree needs this first) |
| Analyze   | `dart analyze lib/`                                                 | `2 issues found.` (pre-existing `dart:html` infos); no new issues |
| Tests     | `flutter test`                                                      | all pass |
| Outbox    | `flutter test test/repositories/list_repository_outbox_test.dart test/repositories/finance_repository_test.dart` | all pass |

## Scope

**In scope**:
- `lib/repositories/list_repository.dart`
- `lib/repositories/finance_repository.dart`
- `lib/repositories/recipe_repository.dart`
- `test/repositories/list_repository_outbox_test.dart`
- `test/repositories/finance_repository_test.dart`

**Out of scope** (do NOT touch):
- `chore_repository.dart`, `pinwall_repository.dart` — already non-blocking;
  leave their (absent) guard/flag alone to avoid behavior changes.
- `connectivity_service.dart` — reachability is plan 003; no health-ping here.
- `outbox_coordinator.dart`, any provider, any UI/screen file. The repository
  providers construct repos with no `autoSync` argument, so the default `true`
  keeps production behavior — do not edit providers.

## Git workflow

- Branch: `advisor/001-nonblocking-writes`.
- Conventional Commits, e.g. `fix: make offline-first write sync fire-and-forget`.
- Do NOT push or open a PR.

## Steps

### Step 1: Add the `autoSync` seam + re-entrancy guard to the three repositories

For each of `list_repository.dart`, `finance_repository.dart`,
`recipe_repository.dart`:

1. Add a field `final bool _autoSync;` and a constructor parameter
   `bool autoSync = true`, initialized to `_autoSync`. Example for
   `ListRepository`:
   ```dart
   ListRepository({
     required AppDatabase db,
     required ListService remote,
     Uuid? uuid,
     bool autoSync = true,
   })  : _db = db,
         _remote = remote,
         _uuid = uuid ?? const Uuid(),
         _autoSync = autoSync;
   ```
2. Add a field `bool _isDraining = false;` and wrap the **existing**
   `drainOutboxOnce()` body in the guard (preserving the body verbatim,
   including its internal early `return`s):
   ```dart
   Future<void> drainOutboxOnce() async {
     if (_isDraining) return;
     _isDraining = true;
     try {
       // ... existing body unchanged ...
     } finally {
       _isDraining = false;
     }
   }
   ```
3. Ensure `dart:async` `unawaited` is importable: `list_repository.dart` already
   has it; add `import 'dart:async' show unawaited;` to `finance_repository.dart`
   and `recipe_repository.dart` (only if not already importing `unawaited`).

**Verify**: `dart analyze lib/` → `2 issues found.`, no new issues.

### Step 2: Make inline drains fire-and-forget, gated by `autoSync`

Replace each inline `await drainOutboxOnce();` in the `*OfflineFirst` methods of
the three repos with:
```dart
if (_autoSync) unawaited(drainOutboxOnce());
```
(For `finance.updateExpenseOfflineFirst`, which re-reads and returns a row after
the old `await drainOutboxOnce();`: it now re-reads immediately and returns the
optimistic local row — correct and intended.)

**Verify**:
- `grep -rn "await drainOutboxOnce" lib/repositories/list_repository.dart lib/repositories/finance_repository.dart lib/repositories/recipe_repository.dart` → no matches.
- `grep -rn "if (_autoSync) unawaited(drainOutboxOnce())" lib/repositories/list_repository.dart` → 3 matches.
- `dart analyze lib/` → `2 issues found.`, no new issues.

### Step 3: Make the affected tests deterministic via `autoSync: false`

The drain is now fire-and-forget, so tests must drive it explicitly.

In `test/repositories/list_repository_outbox_test.dart` **and**
`test/repositories/finance_repository_test.dart`:
1. In `setUp`, construct the repo with `autoSync: false`, e.g.
   `repo = ListRepository(db: db, remote: remote, autoSync: false);`
   (finance: `FinanceRepository(db: db, remote: remote, autoSync: false)`).
2. Because no auto-drain fires, **every** test that asserts post-sync state must
   now call `await repo.drainOutboxOnce();` explicitly after the write and
   before those assertions. This is a **uniform rule** and applies to BOTH
   success-path tests (asserting server ID / `outboxCount() == 0`) AND
   failure-path tests (asserting `attemptCount == 1`, `lastError != null` after
   a one-shot throwing fake). Example (failure path):
   ```dart
   remote.throwOnCreateItem = fakeDioException(statusCode: 503);
   final result = await repo.createItemOfflineFirst(listId, const CreateListItemRequest(...));
   await repo.drainOutboxOnce(); // drain is fire-and-forget + autoSync:false
   final ops = await db.getOutboxBatch(limit: 10);
   expect(ops.where((o) => o.type == 'createItem').first.attemptCount, equals(1));
   ```
3. Tests that already call `await repo.drainOutboxOnce()` (e.g. the
   "dependent updateItem" and "after recovery" cases) keep that call; with
   `autoSync: false` there is no auto-drain racing them, so they remain correct.
   Do not weaken any assertion.

**Verify**:
`flutter test test/repositories/list_repository_outbox_test.dart test/repositories/finance_repository_test.dart`
→ all pass.

### Step 4: Full suite

**Verify**: `flutter test` → all pass.

## Test plan

- No new test files. Update the two existing outbox test files: `autoSync: false`
  in `setUp`, and an explicit `await repo.drainOutboxOnce();` before every
  post-sync assertion (success and failure paths alike). Preserve every
  assertion's strength and the existing test count.
- Structural pattern: the existing "full drain" / "after recovery" cases that
  already call `drainOutboxOnce()` explicitly.
- Verification: `flutter test` → all pass.

## Done criteria

ALL must hold:

- [ ] Each of the three repos has a `bool autoSync = true` constructor param and a `bool _isDraining` guard wrapping `drainOutboxOnce()`.
- [ ] `grep -rn "await drainOutboxOnce" lib/repositories/{list,finance,recipe}_repository.dart` → no matches; `grep -rn "if (_autoSync) unawaited(drainOutboxOnce())" lib/repositories/list_repository.dart` → 3 matches.
- [ ] `grep -rn "autoSync: false" test/repositories/list_repository_outbox_test.dart test/repositories/finance_repository_test.dart` → at least 1 match each.
- [ ] `dart analyze lib/` → `2 issues found.`, no new issues.
- [ ] `flutter test` exits 0; no test deleted or assertion weakened (same test count as before).
- [ ] No files outside the in-scope list modified (`git status`), in particular not any provider or screen.
- [ ] `plans/README.md` status row for 001 updated.

## STOP conditions

Stop and report (do not improvise) if:
- The "Current state" line numbers/excerpts don't match the live code (drift).
- A UI screen depends on an `*OfflineFirst` method's returned object carrying a
  **server** ID synchronously — report which screen.
- After Step 3, a test still fails for a reason that is NOT "needs an explicit
  drain before a post-sync assertion" (e.g. the guard changed an assertion's
  outcome unexpectedly) — report the specific failure.
- Making the guard wrap `drainOutboxOnce()` would require changing a method
  signature other than adding the constructor param — report it.

## Maintenance notes

- New offline-first writes should follow: optimistic local write →
  `enqueueOutbox` → `if (_autoSync) unawaited(drainOutboxOnce());`, and the
  repo's `drainOutboxOnce()` must keep the `_isDraining` guard.
- `chore_repository`/`pinwall_repository` deliberately keep their existing
  shape (no guard / no `autoSync`); if they later get failure-path tests or
  show double-send symptoms, apply the same guard there.
- Plan 002 extracts the drain *loop* into `OutboxDrainer`; the `_isDraining`
  guard stays in each repo's `drainOutboxOnce()` wrapper around the
  `OutboxDrainer.drain(...)` call — keep it when 002 lands.
- Optional follow-up (not here): lowering the 30s Dio timeout
  (`api_config.dart`) so background drain attempts on dead links give up sooner.
