# Plan 011: Harden the offline outbox — listener lifecycle, atomic ID reconciliation, batched signals

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9c9b04f3..HEAD -- frontend/lib/services/outbox_coordinator.dart frontend/lib/repositories/list_repository.dart frontend/lib/storage/app_database.dart`
> On a mismatch with "Current state", treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (touches the sync engine; regression = silent data loss)
- **Depends on**: plans/009-frontend-test-baseline.md, plans/015-money-outbox-unit-tests.md (characterization net first)
- **Category**: bug
- **Planned at**: commit `9c9b04f3`, 2026-06-11

## Why this matters

Three defects in the offline-first write path: (1) the outbox coordinator's
connectivity listener is never stored or cancelled, so every coordinator rebuild
(its provider awaits five repository FutureProviders — any invalidation rebuilds
it) stacks another listener, firing duplicate drains per reconnect; (2) when a
locally-created item gets its server ID, the temp-ID replacement and the outbox
payload rewrite are two separate awaits — not atomic, so an op enqueued between
them can keep a dangling temp ID that fails forever on retry; (3) checking off
one list item fires 2+N sequential DB writes (purchase signal + N co-occurrence
upserts), an N+1 on the hot interaction path.

## Current state

- `frontend/lib/services/outbox_coordinator.dart:47–58` — `start()`:

  ```dart
  void start() {
    _connectivity.onStatusChange.listen((online) {
      if (online) {
        _logger.i('Connectivity restored; draining outbox');
        drain();
      }
    });
    _connectivity.isOnline().then((online) { if (online) drain(); });
  }
  ```

  `dispose()` (:97–99) cancels only `_retryTimer`. `ConnectivityService.onStatusChange`
  is a broadcast `Stream<bool>` (`frontend/lib/services/connectivity_service.dart`).
  The coordinator is built in `frontend/lib/providers/outbox_provider.dart:19–41`
  (`outboxCoordinatorProvider`, a FutureProvider that calls `coordinator.start()`
  and registers `ref.onDispose(coordinator.dispose)`).
- `frontend/lib/repositories/list_repository.dart:248–250` — `_syncCreateItem`:

  ```dart
  await _db.replaceTempItemId(tempId: tempId, server: created);
  await _db.rewriteOutboxPayloadIds(oldId: tempId, newId: created.id);
  await _db.deleteOutboxOp(opId);
  ```

- `frontend/lib/repositories/list_repository.dart:~425–460` — `_recordPurchaseSignal`
  (called on item check; best-effort try/catch): one `getListGroupId` query, one
  `insertPurchaseHistory`, then `getCheckedItemsWithCanonical(listId)` and a loop
  calling `await _db.incrementCooccurrence(...)` once per checked peer.
- `frontend/lib/storage/app_database.dart` — Drift database; transactions via
  `transaction(() async { ... })` (see `clearAllUserData()` at :722 as the in-repo
  exemplar). `incrementCooccurrence` is an upsert (`INSERT ... ON CONFLICT`)
  around :1005.
- Convention: `Logger` field `_logger`, errors logged not thrown in background paths.

## Commands you will need

| Purpose | Command (run in `frontend/`) | Expected on success |
|---------|------------------------------|---------------------|
| Deps    | `flutter pub get`            | exit 0              |
| Analyze | `dart analyze lib/`          | exit 0              |
| Tests   | `flutter test`               | all pass            |

## Scope

**In scope**:
- `frontend/lib/services/outbox_coordinator.dart`
- `frontend/lib/repositories/list_repository.dart`
- `frontend/lib/storage/app_database.dart` (only: a batched co-occurrence method
  and/or a combined transactional reconcile helper — no schema changes)
- Tests under `frontend/test/`

**Out of scope**:
- `outbox_provider.dart` provider structure (the FutureProvider chain stays).
- Outbox schema (`OutboxOps` table), drain ordering, retry/backoff policy.
- Other repositories' `_sync*` methods (same pattern may exist — report, don't fix).

## Git workflow

- Branch: `fix/outbox-hardening` off `new-main-fr`.
- Conventional commits, one per defect.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Store and cancel the connectivity subscription

In `OutboxCoordinator`: add `StreamSubscription<bool>? _connectivitySub;`, assign
it in `start()`, cancel it in `dispose()` (alongside `_retryTimer`). Make
`start()` idempotent: cancel any existing subscription before re-listening.

**Verify**: `dart analyze lib/` → exit 0; `grep -n "_connectivitySub" frontend/lib/services/outbox_coordinator.dart` → ≥3 matches (declare, assign, cancel).

### Step 2: Make ID reconciliation atomic

Wrap the temp-ID replacement and outbox rewrite in one Drift transaction. Either
inline in `_syncCreateItem`:

```dart
await _db.transaction(() async {
  await _db.replaceTempItemId(tempId: tempId, server: created);
  await _db.rewriteOutboxPayloadIds(oldId: tempId, newId: created.id);
});
await _db.deleteOutboxOp(opId);
```

or as a named `AppDatabase.reconcileTempItemId(...)` method if `transaction()`
isn't callable from the repository (Drift exposes it on the database object —
check how `list_repository.dart` holds `_db`). Keep `deleteOutboxOp` outside the
transaction (op deletion after a successful rewrite is the existing semantic).

**Verify**: `dart analyze lib/` → exit 0.

### Step 3: Batch the co-occurrence writes

Add an `AppDatabase.incrementCooccurrences(...)` (plural) that performs all N
upserts inside one transaction (or a single multi-VALUES upsert statement —
either is fine; transaction is simpler and keeps the existing per-pair SQL).
Replace the loop in `_recordPurchaseSignal` with one call. Keep the
fire-and-forget try/catch semantics.

**Verify**: `dart analyze lib/` → exit 0.

### Step 4: Tests

See Test plan; run the full suite.

**Verify**: `flutter test` → all pass.

## Test plan

In the test file(s) created by plan 015 (or a new
`frontend/test/services/outbox_coordinator_test.dart` if 015's layout differs),
using the in-memory-DB harness pattern from `frontend/test/frontend_flows_test.dart:~995`:

1. Coordinator: construct with a fake `ConnectivityService` (subclass or a small
   hand-rolled fake exposing a controllable `StreamController<bool>`), call
   `start()` twice, emit one online event → assert `drain()` work happens once
   (observable via outbox op consumption or a counting fake repo).
2. Reconciliation: enqueue two ops where the second references the first's temp
   ID; simulate the create sync; assert no outbox payload still contains the
   temp ID afterward.
3. Co-occurrence: seed a list with 3 checked canonical items, record a purchase
   signal, assert co-occurrence rows exist for all pairs (behavior unchanged).

## Done criteria

- [ ] `dart analyze lib/` exits 0; `flutter test` exits 0 (incl. new tests)
- [ ] Subscription stored + cancelled; `start()` idempotent
- [ ] Reconciliation runs in a transaction (grep: `transaction` near `replaceTempItemId`)
- [ ] No per-peer `await _db.incrementCooccurrence(` loop remains in `list_repository.dart`
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `transaction()` is not reachable from the repository without restructuring DI.
- Plan 015's tests fail BEFORE your changes (broken baseline — its problem, not yours).
- You find drain-ordering or idempotency-key logic that the transactional change
  would alter — report before proceeding.

## Maintenance notes

- The same unstored-listener pattern may exist elsewhere (`grep -rn "\.listen(" frontend/lib/services/`);
  plan 017's `cancel_subscriptions` lint will catch future cases.
- Reviewer: scrutinize that `deleteOutboxOp` stays OUTSIDE the reconcile
  transaction and that drain order (lists → recipes → finance → …) is untouched.
