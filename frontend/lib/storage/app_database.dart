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
  RealColumn get quantity => real()();
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

class ExpensesTable extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().named('group_id')();
  TextColumn get payerId => text().named('payer_id')();
  IntColumn get amount => integer()();
  TextColumn get description => text()();
  TextColumn get category => text()();
  TextColumn get currency => text()();
  TextColumn get notes => text()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class FinanceSummaries extends Table {
  TextColumn get groupId => text().named('group_id')();
  TextColumn get summaryJson => text().named('summary_json')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {groupId};
}

class CurrentChoresCaches extends Table {
  TextColumn get groupId => text().named('group_id')();
  TextColumn get choresJson => text().named('chores_json')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {groupId};
}

class RecipesTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  IntColumn get prepTime => integer().named('prep_time')();
  IntColumn get cookTime => integer().named('cook_time')();
  IntColumn get servings => integer()();
  TextColumn get imageUrl => text().named('image_url').nullable()();
  BoolColumn get isPublic => boolean().named('is_public')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class PinwallPostsCaches extends Table {
  TextColumn get groupId => text().named('group_id')();
  TextColumn get postsJson => text().named('posts_json')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {groupId};
}

class HubGroupCaches extends Table {
  TextColumn get groupId => text().named('group_id')();
  TextColumn get groupJson => text().named('group_json')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {groupId};
}

class HubActivityCaches extends Table {
  TextColumn get groupId => text().named('group_id')();
  TextColumn get activitiesJson => text().named('activities_json')();
  BoolColumn get hadError => boolean().named('had_error')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {groupId};
}

@DriftDatabase(
  tables: [
    ListsTable,
    ListItemsTable,
    ExpensesTable,
    FinanceSummaries,
    CurrentChoresCaches,
    RecipesTable,
    PinwallPostsCaches,
    HubGroupCaches,
    HubActivityCaches,
    OutboxOps,
    Conflicts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // SQLite can't change column types in-place; rebuild list_items_table.
            await customStatement('''
CREATE TABLE list_items_table__new (
  id TEXT NOT NULL PRIMARY KEY,
  list_id TEXT NOT NULL,
  name TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit TEXT NOT NULL,
  checked INTEGER NOT NULL,
  position INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''');

            await customStatement('''
INSERT INTO list_items_table__new (
  id, list_id, name, quantity, unit, checked, position, created_at, updated_at
)
SELECT
  id, list_id, name, CAST(quantity AS REAL), unit, checked, position, created_at, updated_at
FROM list_items_table;
''');

            await customStatement('DROP TABLE list_items_table;');
            await customStatement(
                'ALTER TABLE list_items_table__new RENAME TO list_items_table;');
          }
        },
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

  Future<List<OutboxOp>> getOutboxBatchByTypes(
    List<String> types, {
    int limit = 50,
    Duration minBackoff = const Duration(seconds: 5),
    int maxAttempts = 10,
  }) {
    final cutoff = DateTime.now().subtract(minBackoff);
    return (select(outboxOps)
          ..where((t) =>
              t.type.isIn(types) &
              t.attemptCount.isSmallerThanValue(maxAttempts) &
              (t.lastAttemptAt.isNull() | t.lastAttemptAt.isSmallerThanValue(cutoff)))
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

  Future<int> outboxCount() async {
    final result = await customSelect(
      'SELECT COUNT(*) AS c FROM outbox_ops',
    ).getSingle();
    return (result.data['c'] as int?) ?? 0;
  }

  Future<int> outboxPendingCount({int maxAttempts = 10}) async {
    final result = await customSelect(
      'SELECT COUNT(*) AS c FROM outbox_ops WHERE attempt_count < ?',
      variables: [Variable.withInt(maxAttempts)],
    ).getSingle();
    return (result.data['c'] as int?) ?? 0;
  }

  Future<int> outboxFailedCount({int maxAttempts = 10}) async {
    final result = await customSelect(
      'SELECT COUNT(*) AS c FROM outbox_ops WHERE attempt_count >= ?',
      variables: [Variable.withInt(maxAttempts)],
    ).getSingle();
    return (result.data['c'] as int?) ?? 0;
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

  // ---------------------------------------------------------------------------
  // Expenses + summary cache
  // ---------------------------------------------------------------------------

  Stream<List<ExpensesTableData>> watchExpensesByGroup(String groupId) {
    return (select(expensesTable)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([(t) => OrderingTerm.desc(t.date), (t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<ExpensesTableData>> getExpensesByGroupOnce(String groupId) {
    return (select(expensesTable)..where((t) => t.groupId.equals(groupId))).get();
  }

  Future<void> upsertExpensesRows(Iterable<ExpensesTableCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(expensesTable, rows.toList(growable: false));
    });
  }

  Stream<FinanceSummary?> watchFinanceSummary(String groupId) {
    return (select(financeSummaries)..where((t) => t.groupId.equals(groupId))).watchSingleOrNull();
  }

  Future<void> upsertFinanceSummary({
    required String groupId,
    required Map<String, dynamic> summaryJson,
  }) async {
    await into(financeSummaries).insert(
      FinanceSummariesCompanion(
        groupId: Value(groupId),
        summaryJson: Value(jsonEncode(summaryJson)),
        updatedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  // ---------------------------------------------------------------------------
  // Current chores cache
  // ---------------------------------------------------------------------------

  Stream<CurrentChoresCache?> watchCurrentChores(String groupId) {
    return (select(currentChoresCaches)
          ..where((t) => t.groupId.equals(groupId)))
        .watchSingleOrNull();
  }

  Future<CurrentChoresCache?> getCurrentChoresOnce(String groupId) {
    return (select(currentChoresCaches)
          ..where((t) => t.groupId.equals(groupId)))
        .getSingleOrNull();
  }

  Future<void> upsertCurrentChores({
    required String groupId,
    required String choresJson,
  }) async {
    await into(currentChoresCaches).insert(
      CurrentChoresCachesCompanion(
        groupId: Value(groupId),
        choresJson: Value(choresJson),
        updatedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  // ---------------------------------------------------------------------------
  // Recipes cache
  // ---------------------------------------------------------------------------

  Stream<List<RecipesTableData>> watchRecipes() {
    return (select(recipesTable)
          ..orderBy([
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .watch();
  }

  Future<List<RecipesTableData>> getRecipesOnce() {
    return (select(recipesTable)
          ..orderBy([
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .get();
  }

  Future<void> upsertRecipesRows(Iterable<RecipesTableCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(recipesTable, rows.toList(growable: false));
    });
  }

  // ---------------------------------------------------------------------------
  // Pinwall cache
  // ---------------------------------------------------------------------------

  Stream<PinwallPostsCache?> watchPinwallPosts(String groupId) {
    return (select(pinwallPostsCaches)..where((t) => t.groupId.equals(groupId)))
        .watchSingleOrNull();
  }

  Future<PinwallPostsCache?> getPinwallPostsOnce(String groupId) {
    return (select(pinwallPostsCaches)..where((t) => t.groupId.equals(groupId)))
        .getSingleOrNull();
  }

  Future<void> upsertPinwallPosts({
    required String groupId,
    required String postsJson,
  }) async {
    await into(pinwallPostsCaches).insert(
      PinwallPostsCachesCompanion(
        groupId: Value(groupId),
        postsJson: Value(postsJson),
        updatedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  // ---------------------------------------------------------------------------
  // Hub caches (group + recent activity)
  // ---------------------------------------------------------------------------

  Stream<HubGroupCache?> watchHubGroup(String groupId) {
    return (select(hubGroupCaches)..where((t) => t.groupId.equals(groupId)))
        .watchSingleOrNull();
  }

  Future<HubGroupCache?> getHubGroupOnce(String groupId) {
    return (select(hubGroupCaches)..where((t) => t.groupId.equals(groupId)))
        .getSingleOrNull();
  }

  Future<void> upsertHubGroup({
    required String groupId,
    required String groupJson,
  }) async {
    await into(hubGroupCaches).insert(
      HubGroupCachesCompanion(
        groupId: Value(groupId),
        groupJson: Value(groupJson),
        updatedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Stream<HubActivityCache?> watchHubActivities(String groupId) {
    return (select(hubActivityCaches)..where((t) => t.groupId.equals(groupId)))
        .watchSingleOrNull();
  }

  Future<HubActivityCache?> getHubActivitiesOnce(String groupId) {
    return (select(hubActivityCaches)..where((t) => t.groupId.equals(groupId)))
        .getSingleOrNull();
  }

  Future<void> upsertHubActivities({
    required String groupId,
    required String activitiesJson,
    required bool hadError,
  }) async {
    await into(hubActivityCaches).insert(
      HubActivityCachesCompanion(
        groupId: Value(groupId),
        activitiesJson: Value(activitiesJson),
        hadError: Value(hadError),
        updatedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
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
      sqlite3Wasm: Uri.parse('/sqlite3.wasm'),
      // Compiled from `web/drift_worker.dart`.
      driftWorker: Uri.parse('/drift_worker.dart.js'),
    ),
  );
}

