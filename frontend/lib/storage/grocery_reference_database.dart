import 'grocery_reference_sqlite_web.dart'
    if (dart.library.io) 'package:sqlite3/sqlite3.dart';

import 'app_database.dart'
    show CanonicalItemsTableData, ItemAliasesTableData, StoreAislesTableData;

/// Read-only accessor over the prebuilt global grocery reference file
/// (`grocery_ref.sqlite`), shipped as a bundled asset and copied into place by
/// [GroceryReferenceInstaller]. It holds ONLY the static global brain —
/// canonical items, seed/OFF aliases (+ the `item_aliases_fts` index), and the
/// shipped store layouts — all with `group_id = '__global__'`.
///
/// It intentionally does NOT use drift codegen: drift would emit its own
/// duplicate `*TableData` classes for the shared tables, which can't be merged
/// with [AppDatabase]'s. Backing it with `package:sqlite3` directly lets its
/// methods return AppDatabase's row types so the two can be unioned in Dart.
/// Every used query is bounded/indexed (single lookups, prefix range scans, an
/// FTS top-N), so the synchronous reads are cheap.
class GroceryReferenceDatabase {
  final Database _db;

  GroceryReferenceDatabase._(this._db);

  /// Empty reference used on web, where the bundled JSON data is loaded into
  /// the main Drift/WASM database instead of opening a native SQLite file.
  factory GroceryReferenceDatabase.empty() {
    return GroceryReferenceDatabase._(
      sqlite3.open('', mode: OpenMode.readOnly),
    );
  }

  /// Opens the prebuilt file read-only. The file already contains the full
  /// schema + data, so nothing is created or migrated.
  factory GroceryReferenceDatabase.open(String path) {
    return GroceryReferenceDatabase._(
        sqlite3.open(path, mode: OpenMode.readOnly));
  }

  void close() => _db.dispose();

  // ---- Row mappers (drift stores DateTime as integer unix seconds) ----

  static DateTime _ts(Object? v) =>
      DateTime.fromMillisecondsSinceEpoch(((v as int?) ?? 0) * 1000);

  static DateTime? _tsN(Object? v) =>
      v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as int) * 1000);

  static ItemAliasesTableData _alias(Row r) => ItemAliasesTableData(
        id: r['id'] as String,
        groupId: r['group_id'] as String,
        canonicalItemId: r['canonical_item_id'] as String,
        aliasText: r['alias_text'] as String,
        lang: (r['lang'] as String?) ?? 'und',
        source: (r['source'] as String?) ?? 'correction',
        weight: (r['weight'] as int?) ?? 1,
        version: (r['version'] as int?) ?? 0,
        createdAt: _ts(r['created_at']),
        updatedAt: _ts(r['updated_at']),
        deletedAt: _tsN(r['deleted_at']),
      );

  static CanonicalItemsTableData _canonical(Row r) => CanonicalItemsTableData(
        id: r['id'] as String,
        groupId: r['group_id'] as String,
        nameDe: (r['name_de'] as String?) ?? '',
        nameEn: (r['name_en'] as String?) ?? '',
        nameFr: (r['name_fr'] as String?) ?? '',
        nameEs: (r['name_es'] as String?) ?? '',
        category: (r['category'] as String?) ?? '',
        defaultUnit: (r['default_unit'] as String?) ?? '',
        productId: r['product_id'] as String?,
        isGlobal: ((r['is_global'] as int?) ?? 0) == 1,
        version: (r['version'] as int?) ?? 0,
        createdAt: _ts(r['created_at']),
        updatedAt: _ts(r['updated_at']),
        deletedAt: _tsN(r['deleted_at']),
      );

  static StoreAislesTableData _aisle(Row r) => StoreAislesTableData(
        id: r['id'] as String,
        groupId: r['group_id'] as String,
        storeId: r['store_id'] as String?,
        canonicalItemId: r['canonical_item_id'] as String,
        aisle: (r['aisle'] as String?) ?? '',
        sortOrder: (r['sort_order'] as int?) ?? 0,
        confidence: (r['confidence'] as num?)?.toDouble() ?? 0.5,
        version: (r['version'] as int?) ?? 0,
        createdAt: _ts(r['created_at']),
        updatedAt: _ts(r['updated_at']),
        deletedAt: _tsN(r['deleted_at']),
      );

  // Mirror of AppDatabase._prefixUpperBound: exclusive upper bound so an
  // equality index on alias_text can drive a prefix range scan.
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

  // ---- Aliases (all rows are global; no group filter needed) ----

  List<ItemAliasesTableData> findAlias(String aliasText) {
    final rs = _db.select(
      'SELECT * FROM item_aliases_table WHERE alias_text = ? AND deleted_at IS NULL '
      'ORDER BY weight DESC LIMIT 1',
      [aliasText],
    );
    return rs.map(_alias).toList();
  }

  List<ItemAliasesTableData> findAliasesByText(String aliasText) {
    final rs = _db.select(
      'SELECT * FROM item_aliases_table WHERE alias_text = ? AND deleted_at IS NULL',
      [aliasText],
    );
    return rs.map(_alias).toList();
  }

  List<ItemAliasesTableData> findAliasesByTexts(Set<String> aliasTexts) {
    if (aliasTexts.isEmpty) return const [];
    final list = aliasTexts.toList();
    final placeholders = List.filled(list.length, '?').join(',');
    final rs = _db.select(
      'SELECT * FROM item_aliases_table WHERE alias_text IN ($placeholders) '
      'AND deleted_at IS NULL ORDER BY weight DESC',
      list,
    );
    return rs.map(_alias).toList();
  }

  List<ItemAliasesTableData> getItemAliasesForFuzzy() {
    final rs =
        _db.select('SELECT * FROM item_aliases_table WHERE deleted_at IS NULL');
    return rs.map(_alias).toList();
  }

  List<ItemAliasesTableData> getAliasFuzzyCandidates({
    required String query,
    int maxCandidates = 400,
  }) {
    if (query.isEmpty) return const [];
    final lo = (query.length - 2).clamp(1, 1 << 30);
    final hi = query.length + 2;
    final firstChar = query.substring(0, 1);
    final upper = _prefixUpperBound(firstChar);
    final where = upper == null
        ? 'alias_text >= ?'
        : 'alias_text >= ? AND alias_text < ?';
    final args = <Object?>[
      firstChar,
      if (upper != null) upper,
      lo,
      hi,
      maxCandidates
    ];
    final rs = _db.select(
      'SELECT * FROM item_aliases_table WHERE $where AND deleted_at IS NULL '
      'AND LENGTH(alias_text) BETWEEN ? AND ? ORDER BY weight DESC LIMIT ?',
      args,
    );
    return rs.map(_alias).toList();
  }

  List<ItemAliasesTableData> searchAliasPrefix({
    required String query,
    int limit = 40,
  }) {
    if (query.isEmpty) return const [];
    final upper = _prefixUpperBound(query);
    final where = upper == null
        ? 'alias_text >= ?'
        : 'alias_text >= ? AND alias_text < ?';
    final args = <Object?>[query, if (upper != null) upper, limit];
    final rs = _db.select(
      'SELECT * FROM item_aliases_table WHERE $where AND deleted_at IS NULL '
      'ORDER BY weight DESC LIMIT ?',
      args,
    );
    return rs.map(_alias).toList();
  }

  /// FTS5 word-prefix search over the prebuilt `item_aliases_fts` index.
  List<ItemAliasesTableData> searchAliasWordPrefix({
    required String query,
    int limit = 80,
  }) {
    if (query.isEmpty) return const [];
    final tokens =
        query.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return const [];
    final ftsMatch = tokens
        .map((t) {
          final safe = t
              .replaceAll('"', '')
              .replaceAll('(', '')
              .replaceAll(')', '')
              .trim();
          if (safe.isEmpty) return null;
          return '$safe*';
        })
        .whereType<String>()
        .join(' ');
    if (ftsMatch.isEmpty) return const [];
    final rs = _db.select(
      '''
      SELECT a.* FROM item_aliases_fts fts
      JOIN item_aliases_table a ON a.rowid = fts.rowid
      WHERE item_aliases_fts MATCH ? AND a.deleted_at IS NULL
      ORDER BY a.weight DESC LIMIT ?
      ''',
      [ftsMatch, limit],
    );
    return rs.map(_alias).toList();
  }

  // ---- Canonical items ----

  List<CanonicalItemsTableData> getCanonicalItemsByIds(Iterable<String> ids) {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return const [];
    final placeholders = List.filled(list.length, '?').join(',');
    final rs = _db.select(
      'SELECT * FROM canonical_items_table WHERE id IN ($placeholders) '
      'AND deleted_at IS NULL',
      list,
    );
    return rs.map(_canonical).toList();
  }

  CanonicalItemsTableData? getCanonicalItemById(String id) {
    final rs = _db.select(
      'SELECT * FROM canonical_items_table WHERE id = ? AND deleted_at IS NULL LIMIT 1',
      [id],
    );
    return rs.isEmpty ? null : _canonical(rs.first);
  }

  List<CanonicalItemsTableData> getAllCanonicalGlobal() {
    final rs = _db
        .select('SELECT * FROM canonical_items_table WHERE deleted_at IS NULL');
    return rs.map(_canonical).toList();
  }

  bool hasCanonicalItems() {
    final rs = _db.select('SELECT 1 FROM canonical_items_table LIMIT 1');
    return rs.isNotEmpty;
  }

  // ---- Store aisles (all global) ----

  StoreAislesTableData? getStoreAisle({
    required String storeId,
    required String canonicalItemId,
  }) {
    final rs = _db.select(
      'SELECT * FROM store_aisles_table WHERE store_id = ? AND canonical_item_id = ? '
      'AND deleted_at IS NULL LIMIT 1',
      [storeId, canonicalItemId],
    );
    return rs.isEmpty ? null : _aisle(rs.first);
  }

  List<StoreAislesTableData> getStoreAisles({String? storeId}) {
    final ResultSet rs;
    if (storeId == null) {
      rs = _db.select(
          'SELECT * FROM store_aisles_table WHERE deleted_at IS NULL ORDER BY sort_order');
    } else {
      rs = _db.select(
        'SELECT * FROM store_aisles_table WHERE store_id = ? AND deleted_at IS NULL '
        'ORDER BY sort_order',
        [storeId],
      );
    }
    return rs.map(_aisle).toList();
  }
}
