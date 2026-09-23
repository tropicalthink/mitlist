import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/fakes.dart';

/// Regression: checking an item off must never wedge the outbox.
///
/// The check-off path records a purchase signal from inside the item update's
/// transaction, and that signal kicks off a drain. With auto-sync on (the
/// production configuration) the drain started from inside the open
/// transaction, so its queries ran against a transaction that closed under it
/// and the repository's single-flight guard never released — every later
/// drain returned early and the banner said "Syncing" forever.
AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

Future<void> _insertList(AppDatabase db, String listId,
    {String groupId = 'group-1'}) async {
  await db.upsertListsRows([
    ListsTableCompanion(
      id: drift.Value(listId),
      groupId: drift.Value(groupId),
      name: const drift.Value('My List'),
      type: const drift.Value('shopping'),
      createdAt: drift.Value(DateTime.utc(2026, 1, 1)),
      updatedAt: drift.Value(DateTime.utc(2026, 1, 1)),
    ),
  ]);
}

Future<void> _insertItem(AppDatabase db, String listId, String id, String name,
    {String? canonicalItemId}) {
  return db.upsertListItemsRows([
    ListItemsTableCompanion(
      id: drift.Value(id),
      listId: drift.Value(listId),
      name: drift.Value(name),
      quantity: const drift.Value(1.0),
      unit: const drift.Value(''),
      checked: const drift.Value(false),
      position: const drift.Value(0),
      canonicalItemId: drift.Value(canonicalItemId),
      createdAt: drift.Value(DateTime.utc(2026, 1, 5)),
      updatedAt: drift.Value(DateTime.utc(2026, 1, 5)),
    ),
  ]);
}

/// Polls until the outbox is empty or [timeout] elapses; returns the count.
Future<int> _settleOutbox(AppDatabase db,
    {Duration timeout = const Duration(seconds: 3)}) async {
  final deadline = DateTime.now().add(timeout);
  var count = await db.outboxCount();
  while (count > 0 && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    count = await db.outboxCount();
  }
  return count;
}

void main() {
  late AppDatabase db;
  late FakeListService remote;
  late ListRepository repo;

  setUp(() {
    db = _memoryDb();
    remote = FakeListService();
    // autoSync on: the production wiring, where every write drains itself.
    repo = ListRepository(db: db, remote: remote);
  });

  tearDown(() => db.close());

  test('check-off of a canonical item drains and does not wedge the outbox',
      () async {
    const listId = 'list-canonical';
    const itemId = 'item-2';
    const canonicalId = 'c0000000-0000-4000-8000-000000000001';
    await _insertList(db, listId);
    await db.into(db.canonicalItemsTable).insert(
          CanonicalItemsTableCompanion(
            id: const drift.Value(canonicalId),
            groupId: const drift.Value('group-1'),
            nameDe: const drift.Value('Milch'),
            nameEn: const drift.Value('Milk'),
            category: const drift.Value('dairy'),
            defaultUnit: const drift.Value('l'),
            isGlobal: const drift.Value(false),
            version: const drift.Value(0),
            createdAt: drift.Value(DateTime.utc(2026, 1, 1)),
            updatedAt: drift.Value(DateTime.utc(2026, 1, 1)),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
    await _insertItem(db, listId, itemId, 'Milk', canonicalItemId: canonicalId);

    await repo.updateItemOfflineFirst(
        listId, itemId, const UpdateListItemRequest(checked: true));
    expect(await _settleOutbox(db), 0);
    expect(remote.groceryPurchaseCalls, hasLength(1));

    await repo.updateItemOfflineFirst(
        listId, itemId, const UpdateListItemRequest(checked: false));
    expect(await _settleOutbox(db), 0,
        reason: 'the drain guard released after the check-off');
    expect(remote.updateItemCalls, hasLength(2));
  });

  test('a follow-up drain (the coordinator poll) empties a wedged outbox',
      () async {
    const listId = 'list-recover';
    const itemId = 'item-3';
    const canonicalId = 'c0000000-0000-4000-8000-000000000002';
    await _insertList(db, listId);
    await db.into(db.canonicalItemsTable).insert(
          CanonicalItemsTableCompanion(
            id: const drift.Value(canonicalId),
            groupId: const drift.Value('group-1'),
            nameDe: const drift.Value('Eier'),
            nameEn: const drift.Value('Eggs'),
            category: const drift.Value('dairy'),
            defaultUnit: const drift.Value(''),
            isGlobal: const drift.Value(false),
            version: const drift.Value(0),
            createdAt: drift.Value(DateTime.utc(2026, 1, 1)),
            updatedAt: drift.Value(DateTime.utc(2026, 1, 1)),
          ),
          mode: drift.InsertMode.insertOrReplace,
        );
    await _insertItem(db, listId, itemId, 'Eggs', canonicalItemId: canonicalId);

    await repo.updateItemOfflineFirst(
        listId, itemId, const UpdateListItemRequest(checked: true));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // Whatever the write-triggered drain did, an explicit drain from a plain
    // zone must finish and leave nothing queued.
    await repo.drainOutboxOnce().timeout(const Duration(seconds: 5));
    expect(await _settleOutbox(db), 0);
    expect(remote.updateItemCalls, hasLength(1));
    expect(remote.groceryPurchaseCalls, hasLength(1));
  });
}
