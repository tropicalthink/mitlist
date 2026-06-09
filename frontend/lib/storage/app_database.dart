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
  IntColumn get priceCents => integer().named('price_cents').nullable()();
  TextColumn get canonicalItemId => text().named('canonical_item_id').nullable()();
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

// =============================================================================
// Grocery Intelligence Graph
// =============================================================================

class CanonicalItemsTable extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().named('group_id')();
  TextColumn get nameDe => text().named('name_de').withDefault(const Constant(''))();
  TextColumn get nameEn => text().named('name_en').withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant(''))();
  TextColumn get defaultUnit => text().named('default_unit').withDefault(const Constant(''))();
  TextColumn get productId => text().named('product_id').nullable()();
  BoolColumn get isGlobal => boolean().named('is_global').withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class ItemAliasesTable extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().named('group_id')();
  TextColumn get canonicalItemId => text().named('canonical_item_id')();
  TextColumn get aliasText => text().named('alias_text')();
  TextColumn get lang => text().withDefault(const Constant('und'))();
  TextColumn get source => text().withDefault(const Constant('correction'))();
  IntColumn get weight => integer().withDefault(const Constant(1))();
  IntColumn get version => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class CorrectionsTable extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().named('group_id')();
  TextColumn get userId => text().named('user_id').nullable()();
  TextColumn get scope => text().withDefault(const Constant('household'))();
  TextColumn get kind => text()();
  TextColumn get rawText => text().named('raw_text').withDefault(const Constant(''))();
  TextColumn get resolvedCanonicalItemId =>
      text().named('resolved_canonical_item_id').nullable()();
  TextColumn get correctedValueJson =>
      text().named('corrected_value_json').nullable()();
  TextColumn get source => text().withDefault(const Constant('manual_review'))();
  IntColumn get version => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get appliedAt => dateTime().named('applied_at').nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class StoreAislesTable extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().named('group_id')();
  TextColumn get storeId => text().named('store_id').nullable()();
  TextColumn get canonicalItemId => text().named('canonical_item_id')();
  TextColumn get aisle => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().named('sort_order').withDefault(const Constant(0))();
  RealColumn get confidence => real().withDefault(const Constant(0.5))();
  IntColumn get version => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class PurchaseHistoryTable extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().named('group_id')();
  TextColumn get canonicalItemId => text().named('canonical_item_id').nullable()();
  TextColumn get listItemId => text().named('list_item_id').nullable()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  TextColumn get unit => text().withDefault(const Constant(''))();
  IntColumn get version => integer().withDefault(const Constant(0))();
  DateTimeColumn get purchasedAt => dateTime().named('purchased_at')();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class ItemCooccurrenceTable extends Table {
  TextColumn get groupId => text().named('group_id')();
  TextColumn get itemAId => text().named('item_a_id')();
  TextColumn get itemBId => text().named('item_b_id')();
  IntColumn get count => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSeenAt => dateTime().named('last_seen_at')();
  IntColumn get version => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>>? get primaryKey => {groupId, itemAId, itemBId};
}

class ScanArtifactsTable extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().named('group_id')();
  TextColumn get userId => text().named('user_id').nullable()();
  TextColumn get imageRef => text().named('image_ref').withDefault(const Constant(''))();
  TextColumn get engine => text().withDefault(const Constant('mlkit'))();
  TextColumn get rawJson => text().named('raw_json').nullable()();
  TextColumn get resolvedJson => text().named('resolved_json').nullable()();
  IntColumn get version => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get syncedAt => dateTime().named('synced_at').nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class GroceryVersionsTable extends Table {
  TextColumn get groupId => text().named('group_id')();
  IntColumn get currentVersion => integer().named('current_version').withDefault(const Constant(0))();
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
    CanonicalItemsTable,
    ItemAliasesTable,
    CorrectionsTable,
    StoreAislesTable,
    PurchaseHistoryTable,
    ItemCooccurrenceTable,
    ScanArtifactsTable,
    GroceryVersionsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

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
          if (from < 3) {
            // Add canonical_item_id link to existing list items.
            await m.addColumn(listItemsTable, listItemsTable.canonicalItemId);
            // Create all grocery intelligence graph tables.
            await m.createTable(canonicalItemsTable);
            await m.createTable(itemAliasesTable);
            await m.createTable(correctionsTable);
            await m.createTable(storeAislesTable);
            await m.createTable(purchaseHistoryTable);
            await m.createTable(itemCooccurrenceTable);
            await m.createTable(scanArtifactsTable);
            await m.createTable(groceryVersionsTable);
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

  Future<String?> getListGroupId(String listId) async {
    final row = await (select(listsTable)
          ..where((t) => t.id.equals(listId)))
        .getSingleOrNull();
    return row?.groupId;
  }

  Stream<List<ListItemsTableData>> watchItemsByList(String listId) {
    return (select(listItemsTable)..where((t) => t.listId.equals(listId))).watch();
  }

  Future<List<ListItemsTableData>> getItemsByListOnce(String listId) {
    return (select(listItemsTable)..where((t) => t.listId.equals(listId))).get();
  }

  Future<void> clearListsForGroup(String groupId) async {
    await (delete(listsTable)..where((t) => t.groupId.equals(groupId))).go();
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

  Future<List<Conflict>> getConflicts() async {
    return (select(conflicts)..where((t) => t.resolvedAt.isNull())).get();
  }

  Future<int> conflictCount() async {
    final result = await customSelect(
      'SELECT COUNT(*) AS c FROM conflicts WHERE resolved_at IS NULL',
    ).getSingle();
    return (result.data['c'] as int?) ?? 0;
  }

  Future<void> resolveConflict(String id) async {
    await (update(conflicts)..where((t) => t.id.equals(id))).write(
      ConflictsCompanion(
        resolvedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> insertConflict(ConflictsCompanion entry) async {
    await into(conflicts).insert(entry);
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

  Future<void> clearAllUserData() {
    return transaction(() async {
      await delete(hubActivityCaches).go();
      await delete(hubGroupCaches).go();
      await delete(pinwallPostsCaches).go();
      await delete(currentChoresCaches).go();
      await delete(financeSummaries).go();
      await delete(expensesTable).go();
      await delete(listItemsTable).go();
      await delete(listsTable).go();
      await delete(recipesTable).go();
      await delete(outboxOps).go();
      await delete(conflicts).go();
      // Grocery graph — preserve global seed rows (is_global = true).
      await (delete(itemCooccurrenceTable)).go();
      await (delete(purchaseHistoryTable)).go();
      await (delete(scanArtifactsTable)).go();
      await (delete(correctionsTable)).go();
      await (delete(storeAislesTable)).go();
      await (delete(itemAliasesTable)
            ..where((t) => t.source.isNotValue('seed')))
          .go();
      await (delete(canonicalItemsTable)
            ..where((t) => t.isGlobal.equals(false)))
          .go();
      await (delete(groceryVersionsTable)).go();
    });
  }

  // ---------------------------------------------------------------------------
  // Grocery graph — canonical items
  // ---------------------------------------------------------------------------

  Future<CanonicalItemsTableData?> getCanonicalItemById(String id) {
    return (select(canonicalItemsTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<CanonicalItemsTableData>> getCanonicalItemsByGroup(
      String groupId) {
    return (select(canonicalItemsTable)
          ..where((t) =>
              (t.groupId.equals(groupId) | t.isGlobal.equals(true)) &
              t.deletedAt.isNull()))
        .get();
  }

  Future<void> upsertCanonicalItems(
      Iterable<CanonicalItemsTableCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(
          canonicalItemsTable, rows.toList(growable: false));
    });
  }

  // ---------------------------------------------------------------------------
  // Grocery graph — aliases (hot lookup path)
  // ---------------------------------------------------------------------------

  Future<ItemAliasesTableData?> findAlias({
    required String groupId,
    required String aliasText,
  }) {
    return (select(itemAliasesTable)
          ..where((t) =>
              (t.groupId.equals(groupId) | t.groupId.equals('__global__')) &
              t.aliasText.equals(aliasText) &
              t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.weight),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Loads all non-deleted aliases for a household + global seed aliases.
  /// Used by the fuzzy resolver when no exact match is found.
  Future<List<ItemAliasesTableData>> getItemAliasesForFuzzy(String groupId) {
    return (select(itemAliasesTable)
          ..where((t) =>
              (t.groupId.equals(groupId) | t.groupId.equals('__global__')) &
              t.deletedAt.isNull()))
        .get();
  }

  Future<void> upsertItemAliases(
      Iterable<ItemAliasesTableCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(
          itemAliasesTable, rows.toList(growable: false));
    });
  }

  Future<void> incrementAliasWeight(String id) async {
    await customUpdate(
      'UPDATE item_aliases_table SET weight = weight + 1, updated_at = ? WHERE id = ?',
      variables: [
        Variable<DateTime>(DateTime.now()),
        Variable<String>(id),
      ],
      updates: {itemAliasesTable},
    );
  }

  // ---------------------------------------------------------------------------
  // Grocery graph — corrections (append-only)
  // ---------------------------------------------------------------------------

  Future<void> insertCorrection(CorrectionsTableCompanion row) async {
    await into(correctionsTable).insert(row, mode: InsertMode.insertOrIgnore);
  }

  Future<List<CorrectionsTableData>> getUnappliedCorrections(
      String groupId) {
    return (select(correctionsTable)
          ..where((t) =>
              t.groupId.equals(groupId) & t.appliedAt.isNull()))
        .get();
  }

  Future<void> markCorrectionApplied(String id) async {
    await (update(correctionsTable)..where((t) => t.id.equals(id))).write(
      CorrectionsTableCompanion(appliedAt: Value(DateTime.now())),
    );
  }

  Future<void> upsertCorrections(
      Iterable<CorrectionsTableCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(
          correctionsTable, rows.toList(growable: false));
    });
  }

  // ---------------------------------------------------------------------------
  // Grocery graph — store aisles
  // ---------------------------------------------------------------------------

  Future<StoreAislesTableData?> getStoreAisle({
    required String groupId,
    required String storeId,
    required String canonicalItemId,
  }) {
    return (select(storeAislesTable)
          ..where((t) =>
              t.groupId.equals(groupId) &
              t.storeId.equals(storeId) &
              t.canonicalItemId.equals(canonicalItemId) &
              t.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Future<List<StoreAislesTableData>> getStoreAisles({
    required String groupId,
    String? storeId,
  }) {
    return (select(storeAislesTable)
          ..where((t) =>
              t.groupId.equals(groupId) &
              (storeId == null
                  ? const Constant(true)
                  : t.storeId.equals(storeId)) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
  }

  Future<void> upsertStoreAisles(
      Iterable<StoreAislesTableCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(
          storeAislesTable, rows.toList(growable: false));
    });
  }

  // ---------------------------------------------------------------------------
  // Grocery graph — purchase history
  // ---------------------------------------------------------------------------

  Future<void> insertPurchaseHistory(PurchaseHistoryTableCompanion row) async {
    await into(purchaseHistoryTable)
        .insert(row, mode: InsertMode.insertOrIgnore);
  }

  Future<void> upsertPurchaseHistory(
      Iterable<PurchaseHistoryTableCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(
          purchaseHistoryTable, rows.toList(growable: false));
    });
  }

  Future<List<PurchaseHistoryTableData>> getRecentPurchases({
    required String groupId,
    required String canonicalItemId,
    int limit = 20,
  }) {
    return (select(purchaseHistoryTable)
          ..where((t) =>
              t.groupId.equals(groupId) &
              t.canonicalItemId.equals(canonicalItemId))
          ..orderBy([(t) => OrderingTerm.desc(t.purchasedAt)])
          ..limit(limit))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Grocery graph — cooccurrence
  // ---------------------------------------------------------------------------

  Future<void> upsertCooccurrence(
      Iterable<ItemCooccurrenceTableCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(
          itemCooccurrenceTable, rows.toList(growable: false));
    });
  }

  Future<List<ItemCooccurrenceTableData>> getTopCooccurrences({
    required String groupId,
    required String itemId,
    int limit = 10,
  }) {
    return (select(itemCooccurrenceTable)
          ..where((t) =>
              t.groupId.equals(groupId) &
              (t.itemAId.equals(itemId) | t.itemBId.equals(itemId)))
          ..orderBy([(t) => OrderingTerm.desc(t.count)])
          ..limit(limit))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Grocery graph — scan artifacts
  // ---------------------------------------------------------------------------

  Future<void> insertScanArtifact(ScanArtifactsTableCompanion row) async {
    await into(scanArtifactsTable).insert(row, mode: InsertMode.insertOrIgnore);
  }

  Future<void> markScanArtifactSynced(String id) async {
    await (update(scanArtifactsTable)..where((t) => t.id.equals(id))).write(
      ScanArtifactsTableCompanion(syncedAt: Value(DateTime.now())),
    );
  }

  // ---------------------------------------------------------------------------
  // Grocery graph — version tracking
  // ---------------------------------------------------------------------------

  Future<int> getGroceryVersion(String groupId) async {
    final row = await (select(groceryVersionsTable)
          ..where((t) => t.groupId.equals(groupId)))
        .getSingleOrNull();
    return row?.currentVersion ?? 0;
  }

  Future<void> setGroceryVersion(String groupId, int version) async {
    await into(groceryVersionsTable).insert(
      GroceryVersionsTableCompanion(
        groupId: Value(groupId),
        currentVersion: Value(version),
        updatedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  // ---------------------------------------------------------------------------
  // Grocery graph — co-occurrence (Phase 6)
  // ---------------------------------------------------------------------------

  /// Increments the co-occurrence count for a canonical item pair.
  /// IDs are sorted so (A,B) and (B,A) hit the same row.
  Future<void> incrementCooccurrence({
    required String groupId,
    required String itemAId,
    required String itemBId,
  }) async {
    // Canonical ordering so (A,B) = (B,A).
    final a = itemAId.compareTo(itemBId) <= 0 ? itemAId : itemBId;
    final b = itemAId.compareTo(itemBId) <= 0 ? itemBId : itemAId;
    final now = DateTime.now();
    await customStatement(
      '''INSERT INTO item_cooccurrence_table
           (group_id, item_a_id, item_b_id, count, last_seen_at, version)
         VALUES (?, ?, ?, 1, ?, 0)
         ON CONFLICT(group_id, item_a_id, item_b_id) DO UPDATE
           SET count = count + 1,
               last_seen_at = excluded.last_seen_at,
               version = version + 1''',
      [groupId, a, b, now],
    );
  }

  /// Returns all checked list items that have a canonicalItemId set.
  Future<List<ListItemsTableData>> getCheckedItemsWithCanonical(
      String listId) {
    return (select(listItemsTable)
          ..where((t) =>
              t.listId.equals(listId) &
              t.checked.equals(true) &
              t.canonicalItemId.isNotNull()))
        .get();
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

