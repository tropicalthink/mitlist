import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/storage/app_database.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

void main() {
  late AppDatabase db;

  setUp(() => db = _memoryDb());
  tearDown(() => db.close());

  Future<void> deadLetter(String id, {String type = 'updateItem'}) async {
    await db.enqueueOutbox(
      id: id,
      type: type,
      payload: {'listId': 'l1', 'itemId': 'i1'},
      entityType: 'listItem',
      entityId: 'i1',
    );
    await db.markOutboxPermanentFailure(id, error: 'boom', threshold: 10);
  }

  group('failed outbox op helpers —', () {
    test('getFailedOutboxOps returns only dead-lettered ops', () async {
      await deadLetter('failed-1');
      await db.enqueueOutbox(
        id: 'pending-1',
        type: 'updateItem',
        payload: {'k': 'v'},
      );

      final failed = await db.getFailedOutboxOps();
      expect(failed.map((o) => o.id), ['failed-1']);
      expect(await db.outboxFailedCount(), 1);
    });

    test('resetFailedOutboxOps(id:) re-arms a single op for drain', () async {
      await deadLetter('failed-1');
      await deadLetter('failed-2');

      await db.resetFailedOutboxOps(id: 'failed-1');

      expect(await db.outboxFailedCount(), 1); // only failed-2 still failed
      final rearmed =
          await db.getOutboxBatchByTypes(const ['updateItem'], maxAttempts: 10);
      expect(rearmed.map((o) => o.id), contains('failed-1'));
      expect(rearmed.map((o) => o.id), isNot(contains('failed-2')));
    });

    test('resetFailedOutboxOps() re-arms all failed ops', () async {
      await deadLetter('failed-1');
      await deadLetter('failed-2');

      await db.resetFailedOutboxOps();

      expect(await db.outboxFailedCount(), 0);
      final fresh = await db.getOutboxOpById('failed-1');
      expect(fresh!.attemptCount, 0);
      expect(fresh.lastError, isNull);
    });

    test('deleteLocalEntity removes the optimistic listItem row', () async {
      await db.upsertListItemsRows([
        ListItemsTableCompanion.insert(
          id: 'i1',
          listId: 'l1',
          name: 'Milk',
          quantity: 1,
          unit: '',
          checked: false,
          position: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
      expect(await db.getItemsByListOnce('l1'), hasLength(1));

      await db.deleteLocalEntity('listItem', 'i1');

      expect(await db.getItemsByListOnce('l1'), isEmpty);
    });
  });
}
