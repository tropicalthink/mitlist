import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/storage/grocery_reference_database.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

/// Shared test scaffolding for the resolution eval/baseline/export tests:
/// an in-memory Drift DB seeded from the real shipped `assets/grocery/seed.json`
/// (full 3,239-item catalogue + aliases), so resolution runs against the real
/// candidate space rather than a toy fixture.

const String kGlobalGroup = '__global__';

/// The reference-DB schema, matching what `intelligence/ml/build_grocery_db.py`
/// emits and what [GroceryReferenceDatabase] reads.
const String _refSchema = '''
CREATE TABLE "canonical_items_table" (
  "id" TEXT NOT NULL, "group_id" TEXT NOT NULL,
  "name_de" TEXT NOT NULL DEFAULT '', "name_en" TEXT NOT NULL DEFAULT '',
  "name_fr" TEXT NOT NULL DEFAULT '', "name_es" TEXT NOT NULL DEFAULT '',
  "category" TEXT NOT NULL DEFAULT '', "default_unit" TEXT NOT NULL DEFAULT '',
  "product_id" TEXT,
  "is_global" INTEGER NOT NULL DEFAULT 0 CHECK ("is_global" IN (0, 1)),
  "version" INTEGER NOT NULL DEFAULT 0,
  "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER,
  PRIMARY KEY ("id"));
CREATE TABLE "item_aliases_table" (
  "id" TEXT NOT NULL, "group_id" TEXT NOT NULL, "canonical_item_id" TEXT NOT NULL,
  "alias_text" TEXT NOT NULL, "lang" TEXT NOT NULL DEFAULT 'und',
  "source" TEXT NOT NULL DEFAULT 'correction', "weight" INTEGER NOT NULL DEFAULT 1,
  "version" INTEGER NOT NULL DEFAULT 0,
  "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER,
  PRIMARY KEY ("id"));
CREATE TABLE "store_aisles_table" (
  "id" TEXT NOT NULL, "group_id" TEXT NOT NULL, "store_id" TEXT,
  "canonical_item_id" TEXT NOT NULL, "aisle" TEXT NOT NULL DEFAULT '',
  "sort_order" INTEGER NOT NULL DEFAULT 0, "confidence" REAL NOT NULL DEFAULT 0.5,
  "version" INTEGER NOT NULL DEFAULT 0,
  "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER,
  PRIMARY KEY ("id"));
CREATE VIRTUAL TABLE item_aliases_fts USING fts5(
  alias_text, content=item_aliases_table, content_rowid=rowid,
  tokenize="unicode61 remove_diacritics 2");
''';

/// A canonical row for [buildTestRefDb]: (id, nameDe, nameEn, category).
typedef RefCanonical = (String, String, String, String);

/// An alias row for [buildTestRefDb]: (canonicalId, aliasText, source, weight).
typedef RefAlias = (String, String, String, int);

/// Builds a temp reference DB file (schema + populated FTS + user_version) from
/// the given canonical/alias rows and returns its path. Mirrors the Python
/// builder so tests exercise the real read-only reference path.
String buildTestRefDb({
  required List<RefCanonical> canonical,
  required List<RefAlias> aliases,
}) {
  final dir = Directory.systemTemp.createTempSync('gref-test');
  final path = '${dir.path}/grocery_ref.sqlite';
  final db = s3.sqlite3.open(path);
  db.execute(_refSchema);
  final insCanon = db.prepare(
      'INSERT INTO canonical_items_table (id,group_id,name_de,name_en,category,is_global,created_at,updated_at) '
      'VALUES (?,?,?,?,?,1,0,0)');
  for (final c in canonical) {
    insCanon.execute([c.$1, kGlobalGroup, c.$2, c.$3, c.$4]);
  }
  insCanon.dispose();
  final insAlias = db.prepare(
      'INSERT INTO item_aliases_table (id,group_id,canonical_item_id,alias_text,source,weight,created_at,updated_at) '
      'VALUES (?,?,?,?,?,?,0,0)');
  var i = 0;
  for (final a in aliases) {
    insAlias.execute(['ra${i++}', kGlobalGroup, a.$1, a.$2, a.$3, a.$4]);
  }
  insAlias.dispose();
  db.execute("INSERT INTO item_aliases_fts(item_aliases_fts) VALUES ('rebuild');");
  db.execute('PRAGMA user_version = 1;');
  db.dispose();
  return path;
}

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
    for (final a in (item['aliases_fr'] as List? ?? [])) {
      addAlias(a as String?, 'fr');
    }
    for (final a in (item['aliases_es'] as List? ?? [])) {
      addAlias(a as String?, 'es');
    }
    addAlias(item['name_de'] as String?, 'de');
    addAlias(item['name_en'] as String?, 'en');
    addAlias(item['name_fr'] as String?, 'fr');
    addAlias(item['name_es'] as String?, 'es');
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
