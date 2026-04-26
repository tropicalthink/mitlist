import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/list_models.dart';

part 'app_database.g.dart';

class ListsTable extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().named('group_id')();
  TextColumn get name => text()();
  TextColumn get type => text()();
  IntColumn get itemCount => integer().named('item_count').nullable()();
  TextColumn get itemPreviewJson =>
      text().named('item_preview_json').withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class ListItemsTable extends Table {
  TextColumn get id => text()();
  TextColumn get listId => text().named('list_id')();
  TextColumn get name => text()();
  IntColumn get quantity => integer()();
  TextColumn get unit => text()();
  BoolColumn get checked => boolean()();
  IntColumn get position => integer()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class OutboxOps extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get type => text()();
  TextColumn get payloadJson => text().named('payload_json')();
  TextColumn get idempotencyKey =>
      text().named('idempotency_key').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get lastAttemptAt =>
      dateTime().named('last_attempt_at').nullable()();
  IntColumn get attemptCount =>
      integer().named('attempt_count').withDefault(const Constant(0))();
  TextColumn get lastError => text().named('last_error').nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class Conflicts extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get entityType => text().named('entity_type')();
  TextColumn get entityId => text().named('entity_id')();
  TextColumn get localPayloadJson => text().named('local_payload_json')();
  TextColumn get serverPayloadJson => text().named('server_payload_json')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get resolvedAt => dateTime().named('resolved_at').nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

@DriftDatabase(tables: [ListsTable, ListItemsTable, OutboxOps, Conflicts])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        beforeOpen: (details) async {
          await customStatement('pragma foreign_keys = ON;');
        },
      );

  Stream<List<ListsTableData>> watchListsByGroup(String groupId) {
    return (select(listsTable)..where((t) => t.groupId.equals(groupId))).watch();
  }

  Future<List<ListsTableData>> getListsByGroupOnce(String groupId) {
    return (select(listsTable)..where((t) => t.groupId.equals(groupId))).get();
  }

  Stream<List<ListItemsTableData>> watchItemsByList(String listId) {
    return (select(listItemsTable)..where((t) => t.listId.equals(listId))).watch();
  }

  Future<List<ListItemsTableData>> getItemsByListOnce(String listId) {
    return (select(listItemsTable)..where((t) => t.listId.equals(listId))).get();
  }

  Future<void> upsertListsRows(Iterable<ListsTableCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(listsTable, rows.toList(growable: false));
    });
  }

  Future<void> upsertListItemsRows(Iterable<ListItemsTableCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(listItemsTable, rows.toList(growable: false));
    });
  }

  Future<void> deleteItemsForList(String listId) async {
    await (delete(listItemsTable)..where((t) => t.listId.equals(listId))).go();
  }

  Future<void> enqueueOutbox({
    required String id,
    required String type,
    required Map<String, dynamic> payload,
    String? idempotencyKey,
  }) async {
    await into(outboxOps).insert(
      OutboxOpsCompanion.insert(
        id: id,
        type: type,
        payloadJson: jsonEncode(payload),
        idempotencyKey: Value(idempotencyKey),
        createdAt: DateTime.now(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<List<OutboxOp>> getOutboxBatch({int limit = 50}) {
    return (select(outboxOps)
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<void> markOutboxAttempt(String id, {String? error}) async {
    await (update(outboxOps)..where((t) => t.id.equals(id))).write(
      OutboxOpsCompanion(
        lastAttemptAt: Value(DateTime.now()),
        attemptCount: const Value.absent(),
        lastError: Value(error),
      ),
    );
    await customUpdate(
      'UPDATE outbox_ops SET attempt_count = attempt_count + 1 WHERE id = ?',
      variables: [Variable<String>(id)],
      updates: {outboxOps},
    );
  }

  Future<void> deleteOutboxOp(String id) async {
    await (delete(outboxOps)..where((t) => t.id.equals(id))).go();
  }

  Future<void> rewriteOutboxPayloadIds({
    required String oldId,
    required String newId,
  }) async {
    // Best-effort rewrite for queued ops referencing temp ids.
    await customUpdate(
      'UPDATE outbox_ops SET payload_json = replace(payload_json, ?, ?) WHERE payload_json LIKE ?',
      variables: [
        Variable<String>(oldId),
        Variable<String>(newId),
        Variable<String>('%$oldId%'),
      ],
      updates: {outboxOps},
    );
  }

  Future<void> replaceTempItemId({
    required String tempId,
    required ListItem server,
  }) async {
    await (delete(listItemsTable)..where((t) => t.id.equals(tempId))).go();
    await upsertListItemsRows([
      ListItemsTableCompanion(
        id: Value(server.id),
        listId: Value(server.listId),
        name: Value(server.name),
        quantity: Value(server.quantity),
        unit: Value(server.unit),
        checked: Value(server.checked),
        position: Value(server.position),
        createdAt: Value(server.createdAt),
        updatedAt: Value(server.updatedAt),
      )
    ]);
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'mitlist_db',
    native: const DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
    ),
    web: DriftWebOptions(
      // Served from `web/sqlite3.wasm` (copied from pub cache).
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      // Compiled from `web/drift_worker.dart`.
      driftWorker: Uri.parse('drift_worker.dart.js'),
    ),
  );
}

