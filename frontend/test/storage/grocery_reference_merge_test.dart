// ignore_for_file: prefer_single_quotes
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/storage/grocery_reference_database.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

/// Builds a tiny prebuilt reference DB file with the same schema/DDL the Python
/// builder emits, so we exercise the real read-only merge path.
String _buildRefDb(Directory dir) {
  final path = '${dir.path}/grocery_ref.sqlite';
  final db = s3.sqlite3.open(path);
  db.execute('''
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
  ''');
  db.execute(
      "INSERT INTO canonical_items_table (id,group_id,name_en,category,is_global,created_at,updated_at) "
      "VALUES ('chocolate_hazelnut_spread','__global__','Hazelnut spread','spreads',1,0,0),"
      "('apple','__global__','Apple','produce',1,0,0)");
  db.execute(
      "INSERT INTO item_aliases_table (id,group_id,canonical_item_id,alias_text,lang,source,weight,created_at,updated_at) "
      "VALUES ('a1','__global__','chocolate_hazelnut_spread','nutella','en','seed',1,0,0),"
      "('a2','__global__','apple','green apple','en','seed',1,0,0)");
  db.execute(
      "INSERT INTO store_aisles_table (id,group_id,store_id,canonical_item_id,aisle,sort_order,created_at,updated_at) "
      "VALUES ('s1','__global__','de_rewe','apple','Obst & Gemüse',3,0,0)");
  db.execute(
      "INSERT INTO item_aliases_fts(item_aliases_fts) VALUES ('rebuild');");
  db.execute('PRAGMA user_version = 1;');
  db.dispose();
  return path;
}

void main() {
  late Directory tmp;
  late AppDatabase db;
  late GroceryReferenceDatabase ref;
  const group = 'group-1';
  final now = DateTime.now();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('gref');
    db = AppDatabase(NativeDatabase.memory());
    ref = GroceryReferenceDatabase.open(_buildRefDb(tmp));
    db.attachReference(ref);
  });

  tearDown(() async {
    ref.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  test('resolution falls through to the global reference DB', () async {
    final hit = await db.findAlias(groupId: group, aliasText: 'nutella');
    expect(hit?.canonicalItemId, 'chocolate_hazelnut_spread');
    expect(hit?.source, 'seed');
  });

  test('household correction outranks the global seed on the same alias',
      () async {
    // A household correction remaps "nutella" to a different canonical, with a
    // higher weight — it must win the merge.
    await db.upsertItemAliases([
      ItemAliasesTableCompanion.insert(
        id: 'h1',
        groupId: group,
        canonicalItemId: 'store_brand_spread',
        aliasText: 'nutella',
        source: const Value('correction'),
        weight: const Value(5),
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final hit = await db.findAlias(groupId: group, aliasText: 'nutella');
    expect(hit?.canonicalItemId, 'store_brand_spread');
    expect(hit?.source, 'correction');
  });

  test('FTS word-prefix search resolves through the reference DB', () async {
    final rows = await db.searchAliasWordPrefix(groupId: group, query: 'nutel');
    expect(rows.map((r) => r.canonicalItemId),
        contains('chocolate_hazelnut_spread'));
  });

  test('prefix autocomplete merges household + global', () async {
    await db.upsertItemAliases([
      ItemAliasesTableCompanion.insert(
        id: 'h2',
        groupId: group,
        canonicalItemId: 'apple',
        aliasText: 'granny smith',
        source: const Value('correction'),
        weight: const Value(9),
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final rows = await db.searchAliasPrefix(groupId: group, query: 'gr');
    final texts = rows.map((r) => r.aliasText).toList();
    expect(texts, contains('granny smith')); // household
    expect(texts, contains('green apple')); // global ref
    // Higher-weight household row leads.
    expect(rows.first.aliasText, 'granny smith');
  });

  test('canonical lookups fall through to the reference DB', () async {
    final byId = await db.getCanonicalItemById('apple');
    expect(byId?.nameEn, 'Apple');
    final byIds =
        await db.getCanonicalItemsByIds(['apple', 'chocolate_hazelnut_spread']);
    expect(
        byIds.map((c) => c.id).toSet(), {'apple', 'chocolate_hazelnut_spread'});
  });

  test('store aisle: household override wins, else global reference', () async {
    // No household override -> global layout.
    final global = await db.getStoreAisle(
        groupId: group, storeId: 'de_rewe', canonicalItemId: 'apple');
    expect(global?.aisle, 'Obst & Gemüse');

    await db.upsertStoreAisles([
      StoreAislesTableCompanion.insert(
        id: 'ov1',
        groupId: group,
        canonicalItemId: 'apple',
        storeId: const Value('de_rewe'),
        aisle: const Value('My Custom Aisle'),
        sortOrder: const Value(1),
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final override = await db.getStoreAisle(
        groupId: group, storeId: 'de_rewe', canonicalItemId: 'apple');
    expect(override?.aisle, 'My Custom Aisle');
  });
}
