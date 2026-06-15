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

  /// The domain entity this op mutates, e.g. 'listItem', 'expense'. Lets the
  /// failed-changes review UI label an op and the per-row flag find it.
  TextColumn get entityType => text().named('entity_type').nullable()();

  /// The id of the mutated entity (temp id for creates). Used to roll back the
  /// optimistic local row when a failed change is discarded.
  TextColumn get entityId => text().named('entity_id').nullable()();

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
  IntColumn get baseAmount =>
      integer().named('base_amount').withDefault(const Constant(0))();
  RealColumn get fxRate =>
      real().named('fx_rate').withDefault(const Constant(1.0))();
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
  int get schemaVersion => 6;

  /// Creates all hot-query indexes.  Called from both onCreate and the v4
  /// onUpgrade block so that fresh installs and upgrades both get the indexes.
  Future<void> _createIndexes() async {
    // lists_table
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_lists_table_group_id ON lists_table(group_id);');
    // list_items_table
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_list_items_table_list_id ON list_items_table(list_id);');
    // expenses_table
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_expenses_table_group_id ON expenses_table(group_id);');
    // outbox_ops — ordered by created_at in every drain query
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_outbox_ops_created_at ON outbox_ops(created_at);');
    // canonical_items_table
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_canonical_items_table_group_id ON canonical_items_table(group_id);');
    // item_aliases_table — filtered by group_id and alias_text
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_item_aliases_table_group_id ON item_aliases_table(group_id);');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_item_aliases_table_alias_text ON item_aliases_table(alias_text);');
    // corrections_table
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_corrections_table_group_id ON corrections_table(group_id);');
    // store_aisles_table
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_store_aisles_table_group_id ON store_aisles_table(group_id);');
    // purchase_history_table — filtered by group_id + canonical_item_id
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_purchase_history_table_group_id ON purchase_history_table(group_id);');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_purchase_history_table_canonical_item_id ON purchase_history_table(canonical_item_id);');
    // item_cooccurrence_table — PK covers (group_id, item_a_id, item_b_id) but
    // queries also filter on item_b_id alone; add a covering index on group_id.
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_item_cooccurrence_table_group_id ON item_cooccurrence_table(group_id);');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
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
          if (from < 4) {
            // Add hot-query indexes (no data migration needed).
            await _createIndexes();
          }
          if (from < 5) {
            // Multi-currency: store the household-base amount and FX rate per
            // expense. Backfill base_amount = amount for existing rows so they
            // remain correct (they were single-currency at the group rate).
            await m.addColumn(expensesTable, expensesTable.baseAmount);
            await m.addColumn(expensesTable, expensesTable.fxRate);
            await customStatement(
                'UPDATE expenses_table SET base_amount = amount WHERE base_amount = 0;');
          }
          if (from < 6) {
            // Track which entity each outbox op mutates so the failed-changes
            // review UI can label/roll back ops. Nullable, no backfill needed.
            await m.addColumn(outboxOps, outboxOps.entityType);
            await m.addColumn(outboxOps, outboxOps.entityId);
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
    String? entityType,
    String? entityId,
  }) async {
    await into(outboxOps).insert(
      OutboxOpsCompanion.insert(
        id: id,
        type: type,
        payloadJson: jsonEncode(payload),
        idempotencyKey: Value(idempotencyKey),
        entityType: Value(entityType),
        entityId: Value(entityId),
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

  /// Returns a single outbox op by ID, or null if it no longer exists.
  Future<OutboxOp?> getOutboxOpById(String id) {
    return (select(outboxOps)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Number of queued ops of [type] already targeting [entityId]. Used to skip
  /// the optimistic-concurrency base when an edit chains onto an unsynced one
  /// (the chain is all ours, so there's no reliable server base to compare).
  Future<int> pendingOpCountForEntity(String type, String entityId) async {
    final result = await customSelect(
      'SELECT COUNT(*) AS c FROM outbox_ops WHERE type = ? AND entity_id = ?',
      variables: [Variable<String>(type), Variable<String>(entityId)],
    ).getSingle();
    return (result.data['c'] as int?) ?? 0;
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

  Future<void> markOutboxPermanentFailure(String id,
      {String? error, int threshold = 10}) async {
    await (update(outboxOps)..where((t) => t.id.equals(id))).write(
      OutboxOpsCompanion(
        lastAttemptAt: Value(DateTime.now()),
        attemptCount: Value(threshold),
        lastError: Value(error),
      ),
    );
  }

  Future<void> deleteOutboxOp(String id) async {
    await (delete(outboxOps)..where((t) => t.id.equals(id))).go();
  }

  /// Removes the optimistic local row for an [entityType]/[entityId] pair when
  /// a failed *create* is discarded — the server never accepted it, so the row
  /// is pure ghost data. Unknown/cache-backed types are a no-op.
  Future<void> deleteLocalEntity(String entityType, String entityId) async {
    switch (entityType) {
      case 'listItem':
        await (delete(listItemsTable)..where((t) => t.id.equals(entityId)))
            .go();
      case 'expense':
        await (delete(expensesTable)..where((t) => t.id.equals(entityId))).go();
      case 'recipe':
        await (delete(recipesTable)..where((t) => t.id.equals(entityId))).go();
    }
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

  /// All dead-lettered ops (attempt_count >= maxAttempts), newest first, for
  /// the failed-changes review surface.
  Future<List<OutboxOp>> getFailedOutboxOps({int maxAttempts = 10}) {
    return (select(outboxOps)
          ..where((t) => t.attemptCount.isBiggerOrEqualValue(maxAttempts))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.lastAttemptAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  /// Reactive view of dead-lettered ops, used by the per-row failed flag and
  /// the review sheet so the UI updates as the user retries/discards.
  Stream<List<OutboxOp>> watchFailedOutboxOps({int maxAttempts = 10}) {
    return (select(outboxOps)
          ..where((t) => t.attemptCount.isBiggerOrEqualValue(maxAttempts))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.lastAttemptAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  /// Re-arms dead-lettered ops for another drain pass: resets attempt_count to
  /// 0 and clears the backoff timestamp/error so [getOutboxBatchByTypes] picks
  /// them up again. Pass an [id] to re-arm a single op, or omit to re-arm all.
  Future<void> resetFailedOutboxOps({String? id, int maxAttempts = 10}) async {
    final query = update(outboxOps)
      ..where((t) => id != null
          ? t.id.equals(id)
          : t.attemptCount.isBiggerOrEqualValue(maxAttempts));
    await query.write(
      const OutboxOpsCompanion(
        attemptCount: Value(0),
        lastAttemptAt: Value(null),
        lastError: Value(null),
      ),
    );
  }

  Future<int> outboxFailedCount({int maxAttempts = 10}) async {
    final result = await customSelect(
      'SELECT COUNT(*) AS c FROM outbox_ops WHERE attempt_count >= ?',
      variables: [Variable.withInt(maxAttempts)],
    ).getSingle();
    return (result.data['c'] as int?) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Conflicts (edit conflicts surfaced by the server's 409-with-current-state)
  // ---------------------------------------------------------------------------

  Future<List<Conflict>> getConflicts() async {
    return (select(conflicts)..where((t) => t.resolvedAt.isNull())).get();
  }

  Stream<List<Conflict>> watchConflicts() {
    return (select(conflicts)..where((t) => t.resolvedAt.isNull())).watch();
  }

  Future<int> conflictCount() async {
    final result = await customSelect(
      'SELECT COUNT(*) AS c FROM conflicts WHERE resolved_at IS NULL',
    ).getSingle();
    return (result.data['c'] as int?) ?? 0;
  }

  Future<void> resolveConflict(String id) async {
    await (update(conflicts)..where((t) => t.id.equals(id))).write(
      ConflictsCompanion(resolvedAt: Value(DateTime.now())),
    );
  }

  Future<void> insertConflict(ConflictsCompanion entry) async {
    await into(conflicts).insert(entry, mode: InsertMode.insertOrReplace);
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

  Future<void> clearExpensesForGroup(String groupId) async {
    await (delete(expensesTable)..where((t) => t.groupId.equals(groupId))).go();
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

  /// Prefix search over aliases for typed autocomplete (e.g. "mlch" → Milch).
  /// Uses the `alias_text` index; includes household + global seed aliases.
  Future<List<ItemAliasesTableData>> searchAliasPrefix({
    required String groupId,
    required String query,
    int limit = 40,
  }) {
    if (query.isEmpty) return Future.value(const []);
    final prefix =
        query.replaceAll('%', r'\%').replaceAll('_', r'\_');
    return (select(itemAliasesTable)
          ..where((t) =>
              (t.groupId.equals(groupId) | t.groupId.equals('__global__')) &
              t.deletedAt.isNull() &
              t.aliasText.like('$prefix%'))
          ..orderBy([(t) => OrderingTerm.desc(t.weight)])
          ..limit(limit))
        .get();
  }

  Future<List<CanonicalItemsTableData>> getCanonicalItemsByIds(
      Iterable<String> ids) {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return Future.value(const []);
    return (select(canonicalItemsTable)
          ..where((t) => t.id.isIn(list) & t.deletedAt.isNull()))
        .get();
  }

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

  /// Hard-deletes the bundled global seed (canonical items + their aliases)
  /// so a newer seed version can be re-ingested cleanly. Household-scoped
  /// items, aliases, and corrections are untouched.
  Future<void> clearGlobalSeed(String globalGroupId) async {
    await batch((b) {
      b.deleteWhere<ItemAliasesTable, ItemAliasesTableData>(
          itemAliasesTable,
          (t) => t.groupId.equals(globalGroupId) & t.source.equals('seed'));
      b.deleteWhere<CanonicalItemsTable, CanonicalItemsTableData>(
          canonicalItemsTable,
          (t) => t.groupId.equals(globalGroupId) | t.isGlobal.equals(true));
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

  /// Returns ALL non-deleted aliases (household + global) whose text exactly
  /// equals [aliasText]. Unlike [findAlias] (which returns only the
  /// top-weighted single row), this surfaces every canonical item a word maps
  /// to — e.g. "spaghetti" is both the canonical name of `spaghetti` and an
  /// alias of `egg_spaghetti`. The ensemble resolver needs every colliding
  /// candidate so the scorer can disambiguate, rather than silently taking
  /// whichever won an arbitrary weight tie.
  Future<List<ItemAliasesTableData>> findAliasesByText({
    required String groupId,
    required String aliasText,
  }) {
    return (select(itemAliasesTable)
          ..where((t) =>
              (t.groupId.equals(groupId) | t.groupId.equals('__global__')) &
              t.aliasText.equals(aliasText) &
              t.deletedAt.isNull()))
        .get();
  }

  /// Loads all non-deleted aliases for a household + global seed aliases.
  /// Used by the fuzzy resolver when no exact match is found.
  ///
  /// NOTE: with the full global seed this returns ~120k rows. Prefer
  /// [getAliasFuzzyCandidates] for the hot resolve path.
  Future<List<ItemAliasesTableData>> getItemAliasesForFuzzy(String groupId) {
    return (select(itemAliasesTable)
          ..where((t) =>
              (t.groupId.equals(groupId) | t.groupId.equals('__global__')) &
              t.deletedAt.isNull()))
        .get();
  }

  /// Indexed prefilter for fuzzy resolution: only aliases that share the query's
  /// first character and are within ±2 in length. Uses the `alias_text` index
  /// for the prefix `LIKE`, cutting the candidate set from ~120k to typically a
  /// few hundred before edit-distance scoring runs in Dart.
  Future<List<ItemAliasesTableData>> getAliasFuzzyCandidates({
    required String groupId,
    required String query,
    int maxCandidates = 400,
  }) {
    if (query.isEmpty) return Future.value(const []);
    final lo = (query.length - 2).clamp(1, 1 << 30);
    final hi = query.length + 2;
    final prefix = query.substring(0, 1).replaceAll('%', r'\%').replaceAll('_', r'\_');
    return (select(itemAliasesTable)
          ..where((t) =>
              (t.groupId.equals(groupId) | t.groupId.equals('__global__')) &
              t.deletedAt.isNull() &
              t.aliasText.length.isBetweenValues(lo, hi) &
              t.aliasText.like('$prefix%'))
          ..orderBy([(t) => OrderingTerm.desc(t.weight)])
          ..limit(maxCandidates))
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

  /// Returns the aisle for an item at a store. Household-specific overrides
  /// take precedence over the shipped global store layout (groupId desc orders
  /// a real group id ahead of '__global__').
  Future<StoreAislesTableData?> getStoreAisle({
    required String groupId,
    required String storeId,
    required String canonicalItemId,
  }) {
    return (select(storeAislesTable)
          ..where((t) =>
              (t.groupId.equals(groupId) | t.groupId.equals('__global__')) &
              t.storeId.equals(storeId) &
              t.canonicalItemId.equals(canonicalItemId) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.groupId)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Hard-deletes the shipped global store layout so a newer version can be
  /// re-ingested cleanly. Household-specific aisle overrides are untouched.
  Future<void> clearGlobalStoreAisles(String globalGroupId) async {
    await (delete(storeAislesTable)
          ..where((t) => t.groupId.equals(globalGroupId)))
        .go();
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

  /// Returns all purchase-history rows for [groupId] that have a non-null
  /// [canonicalItemId], ordered newest-first. Used by [RestockService] to
  /// compute per-item purchase cadence without N+1 per-item queries.
  Future<List<PurchaseHistoryTableData>> getGroupPurchaseHistory({
    required String groupId,
    int limit = 500,
  }) {
    return (select(purchaseHistoryTable)
          ..where((t) =>
              t.groupId.equals(groupId) &
              t.canonicalItemId.isNotNull())
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

  /// Increments co-occurrence counts for multiple canonical item pairs in a
  /// single transaction. Reuses [incrementCooccurrence] per pair.
  Future<void> incrementCooccurrences({
    required String groupId,
    required String canonicalItemId,
    required List<String> peerCanonicalIds,
  }) async {
    if (peerCanonicalIds.isEmpty) return;
    await transaction(() async {
      for (final peerId in peerCanonicalIds) {
        await incrementCooccurrence(
          groupId: groupId,
          itemAId: canonicalItemId,
          itemBId: peerId,
        );
      }
    });
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

