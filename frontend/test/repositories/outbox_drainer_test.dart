import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/repositories/outbox_drainer.dart';
import 'package:mitlist/repositories/outbox_error_classifier.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/fakes.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

void main() {
  group('OutboxDrainer —', () {
    late AppDatabase db;

    setUp(() {
      db = _memoryDb();
    });

    tearDown(() => db.close());

    // -------------------------------------------------------------------------
    // Case 1: success path — handler deletes op, queue drains to empty.
    // -------------------------------------------------------------------------
    test('success path: handler deletes op, outboxCount becomes 0', () async {
      await db.enqueueOutbox(
        id: 'op-1',
        type: 'doThing',
        payload: {'k': 'v'},
      );

      var calls = 0;
      await OutboxDrainer(db).drain(
        types: const ['doThing'],
        handlers: {
          'doThing': (op, payload) async {
            calls += 1;
            await db.deleteOutboxOp(op.id);
          },
        },
      );

      expect(calls, equals(1));
      expect(await db.outboxCount(), equals(0));
    });

    // -------------------------------------------------------------------------
    // Case 2: unknown type dropped — op deleted, no handler runs.
    // -------------------------------------------------------------------------
    test('unknown type dropped without running a handler', () async {
      await db.enqueueOutbox(
        id: 'op-unknown',
        type: 'mysteryType',
        payload: {'k': 'v'},
      );

      var calls = 0;
      await OutboxDrainer(db).drain(
        types: const ['mysteryType'],
        handlers: {
          'someOtherType': (op, payload) async {
            calls += 1;
          },
        },
      );

      expect(calls, equals(0));
      expect(await db.outboxCount(), equals(0),
          reason: 'op with no matching handler should be dropped');
    });

    // -------------------------------------------------------------------------
    // Case 3: malformed payload dropped.
    //
    // enqueueOutbox JSON-encodes, so we insert a raw row with non-JSON
    // payload_json directly to force the decode path.
    // -------------------------------------------------------------------------
    test('malformed payload dropped', () async {
      await db.into(db.outboxOps).insert(
            OutboxOpsCompanion.insert(
              id: 'op-bad',
              type: 'doThing',
              payloadJson: 'this is not json{',
              createdAt: DateTime.now(),
            ),
          );

      var calls = 0;
      await OutboxDrainer(db).drain(
        types: const ['doThing'],
        handlers: {
          'doThing': (op, payload) async {
            calls += 1;
          },
        },
      );

      expect(calls, equals(0));
      expect(await db.outboxCount(), equals(0),
          reason: 'op with malformed payload should be dropped');
    });

    // -------------------------------------------------------------------------
    // Case 4: transient failure stops the pass (head-of-line). First handler
    // throws a transient (503) → first op attemptCount==1, lastError set, and
    // the SECOND op is NOT processed. (Permanent failures behave differently —
    // see the plan-003 cases below.)
    // -------------------------------------------------------------------------
    test('transient failure stops the pass: second op not processed', () async {
      await db.enqueueOutbox(
        id: 'op-first',
        type: 'doThing',
        payload: {'order': 1},
      );
      // Ensure deterministic ordering by createdAt.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await db.enqueueOutbox(
        id: 'op-second',
        type: 'doThing',
        payload: {'order': 2},
      );

      var secondCalls = 0;
      await OutboxDrainer(db).drain(
        types: const ['doThing'],
        handlers: {
          'doThing': (op, payload) async {
            if (payload['order'] == 1) {
              throw fakeDioException(statusCode: 503);
            }
            secondCalls += 1;
            await db.deleteOutboxOp(op.id);
          },
        },
      );

      expect(secondCalls, equals(0),
          reason: 'second op must not run after first op fails transiently');

      final ops = await db.getOutboxBatch(limit: 10);
      final first = ops.firstWhere((o) => o.id == 'op-first');
      expect(first.attemptCount, equals(1));
      expect(first.lastError, isNotNull);

      // Both ops still present (nothing deleted).
      expect(await db.outboxCount(), equals(2));
    });

    // -------------------------------------------------------------------------
    // Plan 003 — Case A: permanent failure dead-letters AND does not block the
    // queue. First op throws 422 (permanent) → dead-lettered; second op still
    // runs and is deleted. KEY regression test vs head-of-line blocking.
    // -------------------------------------------------------------------------
    test('permanent failure dead-letters and does not block the queue',
        () async {
      await db.enqueueOutbox(
        id: 'op-first',
        type: 'doThing',
        payload: {'order': 1},
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await db.enqueueOutbox(
        id: 'op-second',
        type: 'doThing',
        payload: {'order': 2},
      );

      var secondCalls = 0;
      await OutboxDrainer(db).drain(
        types: const ['doThing'],
        handlers: {
          'doThing': (op, payload) async {
            if (payload['order'] == 1) {
              throw fakeDioException(statusCode: 422);
            }
            secondCalls += 1;
            await db.deleteOutboxOp(op.id);
          },
        },
      );

      // First op dead-lettered: attempt_count pushed to the threshold.
      final ops = await db.getOutboxBatch(limit: 10);
      final first = ops.firstWhere((o) => o.id == 'op-first');
      expect(first.attemptCount, equals(kOutboxMaxAttempts));
      expect(await db.outboxFailedCount(), equals(1));
      expect(await db.outboxPendingCount(), equals(0),
          reason: 'dead-lettered op is excluded from pending');

      // Second op still ran and was deleted.
      expect(secondCalls, equals(1));
      expect(ops.where((o) => o.id == 'op-second'), isEmpty);
    });

    // -------------------------------------------------------------------------
    // Plan 003 — Case B: transient failure records one attempt and stops pass.
    // First op throws 503 (transient) → attempt_count==1, second op NOT run.
    // -------------------------------------------------------------------------
    test('transient failure records one attempt and stops the pass', () async {
      await db.enqueueOutbox(
        id: 'op-first',
        type: 'doThing',
        payload: {'order': 1},
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await db.enqueueOutbox(
        id: 'op-second',
        type: 'doThing',
        payload: {'order': 2},
      );

      var secondCalls = 0;
      await OutboxDrainer(db).drain(
        types: const ['doThing'],
        handlers: {
          'doThing': (op, payload) async {
            if (payload['order'] == 1) {
              throw fakeDioException(statusCode: 503);
            }
            secondCalls += 1;
            await db.deleteOutboxOp(op.id);
          },
        },
      );

      final ops = await db.getOutboxBatch(limit: 10);
      final first = ops.firstWhere((o) => o.id == 'op-first');
      expect(first.attemptCount, equals(1));
      expect(first.lastError, isNotNull);
      expect(secondCalls, equals(0),
          reason: 'transient failure stops the pass (head-of-line)');
    });

    // -------------------------------------------------------------------------
    // Plan 003 — Case C: non-Dio exception is permanent (dead-letter).
    // -------------------------------------------------------------------------
    test('non-Dio exception is permanent', () async {
      await db.enqueueOutbox(
        id: 'op-1',
        type: 'doThing',
        payload: {'k': 'v'},
      );

      await OutboxDrainer(db).drain(
        types: const ['doThing'],
        handlers: {
          'doThing': (op, payload) async {
            throw StateError('x');
          },
        },
      );

      final ops = await db.getOutboxBatch(limit: 10);
      expect(ops.first.attemptCount, equals(kOutboxMaxAttempts));
    });

    // -------------------------------------------------------------------------
    // Plan 004 — Case D: a 409 records a conflict, removes the op, keeps going.
    // -------------------------------------------------------------------------
    test('409 records a conflict, drops the op, and continues the queue',
        () async {
      await db.enqueueOutbox(
        id: 'op-conflict',
        type: 'updateItem',
        payload: {
          'listId': 'l1',
          'itemId': 'i1',
          'patch': {'name': 'mine'}
        },
        entityType: 'listItem',
        entityId: 'i1',
      );
      await db.enqueueOutbox(id: 'op-next', type: 'updateItem', payload: {});

      var nextRan = false;
      await OutboxDrainer(db).drain(
        types: const ['updateItem'],
        handlers: {
          'updateItem': (op, payload) async {
            if (op.id == 'op-conflict') {
              throw fakeDioException(
                statusCode: 409,
                data: {
                  'error': 'conflict',
                  'current': {'id': 'i1', 'name': 'theirs'},
                },
              );
            }
            nextRan = true;
            await db.deleteOutboxOp(op.id);
          },
        },
      );

      expect(await db.conflictCount(), 1);
      expect(await db.getOutboxOpById('op-conflict'), isNull,
          reason: 'conflicting op is removed (stops retrying)');
      expect(nextRan, isTrue, reason: 'queue keeps draining past the conflict');

      final conflicts = await db.getConflicts();
      expect(conflicts.single.serverPayloadJson, contains('theirs'));
      expect(conflicts.single.localPayloadJson, contains('mine'));
    });
  });
}
