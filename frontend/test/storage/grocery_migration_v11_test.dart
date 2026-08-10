// ignore_for_file: prefer_single_quotes
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

/// The pre-11 schema for the tables the v10→v11 migration touches, plus the
/// FTS index + triggers it drops. Mirrors what an on-device DB looked like
/// before the global grocery brain moved to the reference DB.
const _v10Schema = '''
-- Not exercised by this test, but a real database of this vintage has it, and
-- later migrations legitimately ALTER it. Without it the fixture is not a
-- faithful older schema and every future expense migration breaks here.
CREATE TABLE "expenses_table" (
  "id" TEXT NOT NULL, "group_id" TEXT NOT NULL, "payer_id" TEXT NOT NULL,
  "amount" INTEGER NOT NULL, "base_amount" INTEGER NOT NULL DEFAULT 0,
  "fx_rate" REAL NOT NULL DEFAULT 1.0,
  "description" TEXT NOT NULL, "category" TEXT NOT NULL,
  "currency" TEXT NOT NULL, "notes" TEXT NOT NULL,
  "date" INTEGER NOT NULL, "created_at" INTEGER NOT NULL,
  PRIMARY KEY ("id"));
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
CREATE TRIGGER item_aliases_fts_ai AFTER INSERT ON item_aliases_table BEGIN
  INSERT INTO item_aliases_fts(rowid, alias_text) VALUES (new.rowid, new.alias_text);
END;
CREATE TRIGGER item_aliases_fts_ad AFTER DELETE ON item_aliases_table BEGIN
  INSERT INTO item_aliases_fts(item_aliases_fts, rowid, alias_text) VALUES ('delete', old.rowid, old.alias_text);
END;
CREATE TRIGGER item_aliases_fts_au AFTER UPDATE ON item_aliases_table BEGIN
  INSERT INTO item_aliases_fts(item_aliases_fts, rowid, alias_text) VALUES ('delete', old.rowid, old.alias_text);
  INSERT INTO item_aliases_fts(rowid, alias_text) VALUES (new.rowid, new.alias_text);
END;
''';

String _buildV10Db(Directory dir) {
  final path = '${dir.path}/mitlist_v10.sqlite';
  final db = s3.sqlite3.open(path);
  db.execute(_v10Schema);
  // Global seed rows (evicted by the migration) + household rows (kept).
  db.execute(
      "INSERT INTO item_aliases_table (id,group_id,canonical_item_id,alias_text,source,weight,created_at,updated_at) VALUES "
      "('g_a','__global__','apple','apfel','seed',1,0,0),"
      "('h_a','g1','apple','my apple','correction',5,0,0)");
  db.execute(
      "INSERT INTO canonical_items_table (id,group_id,name_en,is_global,created_at,updated_at) VALUES "
      "('apple','__global__','Apple',1,0,0),"
      "('home_jam','g1','Grandma jam',0,0,0)");
  db.execute(
      "INSERT INTO store_aisles_table (id,group_id,store_id,canonical_item_id,aisle,created_at,updated_at) VALUES "
      "('g_s','__global__','de_rewe','apple','Obst',0,0),"
      "('h_s','g1','de_rewe','apple','My Aisle',0,0)");
  db.execute('PRAGMA user_version = 10;');
  db.dispose();
  return path;
}

Future<int> _count(AppDatabase db, String sql) async {
  final rows = await db.customSelect(sql).get();
  return rows.first.data.values.first as int;
}

void main() {
  test('v10→v11 migration evicts global rows, keeps household rows, drops FTS',
      () async {
    final dir = Directory.systemTemp.createTempSync('mitv10');
    addTearDown(() => dir.deleteSync(recursive: true));

    final path = _buildV10Db(dir);
    // Opening triggers drift's onUpgrade(10 -> 11).
    final db = AppDatabase(NativeDatabase(File(path)));
    addTearDown(db.close);

    // Force the connection open so the migration runs.
    await db.customSelect('SELECT 1').get();

    // Global rows evicted.
    expect(
        await _count(db,
            "SELECT COUNT(*) FROM item_aliases_table WHERE group_id='__global__'"),
        0);
    expect(
        await _count(db,
            "SELECT COUNT(*) FROM canonical_items_table WHERE is_global=1 OR group_id='__global__'"),
        0);
    expect(
        await _count(db,
            "SELECT COUNT(*) FROM store_aisles_table WHERE group_id='__global__'"),
        0);

    // Household rows kept.
    expect(await _count(db, "SELECT COUNT(*) FROM item_aliases_table WHERE group_id='g1'"), 1);
    expect(await _count(db, "SELECT COUNT(*) FROM canonical_items_table WHERE group_id='g1'"), 1);
    expect(await _count(db, "SELECT COUNT(*) FROM store_aisles_table WHERE group_id='g1'"), 1);

    // The now-unused main-DB FTS is dropped.
    expect(
        await _count(db,
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='item_aliases_fts'"),
        0);
  });
}
