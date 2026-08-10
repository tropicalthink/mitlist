import 'dart:convert';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/finance_models.dart';
import 'package:mitlist/repositories/finance_repository.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/fakes.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

/// Build a minimal CreateExpenseRequest pointing to [groupId].
CreateExpenseRequest _req({
  String groupId = 'group-1',
  String payerId = 'payer-1',
  int amount = 2500, // $25.00 in cents
  int? baseAmount,
  double fxRate = 1.0,
  String currency = 'USD',
}) =>
    CreateExpenseRequest(
      groupId: groupId,
      payerId: payerId,
      amount: amount,
      baseAmount: baseAmount ?? amount,
      fxRate: fxRate,
      description: 'Groceries',
      category: 'food',
      currency: currency,
      notes: '',
      date: DateTime.utc(2026, 1, 15),
    );

void main() {
  group('FinanceRepository —', () {
    late AppDatabase db;
    late FakeFinanceService remote;
    late FinanceRepository repo;

    setUp(() {
      db = _memoryDb();
      remote = FakeFinanceService();
      repo = FinanceRepository(db: db, remote: remote, autoSync: false);
    });

    tearDown(() => db.close());

    // -------------------------------------------------------------------------
    // Case 1: createExpenseOfflineFirst while "online" (API succeeds immediately)
    // -------------------------------------------------------------------------
    test(
        'createExpenseOfflineFirst: local row written, outbox op deleted after successful drain',
        () async {
      final result = await repo.createExpenseOfflineFirst(_req());
      await repo.drainOutboxOnce();

      // Local row exists with the temp id initially returned.
      expect(result.amount, equals(2500));
      expect(result.description, equals('Groceries'));

      // After successful drain the temp row is replaced by the server row.
      final expenses = await db.getExpensesByGroupOnce('group-1');
      expect(expenses.length, equals(1));
      expect(expenses.first.id, equals(remote.serverExpenseId),
          reason: 'server ID should replace temp ID after drain');

      // Outbox should be empty after successful sync.
      final opCount = await db.outboxCount();
      expect(opCount, equals(0),
          reason: 'createExpense op should be deleted after successful sync');

      // API was called exactly once.
      expect(remote.createCalls.length, equals(1));
      expect(remote.createCalls.first.amount, equals(2500));
    });

    // -------------------------------------------------------------------------
    // Case 2: createExpenseOfflineFirst while API throws
    // -------------------------------------------------------------------------
    test(
        'createExpenseOfflineFirst: local row still written when API throws; op stays with attempt_count=1',
        () async {
      remote.throwOnCreate = fakeDioException(statusCode: 503);

      final result = await repo.createExpenseOfflineFirst(_req());
      await repo.drainOutboxOnce();
      expect(result.amount, equals(2500),
          reason: 'should return the locally created expense');

      // Local row is present (the temp id row).
      final expenses = await db.getExpensesByGroupOnce('group-1');
      expect(expenses.length, equals(1));

      // Op remains in outbox.
      final ops = await db.getOutboxBatch(limit: 10);
      final createOps = ops.where((o) => o.type == 'createExpense').toList();
      expect(createOps.length, equals(1),
          reason: 'op should remain after failed API call');

      // attempt_count should be incremented to 1.
      expect(createOps.first.attemptCount, equals(1));

      // last_error should be set.
      expect(createOps.first.lastError, isNotNull);

      // idempotency_key should be set.
      expect(createOps.first.idempotencyKey, startsWith('createExpense:'),
          reason: 'idempotency_key should be stored with the op');
    });

    // -------------------------------------------------------------------------
    // Case 3: drain after API recovers
    // -------------------------------------------------------------------------
    test(
        'drainOutboxOnce after recovery: op completed and deleted; no duplicate expense',
        () async {
      // First call: API throws.
      remote.throwOnCreate = fakeDioException(statusCode: 503);
      await repo.createExpenseOfflineFirst(_req());
      await repo.drainOutboxOnce(); // consumes the one-shot throw (attempt 1)

      // Verify op is stuck.
      expect(await db.outboxCount(), equals(1));

      // We need to clear the backoff to let the op retry immediately.
      // getOutboxBatchByTypes has a 5s minBackoff; we work around it by
      // inserting a new op with a past lastAttemptAt via raw customUpdate.
      //
      // KNOWN BUG: There is no public API to reset lastAttemptAt for a retry
      // in tests; the 5-second minBackoff in getOutboxBatchByTypes means a
      // real recovery cannot be tested without either sleeping or accessing
      // the DB internals. We directly reset lastAttemptAt below.
      await db.customUpdate(
        'UPDATE outbox_ops SET last_attempt_at = NULL',
        updates: {db.outboxOps},
      );

      // Second call: API succeeds.
      await repo.drainOutboxOnce();

      // Op deleted.
      expect(await db.outboxCount(), equals(0),
          reason: 'op should be deleted after successful retry');

      // No duplicate: exactly one expense row.
      final expenses = await db.getExpensesByGroupOnce('group-1');
      expect(expenses.length, equals(1));
      expect(expenses.first.id, equals(remote.serverExpenseId));

      // API was called twice total (once fail, once succeed).
      expect(remote.createCalls.length, equals(2));
    });

    // -------------------------------------------------------------------------
    // Case 3b: foreign-currency expense survives the outbox round-trip
    // -------------------------------------------------------------------------
    test(
        'createExpenseOfflineFirst: foreign currency baseAmount/fxRate survive enqueue then drain',
        () async {
      // €100.00 at 1.10 → $110.00 base.
      final result = await repo.createExpenseOfflineFirst(_req(
        amount: 10000,
        baseAmount: 11000,
        fxRate: 1.10,
        currency: 'EUR',
      ));

      // Optimistic local row carries the converted base amount + rate.
      expect(result.amount, equals(10000));
      expect(result.baseAmount, equals(11000));
      expect(result.fxRate, equals(1.10));
      expect(result.currency, equals('EUR'));

      // The enqueued JSON payload (drained via _syncCreateExpense) must rebuild
      // the request with the FX fields intact and forward them to the API.
      await repo.drainOutboxOnce();

      expect(remote.createCalls.length, equals(1));
      final sent = remote.createCalls.first;
      expect(sent.amount, equals(10000));
      expect(sent.baseAmount, equals(11000),
          reason: 'base_amount must survive the outbox enqueue→drain cycle');
      expect(sent.fxRate, equals(1.10),
          reason: 'fx_rate must survive the outbox enqueue→drain cycle');
      expect(sent.currency, equals('EUR'));

      // Persisted server row keeps the converted amount.
      final expenses = await db.getExpensesByGroupOnce('group-1');
      expect(expenses.length, equals(1));
      expect(expenses.first.baseAmount, equals(11000));
      expect(expenses.first.fxRate, equals(1.10));
    });

    // -------------------------------------------------------------------------
    // Case 4a: updateExpenseOfflineFirst enqueues correct op type
    // -------------------------------------------------------------------------
    test('updateExpenseOfflineFirst: correct op type enqueued', () async {
      // First create a real expense in the DB.
      const expenseId = 'exp-server-001';
      await db.upsertExpensesRows([
        ExpensesTableCompanion(
          id: const drift.Value('exp-server-001'),
          groupId: const drift.Value('group-1'),
          payerId: const drift.Value('payer-1'),
          amount: const drift.Value(1000),
          description: const drift.Value('Lunch'),
          category: const drift.Value('food'),
          currency: const drift.Value('USD'),
          notes: const drift.Value(''),
          date: drift.Value(DateTime.utc(2026, 1, 10)),
          createdAt: drift.Value(DateTime.utc(2026, 1, 10)),
        )
      ]);

      await repo.updateExpenseOfflineFirst(
        expenseId,
        const UpdateExpenseRequest(amount: 1500, description: 'Updated lunch'),
      );
      await repo.drainOutboxOnce();

      expect(remote.updateCalls.length, equals(1),
          reason: 'update API should be called during drain');

      // All ops should be cleared.
      expect(await db.outboxCount(), equals(0));
    });

    // -------------------------------------------------------------------------
    // Case 4b: deleteExpenseOfflineFirst enqueues correct op type
    // -------------------------------------------------------------------------
    test(
        'deleteExpenseOfflineFirst: local row removed and deleteExpense op enqueued then deleted',
        () async {
      const expenseId = 'exp-del-001';
      await db.upsertExpensesRows([
        ExpensesTableCompanion(
          id: const drift.Value(expenseId),
          groupId: const drift.Value('group-1'),
          payerId: const drift.Value('payer-1'),
          amount: const drift.Value(500),
          description: const drift.Value('Coffee'),
          category: const drift.Value('food'),
          currency: const drift.Value('USD'),
          notes: const drift.Value(''),
          date: drift.Value(DateTime.utc(2026, 1, 12)),
          createdAt: drift.Value(DateTime.utc(2026, 1, 12)),
        )
      ]);

      await repo.deleteExpenseOfflineFirst(expenseId);
      await repo.drainOutboxOnce();

      // Local row is gone.
      final expenses = await db.getExpensesByGroupOnce('group-1');
      expect(expenses.where((e) => e.id == expenseId), isEmpty,
          reason: 'local row should be deleted immediately');

      // Delete was sent to API.
      expect(remote.deleteCalls.contains(expenseId), isTrue);

      // Op cleaned up.
      expect(await db.outboxCount(), equals(0));
    });

    // -------------------------------------------------------------------------
    // Case 4c: deleteExpenseOfflineFirst while API throws — op remains
    // -------------------------------------------------------------------------
    test(
        'deleteExpenseOfflineFirst: when API throws, op remains with attempt_count=1',
        () async {
      const expenseId = 'exp-del-fail';
      await db.upsertExpensesRows([
        ExpensesTableCompanion(
          id: const drift.Value(expenseId),
          groupId: const drift.Value('group-1'),
          payerId: const drift.Value('payer-1'),
          amount: const drift.Value(300),
          description: const drift.Value('Tea'),
          category: const drift.Value('food'),
          currency: const drift.Value('USD'),
          notes: const drift.Value(''),
          date: drift.Value(DateTime.utc(2026, 1, 13)),
          createdAt: drift.Value(DateTime.utc(2026, 1, 13)),
        )
      ]);

      // Make delete throw by overriding noSuchMethod via a custom fake —
      // FakeFinanceService.deleteExpense does not throw by default, but we
      // can add a flag via a local subclass.
      final throwingRemote = _ThrowingDeleteFinanceService();
      final throwingRepo =
          FinanceRepository(db: db, remote: throwingRemote, autoSync: false);

      await throwingRepo.deleteExpenseOfflineFirst(expenseId);
      await throwingRepo.drainOutboxOnce();

      final ops = await db.getOutboxBatch(limit: 10);
      final deleteOps = ops.where((o) => o.type == 'deleteExpense').toList();
      expect(deleteOps.length, equals(1));
      expect(deleteOps.first.attemptCount, equals(1));
      expect(deleteOps.first.lastError, isNotNull);
    });
  });

  // Plan 006 part 1. Expenses were last-write-wins: an offline edit draining
  // after someone else's edit silently overwrote it, with no conflict and no
  // trace — and unlike a list item, a clobbered expense costs somebody money.
  group('FinanceRepository expense conflicts —', () {
    late AppDatabase db;
    late FakeFinanceService remote;
    late FinanceRepository repo;
    const expenseId = 'exp-1';
    final base = DateTime.utc(2026, 1, 10, 12);

    setUp(() async {
      db = _memoryDb();
      remote = FakeFinanceService();
      repo = FinanceRepository(db: db, remote: remote, autoSync: false);
      await db.upsertExpensesRows([
        ExpensesTableCompanion.insert(
          id: expenseId,
          groupId: 'group-1',
          payerId: 'payer-1',
          amount: 2500,
          description: 'Groceries',
          category: 'food',
          currency: 'USD',
          notes: '',
          date: DateTime.utc(2026, 1, 10),
          createdAt: DateTime.utc(2026, 1, 10),
          updatedAt: drift.Value(base),
        )
      ]);
    });

    tearDown(() => db.close());

    test('an offline edit carries the server base it was made against',
        () async {
      await repo.updateExpenseOfflineFirst(
          expenseId, const UpdateExpenseRequest(amount: 3000));

      final op = (await db.getOutboxOpsByType('updateExpense')).single;
      final payload = jsonDecode(op.payloadJson) as Map<String, dynamic>;
      expect(DateTime.parse(payload['expectedUpdatedAt'] as String),
          base.toUtc());
    });

    test('a chained edit sends no base', () async {
      await repo.updateExpenseOfflineFirst(
          expenseId, const UpdateExpenseRequest(amount: 3000));
      await repo.updateExpenseOfflineFirst(
          expenseId, const UpdateExpenseRequest(amount: 3100));

      final ops = await db.getOutboxOpsByType('updateExpense');
      final second = jsonDecode(ops.last.payloadJson) as Map<String, dynamic>;
      expect(second['expectedUpdatedAt'], isNull,
          reason: 'the chain is all ours — the local base would self-conflict');
    });

    test('a row with no known server version falls back to last-write-wins',
        () async {
      await db.upsertExpensesRows([
        ExpensesTableCompanion.insert(
          id: 'exp-local',
          groupId: 'group-1',
          payerId: 'payer-1',
          amount: 100,
          description: 'Local only',
          category: 'food',
          currency: 'USD',
          notes: '',
          date: DateTime.utc(2026, 1, 10),
          createdAt: DateTime.utc(2026, 1, 10),
        )
      ]);

      await repo.updateExpenseOfflineFirst(
          'exp-local', const UpdateExpenseRequest(amount: 200));

      final op = (await db.getOutboxOpsByType('updateExpense')).single;
      final payload = jsonDecode(op.payloadJson) as Map<String, dynamic>;
      expect(payload['expectedUpdatedAt'], isNull,
          reason: 'no server version means nothing to conflict against');
    });

    test('a 409 becomes a resolvable conflict instead of a silent clobber',
        () async {
      await repo.updateExpenseOfflineFirst(
          expenseId, const UpdateExpenseRequest(amount: 3000));

      remote.throwOnUpdate = fakeDioException(statusCode: 409, data: {
        'error': 'conflict',
        'current': {
          'id': expenseId,
          'group_id': 'group-1',
          'payer_id': 'payer-1',
          'amount': 4200,
          'description': 'Groceries (theirs)',
          'category': 'food',
          'currency': 'USD',
          'notes': '',
          'date': '2026-01-10T00:00:00Z',
          'created_at': '2026-01-10T00:00:00Z',
          'updated_at': '2026-01-11T00:00:00Z',
        },
      });

      await repo.drainOutboxOnce();

      expect(await db.conflictCount(), 1);
      final conflict = (await db.getConflicts()).single;
      expect(conflict.entityType, 'updateExpense');
      expect(conflict.serverPayloadJson, contains('theirs'));
      expect(await db.getOutboxOpById(conflict.id), isNull,
          reason: 'the conflicting op stops retrying');
    });

    test('"use theirs" replaces the local row with the server version',
        () async {
      await repo.updateExpenseOfflineFirst(
          expenseId, const UpdateExpenseRequest(amount: 3000));
      remote.throwOnUpdate = fakeDioException(statusCode: 409, data: {
        'error': 'conflict',
        'current': {
          'id': expenseId,
          'group_id': 'group-1',
          'payer_id': 'payer-1',
          'amount': 4200,
          'description': 'Theirs',
          'category': 'food',
          'currency': 'USD',
          'notes': '',
          'date': '2026-01-10T00:00:00Z',
          'created_at': '2026-01-10T00:00:00Z',
          'updated_at': '2026-01-11T00:00:00Z',
        },
      });
      await repo.drainOutboxOnce();

      await repo.resolveConflictAcceptServer((await db.getConflicts()).single);

      final expenses = await repo.getExpensesByGroupOnce('group-1');
      final row = expenses.firstWhere((e) => e.id == expenseId);
      expect(row.amount, 4200);
      expect(row.description, 'Theirs');
      expect(await db.conflictCount(), 0);
    });

    test('"keep mine" re-queues the edit rebased on the server version',
        () async {
      await repo.updateExpenseOfflineFirst(
          expenseId, const UpdateExpenseRequest(amount: 3000));
      remote.throwOnUpdate = fakeDioException(statusCode: 409, data: {
        'error': 'conflict',
        'current': {
          'id': expenseId,
          'group_id': 'group-1',
          'payer_id': 'payer-1',
          'amount': 4200,
          'description': 'Theirs',
          'category': 'food',
          'currency': 'USD',
          'notes': '',
          'date': '2026-01-10T00:00:00Z',
          'created_at': '2026-01-10T00:00:00Z',
          'updated_at': '2026-01-11T00:00:00Z',
        },
      });
      await repo.drainOutboxOnce();

      await repo.resolveConflictKeepLocal((await db.getConflicts()).single);

      final requeued = (await db.getOutboxOpsByType('updateExpense')).single;
      final payload = jsonDecode(requeued.payloadJson) as Map<String, dynamic>;
      expect(payload['patch']['amount'], 3000, reason: 'my edit survives');
      expect(payload['expectedUpdatedAt'], '2026-01-11T00:00:00Z',
          reason: 'rebased on their version so it no longer conflicts');
      expect(await db.conflictCount(), 0);
    });
  });

  group('FinanceRepository settlements —', () {
    late AppDatabase db;
    late FakeFinanceService remote;
    late FinanceRepository repo;
    const groupId = 'group-1';

    setUp(() {
      db = _memoryDb();
      remote = FakeFinanceService();
      repo = FinanceRepository(db: db, remote: remote, autoSync: false);
    });

    tearDown(() => db.close());

    Future<Settlement> record() => repo.recordSettlementOfflineFirst(
          groupId: groupId,
          req: const CreateSettlementRequest(
            fromUserId: 'me',
            toUserId: 'them',
            amount: 2500,
          ),
          createdBy: 'me',
        );

    test('recording queues it and shows it as pending immediately', () async {
      final local = await record();

      expect(local.isLocal, isTrue);
      expect(local.status, SettlementStatus.pending,
          reason: 'a recorded settlement is unconfirmed until the '
              'counterparty responds — offline changes nothing about that');

      final cached = await repo.getSettlementsOnce(groupId);
      expect(cached, hasLength(1));
      expect(cached.single.id, local.id);
      expect(await db.outboxCount(), equals(1));
    });

    test('offline load falls back to the cache instead of throwing', () async {
      await record();
      // remote.settlements stays null → listSettlements throws.

      final loaded = await repo.loadSettlements(groupId);

      expect(loaded, hasLength(1), reason: 'the tab must still render offline');
    });

    test('a server refresh does not erase a still-queued settlement', () async {
      final local = await record();
      remote.settlements = const [];

      final loaded = await repo.loadSettlements(groupId);

      expect(loaded.map((s) => s.id), contains(local.id));
    });

    test('draining replaces the local row with the server one', () async {
      final local = await record();

      await repo.drainOutboxOnce();

      final cached = await repo.getSettlementsOnce(groupId);
      expect(cached, hasLength(1), reason: 'no duplicate after sync');
      expect(cached.single.id, 'server-settlement-1');
      expect(cached.single.isLocal, isFalse,
          reason: 'only a server id makes confirm/decline reachable');
      expect(cached.map((s) => s.id), isNot(contains(local.id)));
      expect(await db.outboxCount(), equals(0));
    });

    test('cancelling an unsynced settlement drops the op without a request',
        () async {
      final local = await record();

      await repo.cancelLocalSettlement(groupId, local.id);

      expect(await repo.getSettlementsOnce(groupId), isEmpty);
      expect(await db.outboxCount(), equals(0));
      expect(remote.settlementCreateCalls, isEmpty,
          reason: 'there is nothing on the server to cancel');
    });

    test('discarding a dead-lettered settlement removes the phantom row',
        () async {
      final local = await record();

      await db.deleteLocalEntity('settlement', local.id);

      expect(await repo.getSettlementsOnce(groupId), isEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// Local helper: a FakeFinanceService whose deleteExpense always throws.
// ---------------------------------------------------------------------------
class _ThrowingDeleteFinanceService extends FakeFinanceService {
  @override
  Future<void> deleteExpense(String id) async {
    throw fakeDioException(statusCode: 503);
  }
}
