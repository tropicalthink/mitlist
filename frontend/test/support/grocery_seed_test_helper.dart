import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:mitlist/storage/app_database.dart';

/// Shared test scaffolding for the resolution eval/baseline/export tests:
/// an in-memory Drift DB seeded from the real shipped `assets/grocery/seed.json`
/// (full 3,239-item catalogue + aliases), so resolution runs against the real
/// candidate space rather than a toy fixture.

const String kGlobalGroup = '__global__';

AppDatabase memoryDb() => AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

/// Loads `assets/grocery/seed.json` via rootBundle and ingests every canonical
/// item + alias into [db] under the global scope, mirroring GrocerySeedLoader.
/// Requires `TestWidgetsFlutterBinding.ensureInitialized()` to have been called.
Future<void> ingestRealSeed(AppDatabase db) async {
  final raw = await rootBundle.loadString('assets/grocery/seed.json');
  final parsed = jsonDecode(raw);
  final items = ((parsed is Map ? parsed['items'] : parsed) as List)
      .cast<Map<String, dynamic>>();
  final now = DateTime.now();

  final canonical = <CanonicalItemsTableCompanion>[];
  final aliases = <ItemAliasesTableCompanion>[];
  var aliasId = 0;

  for (final item in items) {
    final id = item['id'] as String;
    canonical.add(CanonicalItemsTableCompanion.insert(
      id: id,
      groupId: kGlobalGroup,
      nameDe: Value(item['name_de'] as String? ?? ''),
      nameEn: Value(item['name_en'] as String? ?? ''),
      category: Value(item['category'] as String? ?? ''),
      defaultUnit: Value(item['default_unit'] as String? ?? ''),
      isGlobal: const Value(true),
      version: const Value(0),
      createdAt: now,
      updatedAt: now,
    ));
    void addAlias(String? text, String lang) {
      final n = (text ?? '').toLowerCase().trim();
      if (n.isEmpty) return;
      aliases.add(ItemAliasesTableCompanion.insert(
        id: 'a${aliasId++}',
        groupId: kGlobalGroup,
        canonicalItemId: id,
        aliasText: n,
        lang: Value(lang),
        source: const Value('seed'),
        weight: const Value(1),
        version: const Value(0),
        createdAt: now,
        updatedAt: now,
      ));
    }

    for (final a in (item['aliases_de'] as List? ?? [])) {
      addAlias(a as String?, 'de');
    }
    for (final a in (item['aliases_en'] as List? ?? [])) {
      addAlias(a as String?, 'en');
    }
    addAlias(item['name_de'] as String?, 'de');
    addAlias(item['name_en'] as String?, 'en');
  }

  for (final chunk in chunked(canonical, 1000)) {
    await db.upsertCanonicalItems(chunk);
  }
  for (final chunk in chunked(aliases, 4000)) {
    await db.upsertItemAliases(chunk);
  }
}

Iterable<List<T>> chunked<T>(List<T> rows, int size) sync* {
  for (var i = 0; i < rows.length; i += size) {
    yield rows.sublist(i, (i + size).clamp(0, rows.length));
  }
}
