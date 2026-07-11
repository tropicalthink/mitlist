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

class GrocerySeedLoader {
  final AppDatabase _db;
  final AssetBundle _bundle;

  GrocerySeedLoader(
    this._db, {
    @visibleForTesting AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;

  /// Load the bundled grocery assets into Drift.
  ///
  /// Safe to call on every cold start. Each asset (canonical seed, store aisles,
  /// OFF brand aliases) carries its own `version` and is ingested independently
  /// — so adding a new asset to an existing install ingests it even when the
  /// seed itself is already up to date. Household-scoped data is never touched.
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

    // The full seed is ~3k canonical rows + ~280k alias rows, sharing the
    // single serial DB connection with interactive writes. Two rules keep it
    // from wrecking the app while it runs:
    //  1. NO single wrapping transaction. SQLite/drift serialize the whole
    //     connection while a transaction is open, so one big clear+reingest
    //     transaction makes every interactive write (e.g. adding a list item
    //     moments after first launch) queue for the seed's full duration —
    //     measured 7+s on desktop, tens of seconds on a phone in debug. Each
    //     chunked insert below commits on its own instead, so interactive
    //     writes interleave between chunks and wait at most one chunk
    //     (~50-100ms). Atomicity is not lost where it matters: the version key
    //     is written only at the very end, so an interrupted seed simply
    //     re-runs (clear + reingest) on the next launch, and suggestion
    //     queries gate on the seed future rather than on table state.
    //  2. `item_aliases_table` maintains a full-text index via per-row
    //     triggers (see `createAliasFts`); at ~280k rows, per-row
    //     tokenize-and-index is the single biggest cost. Dropping the
    //     triggers for the bulk work and rebuilding the FTS index in one
    //     bulk pass afterward (FTS5's `rebuild` command) measured ~6-7x
    //     faster end to end for the alias insert. Dropping them *before* the
    //     clear also keeps a reseed's ~280k-row delete from firing per-row
    //     FTS delete triggers; the rebuild afterwards reflects the deletes.
    // Same trick for the three secondary indexes on item_aliases_table:
    // keeping them live costs some total import time, but lets autocomplete
    // queries and unrelated interactive DB work yield between import chunks.
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
      // Never leave normal alias writes detached from FTS after a failed or
      // interrupted install. A failed install keeps the old version cursor, so
      // the next launch will rerun and rebuild the index.
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

  /// Ingests the OpenFoodFacts-derived brand aliases (ODbL, shipped as a
  /// separable, attributed asset) so typing a brand — "pringles", "haribo",
  /// "coca cola" — resolves to the right canonical item. Version-gated and
  /// global; stored with `source='off'` so a reseed never drops them and they
  /// can be re-ingested independently. Fail-soft: a missing/old asset is a
  /// no-op (older builds shipped without it).
  Future<void> _loadOffAliasesIfNeeded() async {
    final String raw;
    try {
      raw = await _bundle.loadString(_offAliasesAsset);
    } catch (_) {
      return; // asset not bundled in this build
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final assetVersion = (json['version'] as num?)?.toInt() ?? 0;
    final installed = await _db.getGroceryVersion(_offAliasesVersionKey);
    if (installed >= assetVersion) return;

    final items = (json['items'] as Map<String, dynamic>? ?? {});
    final now = DateTime.now();
    final rows = <ItemAliasesTableCompanion>[];
    items.forEach((canonicalId, byLang) {
      (byLang as Map<String, dynamic>).forEach((lang, list) {
        for (final a in (list as List)) {
          final normalized = normaliseText(a as String);
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
    // Do not wrap the full import in one transaction. This database connection
    // also serves interactive list writes, so a large external-alias asset
    // must yield between chunks just like the canonical seed above. The
    // version is committed last; an interrupted import safely reruns.
    await _db.clearGlobalAliasesBySource(_globalGroupId, 'off');
    for (final chunk in _chunked(rows, 2000)) {
      await _db.upsertItemAliases(chunk);
    }
    await _db.setGroceryVersion(_offAliasesVersionKey, assetVersion);
  }

  /// Ingests the shipped global store layouts (item → aisle + shopping-path
  /// sort order, per store). Version-aware and global; household overrides are
  /// kept in separate rows and never cleared here.
  Future<void> _loadStoreAislesIfNeeded() async {
    final raw = await _bundle.loadString(_storeAislesAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final assetVersion = (json['version'] as num?)?.toInt() ?? 0;
    final installed = await _db.getGroceryVersion(_storeAislesVersionKey);
    if (installed >= assetVersion) return;

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
    await _db.transaction(() async {
      await _db.clearGlobalStoreAisles(_globalGroupId);
      for (final chunk in _chunked(rows, 2000)) {
        await _db.upsertStoreAisles(chunk);
      }
      await _db.setGroceryVersion(_storeAislesVersionKey, assetVersion);
    });
  }

  Future<void> _ingestSeed(Map<String, dynamic> json) async {
    final items = (json['items'] as List).cast<Map<String, dynamic>>();
    final now = DateTime.now();

    final canonicalRows = <CanonicalItemsTableCompanion>[];
    // Raw tuples rather than Companions: at seed size (~280k rows) the
    // Companion/Table insert machinery is the dominant cost — see
    // `AppDatabase.bulkInsertItemAliasesRaw` for the measured ~4x this saves
    // on top of the FTS-trigger drop.
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

      for (final a in (item['aliases_de'] as List? ?? [])) {
        addAlias(a as String, 'de');
      }
      for (final a in (item['aliases_en'] as List? ?? [])) {
        addAlias(a as String, 'en');
      }
      for (final a in (item['aliases_fr'] as List? ?? [])) {
        addAlias(a as String, 'fr');
      }
      for (final a in (item['aliases_es'] as List? ?? [])) {
        addAlias(a as String, 'es');
      }
      // Also alias by canonical name in each shipped language.
      addAlias(item['name_de'] as String, 'de');
      addAlias(item['name_en'] as String, 'en');
      addAlias(item['name_fr'] as String, 'fr');
      addAlias(item['name_es'] as String, 'es');
    }

    // Insert in chunks so a full-seed reingest doesn't hold ~120k companions
    // in one batch / allocation spike on low-end devices.
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
