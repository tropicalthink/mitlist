import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/repositories/outbox_drainer.dart';
import 'package:mitlist/storage/app_database.dart';

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
    // Case 4: failure stops the pass (head-of-line blocking — current behavior).
    // First handler throws → first op attemptCount==1, lastError set, and the
    // SECOND op is NOT processed. Plan 003 changes this for permanent errors.
    // -------------------------------------------------------------------------
    test('failure stops the pass: second op not processed', () async {
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
              throw StateError('boom');
            }
            secondCalls += 1;
            await db.deleteOutboxOp(op.id);
          },
        },
      );

      expect(secondCalls, equals(0),
          reason: 'second op must not run after first op fails');

      final ops = await db.getOutboxBatch(limit: 10);
      final first = ops.firstWhere((o) => o.id == 'op-first');
      expect(first.attemptCount, equals(1));
      expect(first.lastError, isNotNull);

      // Both ops still present (nothing deleted).
      expect(await db.outboxCount(), equals(2));
    });
  });
}
