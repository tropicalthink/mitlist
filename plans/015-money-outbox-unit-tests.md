# Plan 015: Unit tests for the offline-first money path and outbox machinery

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9c9b04f3..HEAD -- frontend/lib/repositories/finance_repository.dart frontend/lib/repositories/list_repository.dart frontend/lib/services/outbox_coordinator.dart frontend/lib/storage/app_database.dart`
> Drift in these files is acceptable (plans 010/011/013 may land around this one)
> — but re-read the live code for any drifted excerpt before writing tests
> against it. **These are characterization tests: pin CURRENT behavior.**

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW (test-only; no production code changes)
- **Depends on**: plans/009-frontend-test-baseline.md
- **Category**: tests
- **Planned at**: commit `9c9b04f3`, 2026-06-11

## Why this matters

The offline-first write path — enqueue to outbox, drain on reconnect, reconcile
temp IDs, surface conflicts — moves the household's money and shopping data, and
has **zero dedicated tests** (the repo's 3 test files are widget-level flows).
Plan 011 wants to change this exact machinery; these tests are its regression
net and must land first. The seams already exist: repositories take `AppDatabase`
by constructor, tests already run an in-memory Drift DB, and Riverpod overrides
are established practice in this repo.

## Current state

- `frontend/lib/repositories/finance_repository.dart` — offline-first writes:
  `createExpenseOfflineFirst` (:65) writes locally + `_db.enqueueOutbox(...)`
  (:83) then `drainOutboxOnce()` (:93); same pattern for update (:117–127) and
  delete (:136–143); `drainOutboxOnce()` at :146. Read the whole file first.
- `frontend/lib/repositories/list_repository.dart` — `_syncCreateItem`
  (:~240–252): posts to API, then `replaceTempItemId` → `rewriteOutboxPayloadIds`
  → `deleteOutboxOp`. Purchase-signal logic at :~425–460.
- `frontend/lib/services/outbox_coordinator.dart` — `start()` (:47) listens to
  `ConnectivityService.onStatusChange`; `drain()` (:~60) guards with
  `_isDraining`, checks `isOnline()`, drains repos in dependency order
  (lists → recipes → finance → chores → pinwall).
- `frontend/lib/services/connectivity_service.dart` — concrete class, no
  interface; `onStatusChange` is `Stream<bool>` from a broadcast controller,
  `isOnline()` async. For fakes: it is NOT abstract — check whether
  `OutboxCoordinator` takes it by concrete type; if so, a fake must `implements
  ConnectivityService` (Dart allows implementing concrete classes) — no
  production change needed.
- `frontend/lib/storage/app_database.dart` — `OutboxOps` table (:43–55: id, type,
  payload_json, idempotency_key, created_at, last_attempt_at, attempt_count,
  last_error), `enqueueOutbox`, `markOutboxAttempt` (:444), `deleteOutboxOp`.
- Test harness exemplar — `frontend/test/frontend_flows_test.dart:~995`:

  ```dart
  final db = AppDatabase(
    drift.DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
  );
  addTearDown(() => db.close());
  ```

  with `ProviderScope(overrides: [appDatabaseProvider.overrideWithValue(db), ...])`.
- API layer: repositories call retrofit-generated services (Dio). For unit tests,
  fake at the service interface the repository holds (read the repository
  constructors to see the exact type) — hand-rolled fakes, matching how the flow
  tests already stub network.

## Commands you will need

| Purpose | Command (run in `frontend/`) | Expected on success |
|---------|------------------------------|---------------------|
| Deps    | `flutter pub get`            | exit 0              |
| Tests   | `flutter test test/repositories/ test/services/` | all pass |
| Full    | `flutter test`               | all pass            |

## Scope

**In scope** (all new files):
- `frontend/test/repositories/finance_repository_test.dart`
- `frontend/test/repositories/list_repository_outbox_test.dart`
- `frontend/test/services/outbox_coordinator_test.dart`
- `frontend/test/support/` for shared fakes (fake connectivity, fake API services)

**Out of scope**:
- ANY file under `frontend/lib/` — if a seam is missing, that's a STOP, not a refactor.
- The existing three test files.

## Git workflow

- Branch: `test/money-outbox-unit-tests` off `new-main-fr`.
- Conventional commits (`test: ...`), one per test file is fine.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Shared fakes

`frontend/test/support/fakes.dart`: `FakeConnectivityService implements
ConnectivityService` (controllable `StreamController<bool>` + settable
`isOnline` result); fake API service(s) for finance/list repositories that
record calls and return canned responses or throw `DioException` on demand.

**Verify**: `dart analyze test/` → exit 0.

### Step 2: FinanceRepository characterization

Cases (in-memory DB, fake API):
1. `createExpenseOfflineFirst` while "online": local row written, outbox op
   enqueued, drain succeeds → op deleted, server ID reconciled (assert exact
   current behavior — read the code for what reconciliation finance does).
2. Same while API throws (offline simulation): local row still written, op
   REMAINS in outbox with `attempt_count` incremented and `last_error` set.
3. Drain after API recovers: op completes and is deleted; no duplicate expense
   (idempotency_key preserved — assert the key is sent if the code does so).
4. Update + delete offline-first variants: op types enqueued correctly.

### Step 3: ListRepository temp-ID reconciliation

1. Create item offline → temp ID in local row + create op in outbox.
2. Enqueue a dependent update op referencing the temp ID.
3. Run the drain/sync; assert: local row has server ID, NO outbox payload still
   contains the temp ID, ops deleted in order.

### Step 4: OutboxCoordinator

1. `drain()` while offline → no repo drains (observable via fake/counting repos
   if constructor permits, else via outbox op counts).
2. Connectivity stream emits online → drain happens; concurrent `drain()` calls
   collapse (the `_isDraining` guard) — fire two quickly, assert single pass.
3. Pin CURRENT `start()` behavior as-is (plan 011 will change listener
   lifecycle; don't pre-assert the fix).

**Verify (each step)**: `flutter test test/<new file>` → all pass.

## Test plan

This plan is the test plan. Target: ≥12 new test cases across the 3 files.
Money amounts in fixtures are integer cents (match `lib/models/finance_models.dart`).

## Done criteria

- [ ] `flutter test` exits 0; ≥12 new cases across the three new files
- [ ] Zero modifications under `frontend/lib/` (`git status`)
- [ ] Tests run without network (fakes only) and without real files (memory DB)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- A repository's API dependency cannot be faked without changing `lib/`
  (report the exact constructor signature blocking you).
- You find an actual bug while characterizing (e.g. duplicate expense on
  re-drain) — write the test pinning the CURRENT behavior with a
  `// KNOWN BUG:` comment and report it; do not fix.

## Maintenance notes

- These tests pin pre-011 behavior; plan 011's executor will update the
  coordinator-lifecycle assertions it intentionally changes (documented there).
- Reviewer: check assertions are substantive (op counts, payload contents,
  attempt_count values) — not just "no throw".
