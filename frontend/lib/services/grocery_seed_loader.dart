import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../storage/app_database.dart';

const _seedAsset = 'assets/grocery/seed.json';
const _globalGroupId = '__global__';
const _uuid = Uuid();

class GrocerySeedLoader {
  final AppDatabase _db;

  GrocerySeedLoader(this._db);

  /// Load the bundled German grocery seed into Drift if not already seeded.
  /// Safe to call on every cold start — skips if global items already exist.
  Future<void> loadIfNeeded() async {
    final existing = await _db.getCanonicalItemsByGroup(_globalGroupId);
    if (existing.isNotEmpty) return;

    final raw = await rootBundle.loadString(_seedAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    await _ingestSeed(json);
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

    await _db.upsertCanonicalItems(canonicalRows);
    await _db.upsertItemAliases(aliasRows);
  }
}
