import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../storage/app_database.dart';
import 'scan/resolution/string_sim.dart';

const _seedAsset = 'assets/grocery/seed.json';
const _seedVersionAsset = 'assets/grocery/seed.version.json';
const _storeAislesAsset = 'assets/grocery/store_aisles.json';
const _offAliasesAsset = 'assets/grocery/off_aliases.json';
const _globalGroupId = '__global__';
const _storeAislesVersionKey = '__store_aisles__';
const _offAliasesVersionKey = '__off_aliases__';
const _uuid = Uuid();

/// Web fallback for the native read-only grocery reference database.
///
/// The browser cannot use `dart:ffi`, so the same bundled canonical catalog,
/// aliases, and aisle mappings are version-gated and loaded into Drift's
/// SQLite/WASM database. Household-scoped rows are never cleared.
class GrocerySeedLoader {
  final AppDatabase _db;
  final AssetBundle _bundle;

  GrocerySeedLoader(
    this._db, {
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;

  Future<void> loadIfNeeded() async {
    await _loadSeedIfNeeded();
    await _loadStoreAislesIfNeeded();
    await _loadOffAliasesIfNeeded();
  }

  Future<void> _loadSeedIfNeeded() async {
    final installedVersion = await _db.getGroceryVersion(_globalGroupId);
    final sidecarVersion = await _readSidecarVersion();
    final hasExisting = await _db.hasCanonicalItemsByGroup(_globalGroupId);
    if (sidecarVersion != null &&
        hasExisting &&
        installedVersion >= sidecarVersion) {
      return;
    }

    final raw = await _bundle.loadString(_seedAsset);
    final json = await compute(_decodeJsonMap, raw);
    final assetVersion = (json['version'] as num?)?.toInt() ?? 0;
    if (hasExisting && installedVersion >= assetVersion) return;

    // Keep each chunk independently committed so normal list writes can run
    // between chunks. The version cursor is written only after a full import,
    // making an interrupted first load safe to retry.
    await _db.dropAliasFtsTriggers();
    try {
      await _db.createAliasIndexes();
      if (hasExisting) {
        await _db.clearGlobalSeed(_globalGroupId);
      }
      await _ingestSeed(json);
      await _db.rebuildAliasFts();
      await _db.setGroceryVersion(_globalGroupId, assetVersion);
    } finally {
      await _db.createAliasFts();
    }
  }

  Future<int?> _readSidecarVersion() async {
    try {
      final raw = await _bundle.loadString(_seedVersionAsset);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (json['version'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadOffAliasesIfNeeded() async {
    final String raw;
    try {
      raw = await _bundle.loadString(_offAliasesAsset);
    } catch (_) {
      return;
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final assetVersion = (json['version'] as num?)?.toInt() ?? 0;
    final installed = await _db.getGroceryVersion(_offAliasesVersionKey);
    if (installed >= assetVersion) return;

    final items = json['items'] as Map<String, dynamic>? ?? {};
    final now = DateTime.now();
    final rows = <ItemAliasesTableCompanion>[];
    items.forEach((canonicalId, byLang) {
      (byLang as Map<String, dynamic>).forEach((lang, list) {
        for (final alias in list as List) {
          final normalized = normaliseText(alias as String);
          if (normalized.isEmpty) continue;
          rows.add(ItemAliasesTableCompanion.insert(
            id: _uuid.v4(),
            groupId: _globalGroupId,
            canonicalItemId: canonicalId,
            aliasText: normalized,
            lang: Value(lang),
            source: const Value('off'),
            weight: const Value(1),
            version: const Value(0),
            createdAt: now,
            updatedAt: now,
          ));
        }
      });
    });

    await _db.clearGlobalAliasesBySource(_globalGroupId, 'off');
    for (final chunk in _chunked(rows, 2000)) {
      await _db.upsertItemAliases(chunk);
    }
    await _db.setGroceryVersion(_offAliasesVersionKey, assetVersion);
  }

  Future<void> _loadStoreAislesIfNeeded() async {
    final raw = await _bundle.loadString(_storeAislesAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final assetVersion = (json['version'] as num?)?.toInt() ?? 0;
    final installed = await _db.getGroceryVersion(_storeAislesVersionKey);
    if (installed >= assetVersion) return;

    final aisles = (json['aisles'] as List).cast<Map<String, dynamic>>();
    final now = DateTime.now();
    final rows = <StoreAislesTableCompanion>[
      for (final aisle in aisles)
        StoreAislesTableCompanion.insert(
          id: _uuid.v4(),
          groupId: _globalGroupId,
          storeId: Value(aisle['store_id'] as String?),
          canonicalItemId: aisle['canonical_item_id'] as String,
          aisle: Value(aisle['aisle'] as String? ?? ''),
          sortOrder: Value((aisle['sort_order'] as num?)?.toInt() ?? 0),
          confidence: Value((aisle['confidence'] as num?)?.toDouble() ?? 0.5),
          version: const Value(0),
          createdAt: now,
          updatedAt: now,
        ),
    ];

    await _db.clearGlobalStoreAisles(_globalGroupId);
    for (final chunk in _chunked(rows, 2000)) {
      await _db.upsertStoreAisles(chunk);
    }
    await _db.setGroceryVersion(_storeAislesVersionKey, assetVersion);
  }

  Future<void> _ingestSeed(Map<String, dynamic> json) async {
    final items = (json['items'] as List).cast<Map<String, dynamic>>();
    final now = DateTime.now();
    final canonicalRows = <CanonicalItemsTableCompanion>[];
    final aliasRows = <(
      String,
      String,
      String,
      String,
      String,
      String,
      int,
      int,
      DateTime,
      DateTime,
    )>[];

    for (final item in items) {
      final id = item['id'] as String;
      canonicalRows.add(CanonicalItemsTableCompanion.insert(
        id: id,
        groupId: _globalGroupId,
        nameDe: Value(item['name_de'] as String? ?? ''),
        nameEn: Value(item['name_en'] as String? ?? ''),
        nameFr: Value(item['name_fr'] as String? ?? ''),
        nameEs: Value(item['name_es'] as String? ?? ''),
        category: Value(item['category'] as String? ?? ''),
        defaultUnit: Value(item['default_unit'] as String? ?? ''),
        isGlobal: const Value(true),
        version: const Value(0),
        createdAt: now,
        updatedAt: now,
      ));

      void addAlias(String text, String lang) {
        final normalized = normaliseText(text);
        if (normalized.isEmpty) return;
        aliasRows.add((
          _uuid.v4(),
          _globalGroupId,
          id,
          normalized,
          lang,
          'seed',
          1,
          0,
          now,
          now,
        ));
      }

      for (final alias in item['aliases_de'] as List? ?? []) {
        addAlias(alias as String, 'de');
      }
      for (final alias in item['aliases_en'] as List? ?? []) {
        addAlias(alias as String, 'en');
      }
      for (final alias in item['aliases_fr'] as List? ?? []) {
        addAlias(alias as String, 'fr');
      }
      for (final alias in item['aliases_es'] as List? ?? []) {
        addAlias(alias as String, 'es');
      }
      addAlias(item['name_de'] as String, 'de');
      addAlias(item['name_en'] as String, 'en');
      addAlias(item['name_fr'] as String, 'fr');
      addAlias(item['name_es'] as String, 'es');
    }

    for (final chunk in _chunked(canonicalRows, 1000)) {
      await _db.upsertCanonicalItems(chunk);
    }
    for (final chunk in _chunked(aliasRows, 4000)) {
      await _db.bulkInsertItemAliasesRaw(chunk);
    }
  }

  static Iterable<List<T>> _chunked<T>(List<T> rows, int size) sync* {
    for (var i = 0; i < rows.length; i += size) {
      yield rows.sublist(i, i + size > rows.length ? rows.length : i + size);
    }
  }
}

Map<String, dynamic> _decodeJsonMap(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;
