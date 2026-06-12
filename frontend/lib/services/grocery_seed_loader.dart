import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../storage/app_database.dart';

const _seedAsset = 'assets/grocery/seed.json';
const _storeAislesAsset = 'assets/grocery/store_aisles.json';
const _globalGroupId = '__global__';
const _storeAislesVersionKey = '__store_aisles__';
const _uuid = Uuid();

class GrocerySeedLoader {
  final AppDatabase _db;

  GrocerySeedLoader(this._db);

  /// Load the bundled grocery seed into Drift.
  ///
  /// Safe to call on every cold start. The bundled asset carries a `version`;
  /// if it is newer than the version already ingested, the previous global
  /// seed is cleared and the new one re-ingested. Household-scoped data is
  /// never touched. Skips work entirely when already up to date.
  Future<void> loadIfNeeded() async {
    final raw = await rootBundle.loadString(_seedAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final assetVersion = (json['version'] as num?)?.toInt() ?? 0;

    final installedVersion = await _db.getGroceryVersion(_globalGroupId);
    final existing = await _db.getCanonicalItemsByGroup(_globalGroupId);
    if (existing.isNotEmpty && installedVersion >= assetVersion) return;

    if (existing.isNotEmpty) {
      await _db.clearGlobalSeed(_globalGroupId);
    }
    await _ingestSeed(json);
    await _db.setGroceryVersion(_globalGroupId, assetVersion);

    await _loadStoreAislesIfNeeded();
  }

  /// Ingests the shipped global store layouts (item → aisle + shopping-path
  /// sort order, per store). Version-aware and global; household overrides are
  /// kept in separate rows and never cleared here.
  Future<void> _loadStoreAislesIfNeeded() async {
    final raw = await rootBundle.loadString(_storeAislesAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final assetVersion = (json['version'] as num?)?.toInt() ?? 0;
    final installed = await _db.getGroceryVersion(_storeAislesVersionKey);
    if (installed >= assetVersion) return;

    await _db.clearGlobalStoreAisles(_globalGroupId);

    final aisles = (json['aisles'] as List).cast<Map<String, dynamic>>();
    final now = DateTime.now();
    final rows = <StoreAislesTableCompanion>[
      for (final a in aisles)
        StoreAislesTableCompanion.insert(
          id: _uuid.v4(),
          groupId: _globalGroupId,
          storeId: Value(a['store_id'] as String?),
          canonicalItemId: a['canonical_item_id'] as String,
          aisle: Value(a['aisle'] as String? ?? ''),
          sortOrder: Value((a['sort_order'] as num?)?.toInt() ?? 0),
          confidence: Value((a['confidence'] as num?)?.toDouble() ?? 0.5),
          version: const Value(0),
          createdAt: now,
          updatedAt: now,
        ),
    ];
    for (final chunk in _chunked(rows, 2000)) {
      await _db.upsertStoreAisles(chunk);
    }
    await _db.setGroceryVersion(_storeAislesVersionKey, assetVersion);
  }

  Future<void> _ingestSeed(Map<String, dynamic> json) async {
    final items = (json['items'] as List).cast<Map<String, dynamic>>();
    final now = DateTime.now();

    final canonicalRows = <CanonicalItemsTableCompanion>[];
    final aliasRows = <ItemAliasesTableCompanion>[];

    for (final item in items) {
      final id = item['id'] as String;
      canonicalRows.add(CanonicalItemsTableCompanion.insert(
        id: id,
        groupId: _globalGroupId,
        nameDe: Value(item['name_de'] as String? ?? ''),
        nameEn: Value(item['name_en'] as String? ?? ''),
        category: Value(item['category'] as String? ?? ''),
        defaultUnit: Value(item['default_unit'] as String? ?? ''),
        isGlobal: const Value(true),
        version: const Value(0),
        createdAt: now,
        updatedAt: now,
      ));

      void addAlias(String text, String lang) {
        final normalized = text.toLowerCase().trim();
        if (normalized.isEmpty) return;
        aliasRows.add(ItemAliasesTableCompanion.insert(
          id: _uuid.v4(),
          groupId: _globalGroupId,
          canonicalItemId: id,
          aliasText: normalized,
          lang: Value(lang),
          source: const Value('seed'),
          weight: const Value(1),
          version: const Value(0),
          createdAt: now,
          updatedAt: now,
        ));
      }

      for (final a in (item['aliases_de'] as List? ?? [])) {
        addAlias(a as String, 'de');
      }
      for (final a in (item['aliases_en'] as List? ?? [])) {
        addAlias(a as String, 'en');
      }
      // Also alias by canonical German and English name.
      addAlias(item['name_de'] as String, 'de');
      addAlias(item['name_en'] as String, 'en');
    }

    // Insert in chunks so a full-seed reingest doesn't hold ~120k companions
    // in one batch / allocation spike on low-end devices.
    for (final chunk in _chunked(canonicalRows, 1000)) {
      await _db.upsertCanonicalItems(chunk);
    }
    for (final chunk in _chunked(aliasRows, 4000)) {
      await _db.upsertItemAliases(chunk);
    }
  }

  static Iterable<List<T>> _chunked<T>(List<T> rows, int size) sync* {
    for (var i = 0; i < rows.length; i += size) {
      yield rows.sublist(i, i + size > rows.length ? rows.length : i + size);
    }
  }
}
