import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../models/list_models.dart';
import 'grocery_reference_database.dart';

part 'app_database.g.dart';

/// The sentinel group id for the bundled global grocery reference rows. These
/// no longer live in the main DB (they moved to [GroceryReferenceDatabase]);
/// the constant is kept so aisle routing can distinguish a global lookup from a
/// household one.
const String kGlobalGroupId = '__global__';

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
  TextColumn get canonicalItemId =>
      text().named('canonical_item_id').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {id};
}

class OutboxOps extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get type => text()();
  TextColumn get payloadJson => text().named('payload_json')();
  TextColumn get idempotencyKey => text().named('idempotency_key').nullable()();
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

  /// Server last-modified stamp, kept as the optimistic-concurrency base for
  /// offline edits. Nullable: rows created locally have no server version yet,
  /// and rows cached before this column existed have none either.
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();

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

  /// 'private' or 'household'. Replaces the old is_public boolean, which the
  /// server dropped in migration 000058.
  TextColumn get visibility => text().withDefault(const Constant('private'))();

  /// The household a 'household' recipe is shared with, else null.
  TextColumn get groupId => text().named('group_id').nullable()();

  /// Tags as a JSON array. The cache used to drop them entirely, so any recipe
  /// served from here came back untagged and the offline edit path could not
  /// touch them.
  TextColumn get tagsJson =>
      text().named('tags_json').withDefault(const Constant('[]'))();
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

/// Single-row cache of the current user's full household list (the payload of
/// `GroupService.listGroups`). Keyed by a constant so the entire list is read
/// and replaced atomically. Lets every screen resolve the active group offline
/// instead of failing on a network call.
class GroupsCaches extends Table {
  TextColumn get cacheKey => text().named('cache_key')();
  TextColumn get groupsJson => text().named('groups_json')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {cacheKey};
}

/// Cached settlements per household (the payload of
/// `FinanceService.listSettlements`), so the Settlements tab renders offline
/// and an offline-recorded settlement has somewhere to live until it syncs.
class SettlementsCaches extends Table {
  TextColumn get groupId => text().named('group_id')();
  TextColumn get settlementsJson => text().named('settlements_json')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {groupId};
}

/// Cached calendar events, keyed by household *and* the requested window.
///
/// Calendar and meal-plan reads are range queries, so a single row per group
/// would thrash as the user pages between months. [rangeKey] is derived from
/// the from/to pair; old rows are pruned per group so browsing does not grow
/// the database without bound.
class CalendarCaches extends Table {
  TextColumn get groupId => text().named('group_id')();
  TextColumn get rangeKey => text().named('range_key')();
  TextColumn get eventsJson => text().named('events_json')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {groupId, rangeKey};
}

/// Cached meal plans, keyed by household and window. See [CalendarCaches].
class MealPlanCaches extends Table {
  TextColumn get groupId => text().named('group_id')();
  TextColumn get rangeKey => text().named('range_key')();
  TextColumn get plansJson => text().named('plans_json')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {groupId, rangeKey};
}

class HubActivityCaches extends Table {
  TextColumn get groupId => text().named('group_id')();
  TextColumn get activitiesJson => text().named('activities_json')();
  BoolColumn get hadError => boolean().named('had_error')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {groupId};
}

/// Last good body of every JSON `GET` the API client made, keyed by method and
/// full URL (query string included).
///
/// The per-feature caches above are the primary offline story, but a dozen
/// screens (products, shopping locations, recurring expenses, notifications,
/// cookbooks, the feature board, the weekly summary, chore assignments…) read
/// straight from a service and had no cache at all, so offline they waited out
/// the connect timeout and rendered an error page. Rather than hand-roll a
/// table and a `toJson` for each, the [ResponseCacheInterceptor] serves the
/// stored body whenever the transport fails. Bounded by row count, see
/// [AppDatabase.upsertResponseCache].
class ResponseCaches extends Table {
  TextColumn get cacheKey => text().named('cache_key')();
  IntColumn get statusCode => integer().named('status_code')();
  TextColumn get bodyJson => text().named('body_json')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {cacheKey};
}

// =============================================================================
// Grocery Intelligence Graph
// =============================================================================

class CanonicalItemsTable extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().named('group_id')();
  TextColumn get nameDe =>
      text().named('name_de').withDefault(const Constant(''))();
  TextColumn get nameEn =>
      text().named('name_en').withDefault(const Constant(''))();
  TextColumn get nameFr =>
      text().named('name_fr').withDefault(const Constant(''))();
  TextColumn get nameEs =>
      text().named('name_es').withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant(''))();
  TextColumn get defaultUnit =>
      text().named('default_unit').withDefault(const Constant(''))();
  TextColumn get productId => text().named('product_id').nullable()();
  BoolColumn get isGlobal =>
      boolean().named('is_global').withDefault(const Constant(false))();
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
  TextColumn get rawText =>
      text().named('raw_text').withDefault(const Constant(''))();
  TextColumn get resolvedCanonicalItemId =>
      text().named('resolved_canonical_item_id').nullable()();
  TextColumn get correctedValueJson =>
      text().named('corrected_value_json').nullable()();
  TextColumn get source =>
      text().withDefault(const Constant('manual_review'))();
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
  IntColumn get sortOrder =>
      integer().named('sort_order').withDefault(const Constant(0))();
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
  TextColumn get canonicalItemId =>
      text().named('canonical_item_id').nullable()();
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
  TextColumn get imageRef =>
      text().named('image_ref').withDefault(const Constant(''))();
  TextColumn get engine =>
      text().withDefault(const Constant('ppocrv6-small-det-medium-rec-onnx'))();
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
  IntColumn get currentVersion =>
      integer().named('current_version').withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column<Object>>? get primaryKey => {groupId};
}

/// On-device tally of grocery words that were checked off but never resolved to
/// a canonical item (resolver score < 0.85, so `canonical_item_id` was null).
///
/// Every such check-off increments the count for its household + normalised
/// name. Once the count crosses the promotion threshold, a household-local
/// canonical item + alias is minted so the word can finally surface in
/// autocomplete/suggestions and feed the learning loop. This table stays
/// strictly local — it is the pre-promotion scratchpad, never synced (unlike
/// [CorrectionsTable]) so sub-threshold noise never leaves the device.
class LocalItemSignalsTable extends Table {
  TextColumn get groupId => text().named('group_id')();
  TextColumn get normalizedName => text().named('normalized_name')();
  TextColumn get displayName => text().named('display_name')();
  IntColumn get count => integer().withDefault(const Constant(0))();

  /// Set once the word crossed the threshold and a canonical was minted. Guards
  /// against re-minting: later check-offs reinforce the existing alias instead.
  TextColumn get promotedCanonicalItemId =>
      text().named('promoted_canonical_item_id').nullable()();
  DateTimeColumn get firstSeen => dateTime().named('first_seen')();
  DateTimeColumn get lastSeen => dateTime().named('last_seen')();

  @override
  Set<Column<Object>>? get primaryKey => {groupId, normalizedName};
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
    GroupsCaches,
    SettlementsCaches,
    CalendarCaches,
    MealPlanCaches,
    ResponseCaches,
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
    LocalItemSignalsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 16;

  /// The prebuilt read-only global grocery brain (canonical items, seed/OFF
  /// aliases + FTS, store aisles). Attached by [GroceryReferenceInstaller] once
  /// the bundled asset is copied into place. Null during the brief first-install
  /// window (and in tests that don't install it), in which case the grocery
  /// read methods degrade to household-only rows — resolution returns nothing
  /// (the caller's backfill links later) and autocomplete falls back to the
  /// bundled index.
  GroceryReferenceDatabase? _reference;

  /// Wires in the reference DB. Idempotent; safe to call after each reinstall.
  void attachReference(GroceryReferenceDatabase reference) {
    _reference = reference;
  }

  bool get hasReference => _reference != null;

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
    // Composite (group_id, alias_text) — the typed-autocomplete prefix search
    // filters group_id AND range-scans alias_text on every keystroke. Neither
    // single-column index lets SQLite do both: with ~280k rows all under the
    // '__global__' scope, seeking group_id still leaves a full alias_text scan.
    // This composite lets one seek land on the group and range the prefix,
    // turning a ~full-table scan per keystroke into a bounded index range.
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_item_aliases_group_alias ON item_aliases_table(group_id, alias_text);');
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
    // local_item_signals_table — read by (group_id, normalized_name) on every
    // unresolved check-off.
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_local_item_signals_group_id ON local_item_signals_table(group_id);');
  }

  /// Creates the FTS5 virtual table that powers word-level prefix search over
  /// alias text (e.g. "pad" matches "Breast Pads", "pringles" matches nothing
  /// under whole-string prefix but a word-prefix query on "pringles" now works
  /// once brand aliases are added to the seed).
  ///
  /// The FTS table is a *content table* pointing at item_aliases_table so the
  /// full-text index stays in sync via triggers on insert/update/delete.
  /// Queried with `alias_text_fts MATCH '"token*"'` (FTS5 prefix syntax on a
  /// single term, or `"word*" "word2*"` for multi-word). Results are JOIN'd back
  /// to item_aliases_table to filter by group_id and deleted_at.
  Future<void> createAliasFts() async {
    // Content FTS5 table — content= makes the tokenized data live in SQLite's
    // FTS index while the source columns remain in item_aliases_table.
    await customStatement('''
CREATE VIRTUAL TABLE IF NOT EXISTS item_aliases_fts
  USING fts5(
    alias_text,
    content=item_aliases_table,
    content_rowid=rowid,
    tokenize="unicode61 remove_diacritics 2"
  );
''');
    // Triggers to keep the FTS index in sync with the base table.
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS item_aliases_fts_ai
  AFTER INSERT ON item_aliases_table BEGIN
    INSERT INTO item_aliases_fts(rowid, alias_text)
      VALUES (new.rowid, new.alias_text);
  END;
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS item_aliases_fts_ad
  AFTER DELETE ON item_aliases_table BEGIN
    INSERT INTO item_aliases_fts(item_aliases_fts, rowid, alias_text)
      VALUES ('delete', old.rowid, old.alias_text);
  END;
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS item_aliases_fts_au
  AFTER UPDATE ON item_aliases_table BEGIN
    INSERT INTO item_aliases_fts(item_aliases_fts, rowid, alias_text)
      VALUES ('delete', old.rowid, old.alias_text);
    INSERT INTO item_aliases_fts(rowid, alias_text)
      VALUES (new.rowid, new.alias_text);
  END;
''');
  }

  /// Drops the FTS-sync triggers so a large bulk insert into
  /// `item_aliases_table` (e.g. the initial grocery seed, ~280k rows) doesn't
  /// pay a per-row tokenize-and-index cost on every insert. Callers MUST
  /// re-run [rebuildAliasFts] and [createAliasFts] (idempotent, `IF NOT
  /// EXISTS`) afterwards so the FTS index reflects the bulk-inserted rows
  /// again. Deliberately NOT wrapped in one transaction with the bulk insert:
  /// a transaction spanning the whole seed serializes every interactive write
  /// behind it for its full duration (see `GrocerySeedLoader`). An interrupted
  /// seed instead leaves the index stale/partial until the next launch, where
  /// the version-gated seed re-runs and repairs it.
  Future<void> dropAliasFtsTriggers() async {
    await customStatement('DROP TRIGGER IF EXISTS item_aliases_fts_ai;');
    await customStatement('DROP TRIGGER IF EXISTS item_aliases_fts_ad;');
    await customStatement('DROP TRIGGER IF EXISTS item_aliases_fts_au;');
  }

  /// Drops the `item_aliases_table` secondary indexes for the duration of the
  /// bulk seed insert — incremental index maintenance across ~280k inserts
  /// costs more than one bulk sort per index afterwards. Callers MUST re-run
  /// [createAliasIndexes] when the bulk insert is done; like the FTS triggers,
  /// an interrupted seed leaves them missing only until the version-gated
  /// re-run repairs them on the next launch.
  Future<void> dropAliasIndexes() async {
    await customStatement(
        'DROP INDEX IF EXISTS idx_item_aliases_table_group_id;');
    await customStatement(
        'DROP INDEX IF EXISTS idx_item_aliases_table_alias_text;');
    await customStatement('DROP INDEX IF EXISTS idx_item_aliases_group_alias;');
  }

  /// Recreates the indexes dropped by [dropAliasIndexes] (idempotent,
  /// `IF NOT EXISTS`). Each CREATE INDEX is a single bulk sort over the table.
  Future<void> createAliasIndexes() async {
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_item_aliases_table_group_id ON item_aliases_table(group_id);');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_item_aliases_table_alias_text ON item_aliases_table(alias_text);');
    await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_item_aliases_group_alias ON item_aliases_table(group_id, alias_text);');
  }

  /// Rebuilds the `item_aliases_fts` index from `item_aliases_table` in one
  /// bulk pass (FTS5's documented 'rebuild' command) — dramatically cheaper
  /// than the per-row trigger-maintained index for a large bulk insert. Only
  /// correct to call while the FTS triggers are down (see
  /// [dropAliasFtsTriggers]); otherwise rows inserted after triggers are
  /// restored would already be indexed once and this would re-index them.
  Future<void> rebuildAliasFts() async {
    await customStatement(
        "INSERT INTO item_aliases_fts(item_aliases_fts) VALUES ('rebuild');");
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
          // No item_aliases_fts on the main DB: the global seed/OFF aliases (the
          // only rows worth a word-prefix FTS) now live in the read-only
          // reference DB. Household correction aliases are few and exact —
          // covered by the searchAliasPrefix range scan — so the main DB keeps
          // no FTS and its insert/update/delete triggers, and correction writes
          // stay cheap.
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
          if (from < 7) {
            // Persist the household list so group resolution works offline.
            await m.createTable(groupsCaches);
          }
          if (from < 8) {
            // Add FTS5 virtual table over alias_text for word-level prefix
            // search (e.g. "pad" → "Breast Pads", "corn" → "Corn Flakes").
            // Backfill the index from existing rows so upgrades work correctly.
            await createAliasFts();
            await customStatement(
                'INSERT INTO item_aliases_fts(rowid, alias_text) '
                'SELECT rowid, alias_text FROM item_aliases_table;');
          }
          if (from < 9) {
            // Store the French and Spanish canonical names so the suggestion
            // UI can show the item in the user's locale (es/fr markets are
            // shipped in the seed). Default ''; the next seed reingest (version
            // bump) backfills the values for global rows.
            await m.addColumn(canonicalItemsTable, canonicalItemsTable.nameFr);
            await m.addColumn(canonicalItemsTable, canonicalItemsTable.nameEs);
          }
          if (from < 10) {
            // Composite (group_id, alias_text) index so typed-autocomplete
            // prefix search seeks the group then range-scans the prefix in one
            // index pass instead of a full ~280k-row scan per keystroke.
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_item_aliases_group_alias ON item_aliases_table(group_id, alias_text);');
          }
          if (from < 11) {
            // The global grocery brain moved to a prebuilt read-only reference
            // DB (GroceryReferenceDatabase). Evict the ~280k global rows this
            // install seeded into the main DB so they aren't double-counted with
            // the reference DB, and drop the now-unused main-DB FTS. Drop the
            // FTS triggers first so the bulk delete doesn't pay a per-row FTS
            // delete (the exact cost the whole change removes).
            await dropAliasFtsTriggers();
            await customStatement('DROP TABLE IF EXISTS item_aliases_fts;');
            await customStatement(
                "DELETE FROM item_aliases_table WHERE group_id = '__global__';");
            await customStatement(
                "DELETE FROM canonical_items_table WHERE is_global = 1 OR group_id = '__global__';");
            await customStatement(
                "DELETE FROM store_aisles_table WHERE group_id = '__global__';");
            // Reclaim the freed pages (one-time, at the upgrade open, before the
            // app is interactive).
            await customStatement('VACUUM;');
          }
          if (from < 12) {
            // Pre-promotion tally for checked-off words that never resolved to a
            // canonical item. Purely local; lets a repeatedly-bought novel word
            // ("fassi", a store brand, a family shorthand) earn its way into the
            // household's suggestions once it crosses the promotion threshold.
            await m.createTable(localItemSignalsTable);
            await customStatement(
                'CREATE INDEX IF NOT EXISTS idx_local_item_signals_group_id ON local_item_signals_table(group_id);');
          }
          if (from < 13) {
            // Offline coverage for the three features that shipped after the
            // offline pass: settlements gain a cache (so a queued one has
            // somewhere to live), and calendar/meal plans gain range-keyed
            // read caches so they render something offline instead of nothing.
            await m.createTable(settlementsCaches);
            await m.createTable(calendarCaches);
            await m.createTable(mealPlanCaches);
          }
          if (from < 14) {
            // Expense optimistic concurrency needs the server's updated_at as a
            // base. Nullable with no backfill: existing cached rows genuinely
            // have no known server version, and a null base means the edit
            // falls back to last-write-wins rather than conflicting falsely.
            await m.addColumn(expensesTable, expensesTable.updatedAt);
          }
          if (from < 15) {
            // Recipes moved from a public/private boolean to household scoping,
            // and the cache finally keeps tags. is_public is NOT NULL with no
            // default, so it has to go rather than linger — an insert that
            // omits it would fail. Rebuild, same as the from < 2 step above.
            //
            // Guarded because a partial database (migration tests build one,
            // and a half-created install could too) may not have the table at
            // all, and a cache migration should not be the thing that bricks
            // the app.
            final hasRecipes = await customSelect(
              "SELECT 1 FROM sqlite_master "
              "WHERE type = 'table' AND name = 'recipes_table';",
            ).get();
            if (hasRecipes.isEmpty) {
              await m.createTable(recipesTable);
            } else {
              await customStatement('''
CREATE TABLE recipes_table__new (
  id TEXT NOT NULL PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  prep_time INTEGER NOT NULL,
  cook_time INTEGER NOT NULL,
  servings INTEGER NOT NULL,
  image_url TEXT,
  visibility TEXT NOT NULL DEFAULT 'private',
  group_id TEXT,
  tags_json TEXT NOT NULL DEFAULT '[]',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
''');

              // Everything carries over as private regardless of the old flag.
              // The cache cannot know which household the server's own backfill
              // chose, and showing an unearned "shared" badge is the worse error
              // — the next sync writes the real value.
              await customStatement('''
INSERT INTO recipes_table__new (
  id, title, description, prep_time, cook_time, servings, image_url,
  visibility, group_id, tags_json, created_at, updated_at
)
SELECT id, title, description, prep_time, cook_time, servings, image_url,
       'private', NULL, '[]', created_at, updated_at
FROM recipes_table;
''');

              await customStatement('DROP TABLE recipes_table;');
              await customStatement(
                  'ALTER TABLE recipes_table__new RENAME TO recipes_table;');
            }
          }
          if (from < 16) {
            // Read-through cache of GET bodies for the offline fallback.
            await m.createTable(responseCaches);
          }
        },
        beforeOpen: (details) async {
          await customStatement('pragma foreign_keys = ON;');
          // WAL lets interactive reads (watch streams, one-shot lookups) run
          // concurrently with a large background write that holds the writer —
          // e.g. the ~280k-row grocery seed and its FTS rebuild. On the default
          // rollback-journal mode the single serial connection stalls every
          // read behind that write, which is a big part of why adding to a list
          // felt frozen right after first launch. busy_timeout makes a
          // contended writer wait for the lock instead of failing outright.
          // Native only: the web (sqlite3 wasm) VFS does not support WAL.
          if (!kIsWeb) {
            await customStatement('pragma journal_mode = WAL;');
            await customStatement('pragma busy_timeout = 5000;');
          }
        },
      );

  Stream<List<ListsTableData>> watchListsByGroup(String groupId) {
    return (select(listsTable)..where((t) => t.groupId.equals(groupId)))
        .watch();
  }

  Future<List<ListsTableData>> getListsByGroupOnce(String groupId) {
    return (select(listsTable)..where((t) => t.groupId.equals(groupId))).get();
  }

  Future<String?> getListGroupId(String listId) async {
    final row = await (select(listsTable)..where((t) => t.id.equals(listId)))
        .getSingleOrNull();
    return row?.groupId;
  }

  Future<String?> getListType(String listId) async {
    final row = await (select(listsTable)..where((t) => t.id.equals(listId)))
        .getSingleOrNull();
    return row?.type;
  }

  Stream<List<ListItemsTableData>> watchItemsByList(String listId) {
    return (select(listItemsTable)..where((t) => t.listId.equals(listId)))
        .watch();
  }

  Future<List<ListItemsTableData>> getItemsByListOnce(String listId) {
    return (select(listItemsTable)..where((t) => t.listId.equals(listId)))
        .get();
  }

  Future<void> deleteListsForGroupExcluding(
    String groupId,
    Set<String> keepIds,
  ) async {
    await (delete(listsTable)
          ..where((t) => t.groupId.equals(groupId) & t.id.isNotIn(keepIds)))
        .go();
  }

  Future<void> updateListName(String listId, String name) async {
    await (update(listsTable)..where((t) => t.id.equals(listId)))
        .write(ListsTableCompanion(name: Value(name)));
  }

  Future<void> upsertListsRows(Iterable<ListsTableCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(listsTable, rows.toList(growable: false));
    });
  }

  Future<void> upsertListItemsRows(
      Iterable<ListItemsTableCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(listItemsTable, rows.toList(growable: false));
    });
  }

  Future<void> deleteItemsForList(String listId) async {
    await (delete(listItemsTable)..where((t) => t.listId.equals(listId))).go();
  }

  Future<void> deleteListItemsByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    await (delete(listItemsTable)..where((t) => t.id.isIn(ids))).go();
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

  /// Drops still-queued ops of [type] targeting [entityId]. Used to coalesce
  /// last-write-wins ops (e.g. pinwall note moves) so only the newest queued
  /// value survives.
  Future<void> deleteOutboxOpsByTypeAndEntity(
      String type, String entityId) async {
    await (delete(outboxOps)
          ..where((t) => t.type.equals(type) & t.entityId.equals(entityId)))
        .go();
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
              (t.lastAttemptAt.isNull() |
                  t.lastAttemptAt.isSmallerThanValue(cutoff)))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Returns a single outbox op by ID, or null if it no longer exists.
  Future<OutboxOp?> getOutboxOpById(String id) {
    return (select(outboxOps)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// All queued ops of [type], oldest first.
  ///
  /// Used by blob-backed refreshes to re-splice optimistic rows after
  /// overwriting a cache with server state: unlike the row-backed tables there
  /// is no per-entity merge, so a refresh that lands before the drain would
  /// otherwise erase a create the user can still see queued.
  Future<List<OutboxOp>> getOutboxOpsByType(String type) {
    return (select(outboxOps)
          ..where((t) => t.type.equals(type))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
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

  /// IDs of list items with an unsynced outbox op (create/update/delete). Used
  /// to keep a server refresh from deleting a row the user just added/edited
  /// locally before the outbox has had a chance to sync it.
  Future<Set<String>> getPendingListItemIds() async {
    final rows = await (select(outboxOps)
          ..where((t) => t.entityType.equals('listItem')))
        .get();
    return rows.map((r) => r.entityId).whereType<String>().toSet();
  }

  /// Records a failed drain attempt.
  ///
  /// [countsTowardFailure] must be false when the request never reached the
  /// server (offline, connection refused). Such an attempt still stamps
  /// `lastAttemptAt` so the 5s backoff applies, but it must not advance
  /// `attempt_count` — that counter gates [getOutboxBatchByTypes], so counting
  /// offline attempts dead-letters valid ops that the server never saw.
  Future<void> markOutboxAttempt(
    String id, {
    String? error,
    bool countsTowardFailure = true,
  }) async {
    await (update(outboxOps)..where((t) => t.id.equals(id))).write(
      OutboxOpsCompanion(
        lastAttemptAt: Value(DateTime.now()),
        attemptCount: const Value.absent(),
        lastError: Value(error),
      ),
    );
    if (!countsTowardFailure) return;
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
      // Blob-backed entities have no row to delete — splice them out of the
      // cached JSON instead. Without this, discarding a dead-lettered create
      // leaves a phantom the server will never have and the user can never
      // remove.
      case 'chore':
        await _spliceFromBlobCaches(
          entityId,
          idOf: (entry) =>
              entry['chore'] is Map ? entry['chore']['id'] as String? : null,
        );
      case 'settlement':
        await _spliceFromSettlementsCaches(entityId);
    }
  }

  /// Removes any entry identified by [idOf] == [entityId] from every cached
  /// current-chores blob. Group-agnostic: the outbox op carries only the entity
  /// id, and a household count is small enough to scan.
  Future<void> _spliceFromBlobCaches(
    String entityId, {
    required String? Function(Map entry) idOf,
  }) async {
    final rows = await select(currentChoresCaches).get();
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row.choresJson);
        if (decoded is! List) continue;
        final kept =
            decoded.where((e) => !(e is Map && idOf(e) == entityId)).toList();
        if (kept.length == decoded.length) continue;
        await upsertCurrentChores(
          groupId: row.groupId,
          choresJson: jsonEncode(kept),
        );
      } catch (_) {
        // Best-effort cleanup; a later refresh reconciles.
      }
    }
  }

  Future<void> _spliceFromSettlementsCaches(String entityId) async {
    final rows = await select(settlementsCaches).get();
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row.settlementsJson);
        if (decoded is! List) continue;
        final kept =
            decoded.where((e) => !(e is Map && e['id'] == entityId)).toList();
        if (kept.length == decoded.length) continue;
        await upsertSettlements(
          groupId: row.groupId,
          settlementsJson: jsonEncode(kept),
        );
      } catch (_) {
        // Best-effort cleanup; a later refresh reconciles.
      }
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

  /// Clears every unresolved conflict recorded for the given op types.
  /// Used to sweep conflicts that should never have been recorded (ops whose
  /// endpoints have no edit-conflict semantics), which would otherwise pin the
  /// "needs your review" banner forever.
  Future<void> resolveConflictsByEntityTypes(List<String> types) async {
    await (update(conflicts)
          ..where((t) => t.entityType.isIn(types) & t.resolvedAt.isNull()))
        .write(ConflictsCompanion(resolvedAt: Value(DateTime.now())));
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

  /// Updates the canonical link carried by a queued list-item create/add.
  /// Local grocery ids are deliberately kept out of the public list API when
  /// they are not UUIDs, but retaining them in the durable outbox lets temp-id
  /// reconciliation preserve the on-device intelligence link.
  Future<void> updatePendingListItemCanonicalId({
    required String entityId,
    required String? canonicalItemId,
  }) async {
    final rows = await (select(outboxOps)
          ..where((t) =>
              t.entityId.equals(entityId) &
              t.type.isIn(const ['createItem', 'addItemAmount'])))
        .get();
    for (final row in rows) {
      final decoded = jsonDecode(row.payloadJson);
      if (decoded is! Map<String, dynamic>) continue;
      if (canonicalItemId == null) {
        decoded.remove('canonicalItemId');
      } else {
        decoded['canonicalItemId'] = canonicalItemId;
      }
      await (update(outboxOps)..where((t) => t.id.equals(row.id))).write(
        OutboxOpsCompanion(payloadJson: Value(jsonEncode(decoded))),
      );
    }
  }

  Future<void> replaceTempItemId({
    required String tempId,
    required ListItem server,
  }) async {
    final local = await (select(listItemsTable)
          ..where((t) => t.id.equals(tempId)))
        .getSingleOrNull();
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
        priceCents: Value(server.priceCents ?? local?.priceCents),
        canonicalItemId:
            Value(server.canonicalItemId ?? local?.canonicalItemId),
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
          ..orderBy([
            (t) => OrderingTerm.desc(t.date),
            (t) => OrderingTerm.desc(t.createdAt)
          ]))
        .watch();
  }

  Future<List<ExpensesTableData>> getExpensesByGroupOnce(String groupId) {
    return (select(expensesTable)..where((t) => t.groupId.equals(groupId)))
        .get();
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
    return (select(financeSummaries)..where((t) => t.groupId.equals(groupId)))
        .watchSingleOrNull();
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
  // Settlements cache
  // ---------------------------------------------------------------------------

  Stream<SettlementsCache?> watchSettlements(String groupId) {
    return (select(settlementsCaches)..where((t) => t.groupId.equals(groupId)))
        .watchSingleOrNull();
  }

  Future<SettlementsCache?> getSettlementsOnce(String groupId) {
    return (select(settlementsCaches)..where((t) => t.groupId.equals(groupId)))
        .getSingleOrNull();
  }

  Future<void> upsertSettlements({
    required String groupId,
    required String settlementsJson,
  }) async {
    await into(settlementsCaches).insert(
      SettlementsCachesCompanion(
        groupId: Value(groupId),
        settlementsJson: Value(settlementsJson),
        updatedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  // ---------------------------------------------------------------------------
  // Calendar / meal-plan range caches
  // ---------------------------------------------------------------------------

  /// How many windows to retain per household. Paging a year back and forth
  /// should be instant without letting the cache grow unbounded.
  static const int kRangeCacheRetained = 24;

  Future<CalendarCache?> getCalendarRange(String groupId, String rangeKey) {
    return (select(calendarCaches)
          ..where(
              (t) => t.groupId.equals(groupId) & t.rangeKey.equals(rangeKey)))
        .getSingleOrNull();
  }

  Future<void> upsertCalendarRange({
    required String groupId,
    required String rangeKey,
    required String eventsJson,
  }) async {
    await into(calendarCaches).insert(
      CalendarCachesCompanion(
        groupId: Value(groupId),
        rangeKey: Value(rangeKey),
        eventsJson: Value(eventsJson),
        updatedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
    await _pruneRangeCache('calendar_caches', groupId);
  }

  Future<MealPlanCache?> getMealPlanRange(String groupId, String rangeKey) {
    return (select(mealPlanCaches)
          ..where(
              (t) => t.groupId.equals(groupId) & t.rangeKey.equals(rangeKey)))
        .getSingleOrNull();
  }

  Future<void> upsertMealPlanRange({
    required String groupId,
    required String rangeKey,
    required String plansJson,
  }) async {
    await into(mealPlanCaches).insert(
      MealPlanCachesCompanion(
        groupId: Value(groupId),
        rangeKey: Value(rangeKey),
        plansJson: Value(plansJson),
        updatedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
    await _pruneRangeCache('meal_plan_caches', groupId);
  }

  /// Drops all but the [kRangeCacheRetained] most recently written windows for
  /// [groupId]. Table name is a compile-time constant from the two callers
  /// above, never user input.
  Future<void> _pruneRangeCache(String table, String groupId) async {
    await customUpdate(
      'DELETE FROM $table WHERE group_id = ? AND range_key NOT IN '
      '(SELECT range_key FROM $table WHERE group_id = ? '
      'ORDER BY updated_at DESC LIMIT ?)',
      variables: [
        Variable<String>(groupId),
        Variable<String>(groupId),
        Variable<int>(kRangeCacheRetained),
      ],
      updates: {calendarCaches, mealPlanCaches},
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

  /// Constant key for the single-row household-list cache.
  static const groupsCacheKey = 'me';

  Stream<GroupsCache?> watchGroupsList() {
    return (select(groupsCaches)
          ..where((t) => t.cacheKey.equals(groupsCacheKey)))
        .watchSingleOrNull();
  }

  Future<GroupsCache?> getGroupsListOnce() {
    return (select(groupsCaches)
          ..where((t) => t.cacheKey.equals(groupsCacheKey)))
        .getSingleOrNull();
  }

  Future<void> upsertGroupsList(String groupsJson) async {
    await into(groupsCaches).insert(
      GroupsCachesCompanion(
        cacheKey: const Value(groupsCacheKey),
        groupsJson: Value(groupsJson),
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

  // ---------------------------------------------------------------------------
  // Response cache (offline fallback for GET requests)
  // ---------------------------------------------------------------------------

  /// Upper bound on cached responses. Paginated lists and per-chore assignment
  /// reads each get their own row, so a busy household accumulates a few
  /// hundred; the oldest are evicted once this is exceeded.
  static const int maxResponseCacheRows = 600;

  Future<ResponseCache?> getResponseCache(String cacheKey) {
    return (select(responseCaches)..where((t) => t.cacheKey.equals(cacheKey)))
        .getSingleOrNull();
  }

  Future<void> upsertResponseCache({
    required String cacheKey,
    required int statusCode,
    required String bodyJson,
  }) async {
    await into(responseCaches).insert(
      ResponseCachesCompanion(
        cacheKey: Value(cacheKey),
        statusCode: Value(statusCode),
        bodyJson: Value(bodyJson),
        updatedAt: Value(DateTime.now()),
      ),
      mode: InsertMode.insertOrReplace,
    );
    await _pruneResponseCache();
  }

  Future<void> _pruneResponseCache() async {
    final count = await responseCaches.count().getSingle();
    if (count <= maxResponseCacheRows) return;
    final overflow = count - maxResponseCacheRows;
    final stale = await (select(responseCaches)
          ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)])
          ..limit(overflow))
        .get();
    if (stale.isEmpty) return;
    await (delete(responseCaches)
          ..where((t) => t.cacheKey.isIn(stale.map((r) => r.cacheKey))))
        .go();
  }

  Future<void> clearResponseCache() => delete(responseCaches).go();

  Future<void> clearAllUserData() {
    return transaction(() async {
      await delete(hubActivityCaches).go();
      await delete(hubGroupCaches).go();
      await delete(groupsCaches).go();
      await delete(pinwallPostsCaches).go();
      await delete(currentChoresCaches).go();
      await delete(settlementsCaches).go();
      await delete(calendarCaches).go();
      await delete(mealPlanCaches).go();
      await delete(responseCaches).go();
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
      await (delete(localItemSignalsTable)).go();
    });
  }

  // ---------------------------------------------------------------------------
  // Grocery graph — local (pre-promotion) novel-word signals
  // ---------------------------------------------------------------------------

  /// The pending signal for a household + normalised name, or null if this word
  /// has never been checked off unresolved before.
  Future<LocalItemSignalsTableData?> getLocalItemSignal({
    required String groupId,
    required String normalizedName,
  }) {
    return (select(localItemSignalsTable)
          ..where((t) =>
              t.groupId.equals(groupId) &
              t.normalizedName.equals(normalizedName)))
        .getSingleOrNull();
  }

  /// Upserts a pending novel-word signal (composite PK: group + normalised
  /// name). Callers read the current row, compute the new count, and write the
  /// full companion back.
  Future<void> upsertLocalItemSignal(LocalItemSignalsTableCompanion row) {
    return into(localItemSignalsTable).insertOnConflictUpdate(row);
  }

  // ---------------------------------------------------------------------------
  // Grocery graph — canonical items
  // ---------------------------------------------------------------------------

  /// Exclusive upper bound for a `>= prefix AND < bound` range scan — the
  /// prefix with its last code unit incremented (e.g. "mil" → "mim"). Returns
  /// null only for the degenerate all-`0xFFFF` prefix, in which case callers
  /// fall back to a lower-bound-only scan. This is what lets an equality index
  /// on `alias_text` drive a prefix search: SQLite's `LIKE` is case-insensitive
  /// by default and therefore *cannot* use a BINARY index, so a bare
  /// `alias_text LIKE 'mil%'` degrades to a full scan of the ~280k-row seed on
  /// every keystroke. A range predicate is index-sargable and stays O(log n).
  static String? _prefixUpperBound(String prefix) {
    final units = prefix.codeUnits.toList();
    for (var i = units.length - 1; i >= 0; i--) {
      if (units[i] < 0xFFFF) {
        units[i] += 1;
        return String.fromCharCodes(units.sublist(0, i + 1));
      }
    }
    return null;
  }

  /// Prefix search over aliases for typed autocomplete (e.g. "mlch" → Milch).
  /// Driven by the `alias_text` index via a range scan (see [_prefixUpperBound]);
  /// includes household + global seed aliases. Alias text is stored already
  /// lowercased/normalised, and the composer lowercases the query, so a BINARY
  /// range comparison matches the same rows the old `LIKE 'prefix%'` did.
  Future<List<ItemAliasesTableData>> searchAliasPrefix({
    required String groupId,
    required String query,
    int limit = 40,
  }) async {
    if (query.isEmpty) return const [];
    final lower = query;
    final upper = _prefixUpperBound(lower);
    final mainRows = await (select(itemAliasesTable)
          ..where((t) {
            final range = upper == null
                ? t.aliasText.isBiggerOrEqualValue(lower)
                : t.aliasText.isBiggerOrEqualValue(lower) &
                    t.aliasText.isSmallerThanValue(upper);
            // The `__global__` disjunct is dead in production (the migration
            // evicted those rows; they live in the reference DB now) but lets
            // tests that seed global rows straight into the main DB keep working
            // without attaching a reference DB.
            return (t.groupId.equals(groupId) |
                    t.groupId.equals(kGlobalGroupId)) &
                t.deletedAt.isNull() &
                range;
          })
          ..orderBy([(t) => OrderingTerm.desc(t.weight)])
          ..limit(limit))
        .get();
    final refRows =
        _reference?.searchAliasPrefix(query: query, limit: limit) ?? const [];
    return _mergeAliasesByWeight(mainRows, refRows, limit);
  }

  /// Merges household (main) and global (ref) alias rows, household first on a
  /// weight tie (household corrections carry >= the seed weight), then by weight
  /// DESC, capped at [limit]. Household rows are passed first so the
  /// insertion-order tiebreak keeps a corrected mapping ahead of the seed —
  /// `List.sort` is not stable, so the index tiebreak is explicit.
  List<ItemAliasesTableData> _mergeAliasesByWeight(
    List<ItemAliasesTableData> household,
    List<ItemAliasesTableData> global,
    int limit,
  ) {
    final merged = [...household, ...global];
    final order = List<int>.generate(merged.length, (i) => i);
    order.sort((a, b) {
      final w = merged[b].weight.compareTo(merged[a].weight);
      return w != 0 ? w : a.compareTo(b);
    });
    final ordered = [for (final i in order) merged[i]];
    return ordered.length > limit ? ordered.sublist(0, limit) : ordered;
  }

  /// Word-level prefix search via FTS5 over alias text.
  ///
  /// Unlike [searchAliasPrefix] (which requires the query to match the *start*
  /// of the whole alias string), this method matches any *word* within the alias
  /// that starts with the query token. For example:
  ///   - "pad"  → matches "breast pads", "sanitary pad", "changing pad"
  ///   - "corn" → matches "corn flakes", "corn starch", "cornflakes" (no-space variant)
  ///   - "pring"→ matches "pringles" (curated brand alias on potato_chips)
  ///
  /// Multi-word queries (e.g. "breast pad") split into tokens and each word
  /// must prefix-match independently within the alias text.
  ///
  /// Returns alias rows ordered by weight DESC (same as [searchAliasPrefix]).
  /// Used by [GrocerySuggestionService] as a supplemental Tier 0 result when
  /// the whole-string prefix finds nothing or too few results.
  Future<List<ItemAliasesTableData>> searchAliasWordPrefix({
    required String groupId,
    required String query,
    int limit = 80,
  }) async {
    // The FTS5 word-prefix index lives only in the read-only reference DB (the
    // global seed/OFF aliases). Household correction rows are few and exact, so
    // they're covered by the whole-string [searchAliasPrefix] range scan on the
    // main DB; no FTS is maintained there.
    return _reference?.searchAliasWordPrefix(query: query, limit: limit) ??
        const [];
  }

  Future<List<CanonicalItemsTableData>> getCanonicalItemsByIds(
      Iterable<String> ids) async {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return const [];
    final mainRows = await (select(canonicalItemsTable)
          ..where((t) => t.id.isIn(list) & t.deletedAt.isNull()))
        .get();
    final seen = {for (final r in mainRows) r.id};
    final missing = list.where((id) => !seen.contains(id));
    final refRows = _reference?.getCanonicalItemsByIds(missing) ?? const [];
    return [...mainRows, ...refRows];
  }

  Future<CanonicalItemsTableData?> getCanonicalItemById(String id) async {
    final main = await (select(canonicalItemsTable)
          ..where((t) => t.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
    if (main != null) return main;
    return _reference?.getCanonicalItemById(id);
  }

  Future<List<CanonicalItemsTableData>> getCanonicalItemsByGroup(
      String groupId) async {
    // Household + delta-synced canonical items from the main DB, unioned with
    // the global reference; a household/delta row shadows a ref row of the same
    // id. The `is_global` disjunct is dead in production (those rows moved to
    // the reference DB) but keeps tests that seed global rows into the main DB
    // working without a reference DB.
    final mainRows = await (select(canonicalItemsTable)
          ..where((t) =>
              (t.groupId.equals(groupId) | t.isGlobal.equals(true)) &
              t.deletedAt.isNull()))
        .get();
    final seen = {for (final r in mainRows) r.id};
    final refRows = _reference?.getAllCanonicalGlobal() ?? const [];
    return [...mainRows, ...refRows.where((r) => !seen.contains(r.id))];
  }

  Future<bool> hasCanonicalItemsByGroup(String groupId) async {
    final row = await (selectOnly(canonicalItemsTable)
          ..addColumns([canonicalItemsTable.id])
          ..where((canonicalItemsTable.groupId.equals(groupId) |
                  canonicalItemsTable.isGlobal.equals(true)) &
              canonicalItemsTable.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    if (row != null) return true;
    return _reference?.hasCanonicalItems() ?? false;
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
      b.deleteWhere<ItemAliasesTable, ItemAliasesTableData>(itemAliasesTable,
          (t) => t.groupId.equals(globalGroupId) & t.source.equals('seed'));
      b.deleteWhere<CanonicalItemsTable, CanonicalItemsTableData>(
          canonicalItemsTable,
          (t) => t.groupId.equals(globalGroupId) | t.isGlobal.equals(true));
    });
  }

  /// Deletes the global aliases that came from a given [source] (e.g. 'off').
  /// Used to re-ingest a versioned external alias set without disturbing the
  /// seed aliases or household corrections.
  Future<void> clearGlobalAliasesBySource(
      String globalGroupId, String source) async {
    await (delete(itemAliasesTable)
          ..where(
              (t) => t.groupId.equals(globalGroupId) & t.source.equals(source)))
        .go();
  }

  // ---------------------------------------------------------------------------
  // Grocery graph — aliases (hot lookup path)
  // ---------------------------------------------------------------------------

  Future<ItemAliasesTableData?> findAlias({
    required String groupId,
    required String aliasText,
  }) async {
    final main = await (select(itemAliasesTable)
          ..where((t) =>
              (t.groupId.equals(groupId) | t.groupId.equals(kGlobalGroupId)) &
              t.aliasText.equals(aliasText) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.weight)])
          ..limit(1))
        .getSingleOrNull();
    final refList = _reference?.findAlias(aliasText) ?? const [];
    final ref = refList.isEmpty ? null : refList.first;
    if (main == null) return ref;
    if (ref == null) return main;
    // Household wins on a weight tie (a correction outranks the seed mapping).
    return ref.weight > main.weight ? ref : main;
  }

  /// Batch form of [findAlias]: for each text in [aliasTexts], the top-weighted
  /// non-deleted household-or-global alias row. Returns a map keyed by
  /// alias_text; texts with no alias are absent.
  Future<Map<String, ItemAliasesTableData>> findAliasesByTexts({
    required String groupId,
    required Set<String> aliasTexts,
  }) async {
    if (aliasTexts.isEmpty) return const {};
    final mainRows = await (select(itemAliasesTable)
          ..where((t) =>
              (t.groupId.equals(groupId) | t.groupId.equals(kGlobalGroupId)) &
              t.aliasText.isIn(aliasTexts.toList()) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.weight)]))
        .get();
    final refRows = _reference?.findAliasesByTexts(aliasTexts) ?? const [];
    // Household rows first so putIfAbsent keeps a correction over the seed;
    // within each source the query already ordered by weight DESC.
    final out = <String, ItemAliasesTableData>{};
    for (final r in [...mainRows, ...refRows]) {
      out.putIfAbsent(r.aliasText, () => r);
    }
    return out;
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
  }) async {
    final mainRows = await (select(itemAliasesTable)
          ..where((t) =>
              (t.groupId.equals(groupId) | t.groupId.equals(kGlobalGroupId)) &
              t.aliasText.equals(aliasText) &
              t.deletedAt.isNull()))
        .get();
    final refRows = _reference?.findAliasesByText(aliasText) ?? const [];
    return [...mainRows, ...refRows];
  }

  /// Loads all non-deleted aliases for a household + global seed aliases.
  /// Used by the fuzzy resolver when no exact match is found.
  ///
  /// NOTE: with the full global seed this returns ~120k rows. Prefer
  /// [getAliasFuzzyCandidates] for the hot resolve path.
  Future<List<ItemAliasesTableData>> getItemAliasesForFuzzy(
      String groupId) async {
    final mainRows = await (select(itemAliasesTable)
          ..where((t) =>
              (t.groupId.equals(groupId) | t.groupId.equals(kGlobalGroupId)) &
              t.deletedAt.isNull()))
        .get();
    final refRows = _reference?.getItemAliasesForFuzzy() ?? const [];
    return [...mainRows, ...refRows];
  }

  /// Indexed prefilter for fuzzy resolution: only aliases that share the query's
  /// first character and are within ±2 in length. Uses the `alias_text` index
  /// for the prefix `LIKE`, cutting the candidate set from ~120k to typically a
  /// few hundred before edit-distance scoring runs in Dart.
  Future<List<ItemAliasesTableData>> getAliasFuzzyCandidates({
    required String groupId,
    required String query,
    int maxCandidates = 400,
  }) async {
    if (query.isEmpty) return const [];
    final lo = (query.length - 2).clamp(1, 1 << 30);
    final hi = query.length + 2;
    // First-character range scan (index-sargable) instead of `LIKE 'x%'`, which
    // can't use the BINARY `alias_text` index — see [searchAliasPrefix].
    final firstChar = query.substring(0, 1);
    final upper = _prefixUpperBound(firstChar);
    final mainRows = await (select(itemAliasesTable)
          ..where((t) {
            final range = upper == null
                ? t.aliasText.isBiggerOrEqualValue(firstChar)
                : t.aliasText.isBiggerOrEqualValue(firstChar) &
                    t.aliasText.isSmallerThanValue(upper);
            return (t.groupId.equals(groupId) |
                    t.groupId.equals(kGlobalGroupId)) &
                t.deletedAt.isNull() &
                t.aliasText.length.isBetweenValues(lo, hi) &
                range;
          })
          ..orderBy([(t) => OrderingTerm.desc(t.weight)])
          ..limit(maxCandidates))
        .get();
    final refRows = _reference?.getAliasFuzzyCandidates(
            query: query, maxCandidates: maxCandidates) ??
        const [];
    return _mergeAliasesByWeight(mainRows, refRows, maxCandidates);
  }

  Future<void> upsertItemAliases(
      Iterable<ItemAliasesTableCompanion> rows) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(
          itemAliasesTable, rows.toList(growable: false));
    });
  }

  /// Fast-path bulk insert for `item_aliases_table`, bypassing the
  /// Companion/Table insert machinery that [upsertItemAliases] uses.
  ///
  /// For the one-time ~280k-row grocery seed, [upsertItemAliases] measured
  /// ~6-7s (with FTS triggers already dropped, see [dropAliasFtsTriggers]) —
  /// this measured ~1.8s for the same data. There is nothing wrong with
  /// [upsertItemAliases] for normal-sized writes; the gap is Companion→SQL
  /// conversion overhead that only matters at seed-sized row counts, so this
  /// method exists solely for that bulk-load path, not as a general
  /// replacement.
  ///
  /// Each row in [rows] must be exactly:
  /// `[id, groupId, canonicalItemId, aliasText, lang, source, weight,
  /// version, createdAt, updatedAt]` — the two [DateTime]s are converted to
  /// epoch seconds here to match how drift itself encodes `DateTimeColumn`
  /// (confirmed empirically: `typeof(created_at)` is `integer`, matching
  /// seconds-since-epoch, not milliseconds or ISO text).
  Future<void> bulkInsertItemAliasesRaw(
    List<
            (
              String id,
              String groupId,
              String canonicalItemId,
              String aliasText,
              String lang,
              String source,
              int weight,
              int version,
              DateTime createdAt,
              DateTime updatedAt,
            )>
        rows,
  ) async {
    const sql = '''
INSERT INTO item_aliases_table
  (id, group_id, canonical_item_id, alias_text, lang, source, weight, version, created_at, updated_at)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ON CONFLICT(id) DO UPDATE SET
    group_id = excluded.group_id,
    canonical_item_id = excluded.canonical_item_id,
    alias_text = excluded.alias_text,
    lang = excluded.lang,
    source = excluded.source,
    weight = excluded.weight,
    version = excluded.version,
    created_at = excluded.created_at,
    updated_at = excluded.updated_at;
''';
    await batch((b) {
      for (final r in rows) {
        b.customStatement(sql, [
          r.$1,
          r.$2,
          r.$3,
          r.$4,
          r.$5,
          r.$6,
          r.$7,
          r.$8,
          r.$9.toUtc().millisecondsSinceEpoch ~/ 1000,
          r.$10.toUtc().millisecondsSinceEpoch ~/ 1000,
        ]);
      }
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

  Future<List<CorrectionsTableData>> getRejectCorrections({
    required String groupId,
    required String rawText,
  }) {
    return (select(correctionsTable)
          ..where((t) =>
              t.groupId.equals(groupId) &
              t.kind.equals('reject') &
              t.rawText.equals(rawText)))
        .get();
  }

  Future<List<CorrectionsTableData>> getUnappliedCorrections(String groupId) {
    return (select(correctionsTable)
          ..where((t) => t.groupId.equals(groupId) & t.appliedAt.isNull()))
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
  }) async {
    // A household aisle override (real group id in the main DB) wins over the
    // shipped global layout. `ORDER BY group_id DESC` keeps a real group ahead
    // of `__global__`; the `__global__` disjunct is dead in production (global
    // layouts live in the reference DB) but lets tests that seed global aisles
    // into the main DB resolve without a reference DB.
    final main = await (select(storeAislesTable)
          ..where((t) =>
              (t.groupId.equals(groupId) | t.groupId.equals(kGlobalGroupId)) &
              t.storeId.equals(storeId) &
              t.canonicalItemId.equals(canonicalItemId) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.groupId)])
          ..limit(1))
        .getSingleOrNull();
    if (main != null) return main;
    return _reference?.getStoreAisle(
        storeId: storeId, canonicalItemId: canonicalItemId);
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
  }) async {
    // Callers that need both global and household layouts (e.g. scan_review)
    // query each group id separately and merge. A `__global__` request reads any
    // global rows still in the main DB (test seeding) unioned with the shipped
    // reference layout; a household request stays on the main DB.
    final mainRows = await (select(storeAislesTable)
          ..where((t) =>
              t.groupId.equals(groupId) &
              (storeId == null
                  ? const Constant(true)
                  : t.storeId.equals(storeId)) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    if (groupId != kGlobalGroupId) return mainRows;
    final refRows = _reference?.getStoreAisles(storeId: storeId) ?? const [];
    final merged = [...mainRows, ...refRows];
    merged.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return merged;
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
          ..where(
              (t) => t.groupId.equals(groupId) & t.canonicalItemId.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.purchasedAt)])
          ..limit(limit))
        .get();
  }

  /// Bounded history for the household-prior scorer.
  ///
  /// The recent window supplies decay and weekday features. The per-item tail
  /// retains enough older observations to estimate sparse or quarterly cadence
  /// without loading the household's unbounded event history.
  Future<List<PurchaseHistoryTableData>> getGroupPurchaseHistoryForPrior({
    required String groupId,
    required DateTime since,
    int recentLimit = 5000,
    int cadencePerItemLimit = 10,
  }) async {
    final recent = await (select(purchaseHistoryTable)
          ..where((t) =>
              t.groupId.equals(groupId) &
              t.canonicalItemId.isNotNull() &
              t.purchasedAt.isBiggerOrEqualValue(since))
          ..orderBy([
            (t) => OrderingTerm.desc(t.purchasedAt),
            (t) => OrderingTerm.desc(t.id),
          ])
          ..limit(recentLimit))
        .get();

    final cadenceRows = await customSelect(
      '''SELECT id, group_id, canonical_item_id, list_item_id, quantity, unit,
                version, purchased_at
           FROM (
             SELECT ph.*,
                    ROW_NUMBER() OVER (
                      PARTITION BY canonical_item_id
                      ORDER BY purchased_at DESC, id DESC
                    ) AS prior_row_number
               FROM purchase_history_table ph
              WHERE group_id = ? AND canonical_item_id IS NOT NULL
           ) ranked
          WHERE prior_row_number <= ?
          ORDER BY purchased_at DESC, id DESC''',
      variables: [
        Variable.withString(groupId),
        Variable.withInt(cadencePerItemLimit),
      ],
      readsFrom: {purchaseHistoryTable},
    ).get();

    final byId = <String, PurchaseHistoryTableData>{
      for (final row in recent) row.id: row,
    };
    for (final row in cadenceRows) {
      final purchase = purchaseHistoryTable.map(row.data);
      byId.putIfAbsent(purchase.id, () => purchase);
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final dateOrder = b.purchasedAt.compareTo(a.purchasedAt);
        return dateOrder != 0 ? dateOrder : b.id.compareTo(a.id);
      });
    return merged;
  }

  Future<Map<String, int>> getGroupPurchaseCountsForPrior({
    required String groupId,
  }) async {
    final rows = await customSelect(
      '''SELECT canonical_item_id, COUNT(*) AS purchase_count
           FROM purchase_history_table
          WHERE group_id = ? AND canonical_item_id IS NOT NULL
          GROUP BY canonical_item_id''',
      variables: [Variable.withString(groupId)],
      readsFrom: {purchaseHistoryTable},
    ).get();
    return {
      for (final row in rows)
        row.read<String>('canonical_item_id'): row.read<int>('purchase_count'),
    };
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

  /// Strongest bounded co-occurrence rows for one household.
  Future<List<ItemCooccurrenceTableData>> getGroupCooccurrences({
    required String groupId,
    int limit = 2000,
  }) {
    return (select(itemCooccurrenceTable)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.count),
            (t) => OrderingTerm.desc(t.lastSeenAt),
            (t) => OrderingTerm.asc(t.itemAId),
            (t) => OrderingTerm.asc(t.itemBId),
          ])
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
      [groupId, a, b, now.millisecondsSinceEpoch ~/ 1000],
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
  Future<List<ListItemsTableData>> getCheckedItemsWithCanonical(String listId) {
    return (select(listItemsTable)
          ..where((t) =>
              t.listId.equals(listId) &
              t.checked.equals(true) &
              t.canonicalItemId.isNotNull()))
        .get();
  }

  /// Live per-list (open, total) item counts for a group — one grouped query
  /// driving the hub cards' "N left" label. Lists with no locally-synced items
  /// simply have no entry; callers fall back to the server's item_count.
  Stream<Map<String, ({int open, int total})>> watchItemCountsByGroup(
      String groupId) {
    final query = customSelect(
      'SELECT li.list_id AS list_id, '
      '  SUM(CASE WHEN li.checked = 0 THEN 1 ELSE 0 END) AS open_count, '
      '  COUNT(*) AS total_count '
      'FROM list_items_table li '
      'JOIN lists_table l ON l.id = li.list_id '
      'WHERE l.group_id = ? '
      'GROUP BY li.list_id',
      variables: [Variable.withString(groupId)],
      readsFrom: {listItemsTable, listsTable},
    );
    return query.watch().map((rows) => {
          for (final r in rows)
            r.read<String>('list_id'): (
              open: r.read<int>('open_count'),
              total: r.read<int>('total_count'),
            ),
        });
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
