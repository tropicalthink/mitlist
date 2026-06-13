# Plan 002: Extract one shared `OutboxDrainer`; collapse 5 duplicated drain loops

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. This
> is a **behavior-preserving refactor** — the drain logic must behave
> identically after each step. If anything in "STOP conditions" occurs, stop
> and report. When done, update the status row for this plan in
> `plans/README.md`.
>
> **Drift check (run first, from `frontend/`)**:
> `git diff --stat 6c868661..HEAD -- lib/repositories/ lib/storage/app_database.dart`
> If in-scope files changed since this plan was written, compare the "Current
> state" excerpts against the live code; on a mismatch, treat it as a STOP
> condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (touches all five repositories' sync paths; must stay behavior-identical)
- **Depends on**: none (do plan 001 first if both are queued, to keep diffs clean)
- **Category**: tech-debt
- **Planned at**: commit `6c868661`, 2026-06-13

## Why this matters

Five repositories each hand-roll the **same** outbox drain loop: fetch a batch,
decode the payload JSON, `switch` on op type, on success delete the op, and in a
single `catch (e)` block call `markOutboxAttempt(op.id, error: 'Something went
wrong.')` then `return`. The loops are byte-for-byte similar
(`list_repository.dart:238-281`, `finance_repository.dart:146-179`,
`recipe_repository.dart:121-154`, `chore_repository.dart:149-196`,
`pinwall_repository.dart:57-97`).

Plan 003 needs to change that `catch` block (to classify transient vs permanent
failures and stop head-of-line blocking). With five copies, that's five edits
and five chances to diverge. This plan extracts the loop into **one**
`OutboxDrainer` so 003 — and every future change to drain semantics — is a
single change point. No behavior changes here; this is pure extraction.

## Current state

The shared shape, per repo, is:
```dart
Future<void> drainOutboxOnce() async {
  final batch = await _db.getOutboxBatchByTypes([<types>], limit: 25);
  if (batch.isEmpty) return;

  for (final op in batch) {
    Map<String, dynamic> payload;
    try {
      payload = (jsonDecode(op.payloadJson) as Map).cast<String, dynamic>();
    } catch (_) {
      await _db.deleteOutboxOp(op.id);
      continue;
    }
    try {
      switch (op.type) {
        case '<typeA>': ... await _db.deleteOutboxOp(op.id); break;
        // ...
      }
    } catch (e) {
      await _db.markOutboxAttempt(op.id, error: 'Something went wrong.');
      return;
    }
  }
}
```

**Important per-repo variations the refactor must preserve:**

1. **`ListRepository` re-reads each op from the DB before processing**
   (`list_repository.dart:247-252`): `final freshOp = await _db.getOutboxOpById(op.id);`
   and uses `freshOp.payloadJson`. This is load-bearing — `_syncCreateItem`
   rewrites temp IDs in *other* queued ops' payloads
   (`rewriteOutboxPayloadIds`), and a later op in the same pass must read its
   rewritten payload. If `freshOp` is null (deleted by a concurrent drain), it
   `continue`s. The shared drainer MUST re-read fresh for every repo (it is
   harmless for the others — they just re-read the same row).
2. **Each `case` deletes its own op on success** (e.g. `await _db.deleteOutboxOp(op.id);`).
   Keep that responsibility in the per-op handler, not the drainer.
3. **`PinwallRepository` calls `refreshPosts(...)` after each successful op**
   inside the case body — that stays in its handler.
4. The op types per repo:
   - list: `createItem`, `updateItem`, `deleteItem`
   - finance: `createExpense`, `updateExpense`, `deleteExpense`
   - recipe: `createRecipe`, `updateRecipe`, `deleteRecipe`
   - chore: `completeChore`, `skipChore`, `rescheduleChore`, `undoChore`
   - pinwall: `createPinwallPost`, `deletePinwallPost`

Relevant DB methods already exist on `AppDatabase`
(`lib/storage/app_database.dart`):
`getOutboxBatchByTypes`, `getOutboxOpById`, `deleteOutboxOp`,
`markOutboxAttempt`. The op model type is `OutboxOp` (generated;
`import '../storage/app_database.dart';` exposes it).

Convention: repositories are plain classes constructed with `AppDatabase _db`
and a remote service; no Riverpod inside them. Match that.

## Commands you will need

| Purpose   | Command (from `frontend/`)                          | Expected |
|-----------|------------------------------------------------------|----------|
| Analyze   | `dart analyze lib/`                                  | `2 issues found.` (pre-existing); no new issues |
| Tests     | `flutter test`                                       | all pass |
| Sync tests| `flutter test test/repositories/ test/services/outbox_coordinator_test.dart` | all pass |

## Scope

**In scope**:
- `lib/repositories/outbox_drainer.dart` (create)
- `lib/repositories/list_repository.dart`
- `lib/repositories/finance_repository.dart`
- `lib/repositories/recipe_repository.dart`
- `lib/repositories/chore_repository.dart`
- `lib/repositories/pinwall_repository.dart`
- `test/repositories/outbox_drainer_test.dart` (create)

**Out of scope** (do NOT touch):
- `lib/storage/app_database.dart` — all needed DB methods already exist. Do not
  add columns or change the schema in this plan.
- The `catch` *semantics* — keep `markOutboxAttempt(..., 'Something went
  wrong.')` + `return` exactly as today. **Changing it is plan 003's job.** If
  you "improve" the error handling here you will collide with 003.
- `_sync*` handler bodies' logic, the `*OfflineFirst` write methods, SSE code.

## Git workflow

- Branch: `advisor/002-shared-outbox-drainer`.
- Commit per step (the codebase stays green between steps).
- Conventional Commits, e.g. `refactor: extract shared OutboxDrainer`.

## Steps

### Step 1: Confirm the baseline is green

**Verify**: `flutter test test/repositories/ test/services/outbox_coordinator_test.dart`
→ all pass. If anything fails here, STOP — the baseline is broken and this
refactor cannot be validated.

### Step 2: Create `OutboxDrainer`

Create `lib/repositories/outbox_drainer.dart` with this shape (preserving every
variation noted in "Current state"):

```dart
import 'dart:convert';

import '../storage/app_database.dart';

/// Handles one outbox op. Receives the freshly re-read op and its decoded
/// payload. MUST delete the op from the outbox on success (call
/// `db.deleteOutboxOp(op.id)`), mirroring the per-case behavior of the old
/// hand-rolled drain loops. Throwing signals a sync failure for that op.
typedef OutboxOpHandler = Future<void> Function(
  OutboxOp op,
  Map<String, dynamic> payload,
);

/// Shared outbox drain loop, extracted from the five repositories so that
/// failure-handling semantics live in exactly one place.
///
/// Behavior is identical to the previous per-repository loops:
///   * fetch a batch (ordered, backoff-aware) via [AppDatabase.getOutboxBatchByTypes]
///   * re-read each op fresh (so temp-ID rewrites done by a preceding handler
///     in the same pass are visible — required by ListRepository)
///   * decode payload JSON; on decode failure, drop the op and continue
///   * unknown op type -> drop the op and continue
///   * on handler success the handler itself has deleted the op
///   * on handler failure: mark an attempt and STOP the pass (head-of-line),
///     exactly as before. (Plan 003 changes this single block.)
class OutboxDrainer {
  final AppDatabase _db;
  const OutboxDrainer(this._db);

  Future<void> drain({
    required List<String> types,
    required Map<String, OutboxOpHandler> handlers,
    int limit = 25,
  }) async {
    final batch = await _db.getOutboxBatchByTypes(types, limit: limit);
    if (batch.isEmpty) return;

    for (final op in batch) {
      // Re-read so handlers see any temp-ID rewrites from this same pass.
      final fresh = await _db.getOutboxOpById(op.id);
      if (fresh == null) continue; // deleted by a concurrent drain

      Map<String, dynamic> payload;
      try {
        payload = (jsonDecode(fresh.payloadJson) as Map).cast<String, dynamic>();
      } catch (_) {
        await _db.deleteOutboxOp(op.id);
        continue;
      }

      final handler = handlers[fresh.type];
      if (handler == null) {
        await _db.deleteOutboxOp(op.id);
        continue;
      }

      try {
        await handler(fresh, payload);
      } catch (e) {
        // PLAN 003 will replace this block with error classification.
        await _db.markOutboxAttempt(op.id, error: 'Something went wrong.');
        return;
      }
    }
  }
}
```

**Verify**: `dart analyze lib/repositories/outbox_drainer.dart` → no issues.

### Step 3: Migrate `ListRepository` first (the trickiest, exercises the fresh re-read)

In `lib/repositories/list_repository.dart`, replace the body of
`drainOutboxOnce()` with a delegation to `OutboxDrainer`. **If plan 001 has
landed**, `drainOutboxOnce()` is wrapped in an `if (_isDraining) return;
_isDraining = true; try { ... } finally { _isDraining = false; }` guard — KEEP
that guard wrapper and replace only the `for (final op in batch)` loop *inside*
the `try` with the `OutboxDrainer(_db).drain(...)` call.
Construct an `OutboxDrainer(_db)` (a field `late final _drainer = OutboxDrainer(_db);`
or a local) and call:

```dart
Future<void> drainOutboxOnce() async {
  await OutboxDrainer(_db).drain(
    types: const ['createItem', 'updateItem', 'deleteItem'],
    handlers: {
      'createItem': (op, payload) => _syncCreateItem(op.id, payload),
      'updateItem': (op, payload) => _syncUpdateItem(op.id, payload),
      'deleteItem': (op, payload) => _syncDeleteItem(op.id, payload),
    },
  );
}
```

The existing `_syncCreateItem` / `_syncUpdateItem` / `_syncDeleteItem` already
take `(String opId, Map<String,dynamic> payload)` and already delete the op on
success — keep them unchanged. Add `import 'outbox_drainer.dart';`.

The old loop's manual `getOutboxOpById` re-read is now done by the drainer, so
remove the local `freshOp` plumbing from the deleted loop body (the handlers
already receive the fresh payload).

**Verify**:
`flutter test test/repositories/list_repository_outbox_test.dart` → all pass
(this suite specifically tests the temp-ID-rewrite-across-ops behavior; if it
passes, the fresh re-read is preserved).

### Step 4: Migrate the other four repositories

Apply the same delegation pattern to each, mapping each `case` to a handler.
Keep handler bodies identical to the current `case` bodies (including the
`await _db.deleteOutboxOp(...)` on success and pinwall's `refreshPosts(...)`).

- `finance_repository.dart`: types `createExpense`/`updateExpense`/`deleteExpense`
  → `_syncCreateExpense`/`_syncUpdateExpense`/`_syncDeleteExpense`.
- `recipe_repository.dart`: types `createRecipe`/`updateRecipe`/`deleteRecipe`
  → `_syncCreate`/`_syncUpdate`/`_syncDelete`.
- `chore_repository.dart`: types `completeChore`/`skipChore`/`rescheduleChore`/
  `undoChore`. These have **inline** case bodies (no `_sync*` methods). Wrap
  each in a handler closure, e.g.:
  ```dart
  'completeChore': (op, payload) async {
    await _remote.completeChore(payload['choreId'] as String);
    await _db.deleteOutboxOp(op.id);
  },
  'skipChore': (op, payload) async {
    await _remote.skipChore(payload['choreId'] as String,
        skipReason: payload['reason'] as String?);
    await _db.deleteOutboxOp(op.id);
  },
  // rescheduleChore, undoChore likewise — copy the exact current logic.
  ```
- `pinwall_repository.dart`: types `createPinwallPost`/`deletePinwallPost`;
  handlers copy the current case bodies including
  `await refreshPosts(payload['groupId'] as String);` before
  `await _db.deleteOutboxOp(op.id);`.

Add `import 'outbox_drainer.dart';` to each. Each repo's `import 'dart:convert';`
may now be unused — if `dart analyze` flags it as unused, remove it; otherwise
leave it.

**Verify** after all four:
- `dart analyze lib/` → `2 issues found.` (pre-existing), no new issues.
- `flutter test test/repositories/ test/services/outbox_coordinator_test.dart` → all pass.

### Step 5: Add a focused unit test for the drainer

Create `test/repositories/outbox_drainer_test.dart`. Use the in-memory DB
pattern from the top of
`test/repositories/list_repository_outbox_test.dart`:
```dart
AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(NativeDatabase.memory(),
          closeStreamsSynchronously: true));
```
Cover, using raw `db.enqueueOutbox(...)` + handlers that record calls:
1. **Success path**: a handler that deletes the op runs; `outboxCount()` → 0.
2. **Unknown type dropped**: enqueue an op whose type is not in `handlers`;
   after `drain`, that op is deleted (`outboxCount()` → 0) and no handler ran.
3. **Malformed payload dropped**: enqueue with valid JSON but a handler is
   present; then a separate op with a payload that fails to decode — assert it's
   deleted. (To force a decode failure, insert a row with non-JSON
   `payload_json` via `db.customStatement` / direct insert, since
   `enqueueOutbox` JSON-encodes.) If forcing malformed JSON is awkward, skip
   this sub-case and note it.
4. **Failure stops the pass (head-of-line)**: two ops; the first handler
   throws. Assert the first op got an attempt recorded (`attemptCount == 1`,
   `lastError != null`) and the **second op was not processed** (its handler's
   call-count is 0). This locks in the current behavior that plan 003 will
   deliberately change.

**Verify**: `flutter test test/repositories/outbox_drainer_test.dart` → all pass.

### Step 6: Full suite

**Verify**: `flutter test` → all pass.

## Test plan

- New file `test/repositories/outbox_drainer_test.dart` (Step 5), modeled on
  `test/repositories/list_repository_outbox_test.dart`'s in-memory-DB setup.
- Existing repository + coordinator tests are the regression guard for
  behavior-preservation; they must all still pass unchanged.
- Verification: `flutter test` → all pass; the new drainer tests exist and pass.

## Done criteria

ALL must hold:

- [ ] `lib/repositories/outbox_drainer.dart` exists and exports `OutboxDrainer` + `OutboxOpHandler`.
- [ ] Each of the five repositories' `drainOutboxOnce()` delegates to `OutboxDrainer(...).drain(...)`; none contains its own `for (final op in batch)` loop anymore. Check: `grep -rn "for (final op in batch)" lib/repositories/` returns **no** matches.
- [ ] The `catch` block in `outbox_drainer.dart` still does `markOutboxAttempt(..., 'Something went wrong.')` then `return` (unchanged semantics — 003 changes it).
- [ ] `dart analyze lib/` → `2 issues found.`, no new issues.
- [ ] `flutter test` exits 0; `test/repositories/outbox_drainer_test.dart` exists with the 4 cases (or 3 + a documented skip).
- [ ] No files outside the in-scope list modified (`git status`), in particular **not** `app_database.dart`.
- [ ] `plans/README.md` status row for 002 updated.

## STOP conditions

Stop and report (do not improvise) if:
- `list_repository_outbox_test.dart` fails after Step 3 — the temp-ID re-read
  was not faithfully preserved.
- A repository's `case` body does something not captured by the handler shape
  above (e.g. accesses loop-local state) — report it rather than guessing.
- You find yourself wanting to "fix" the error handling — that is plan 003;
  stop and confirm scope.
- The baseline in Step 1 is not green.

## Maintenance notes

- After this lands, **all** outbox failure semantics live in
  `OutboxDrainer.drain`'s `catch` block — that is the single seam plan 003
  edits. Reviewers of any future drain-behavior change should expect to see it
  only in `outbox_drainer.dart`.
- New domains that need offline writes should register a handler map rather than
  copy a loop.
- The `limit: 25` batch size and the ordering/backoff live in
  `AppDatabase.getOutboxBatchByTypes` — unchanged by this plan.
