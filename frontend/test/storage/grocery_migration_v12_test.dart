// ignore_for_file: prefer_single_quotes
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

/// The v11 schema for the tables that must survive the v11→v12 upgrade. v12 only
/// *adds* the local_item_signals_table (pre-promotion tally for novel words), so
/// this test proves the new table + index appear and existing household grocery
/// data is untouched.
const _v11Schema = '''
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
''';

String _buildV11Db(Directory dir) {
  final path = '${dir.path}/mitlist_v11.sqlite';
  final db = s3.sqlite3.open(path);
  db.execute(_v11Schema);
  db.execute(
      "INSERT INTO canonical_items_table (id,group_id,name_en,is_global,created_at,updated_at) VALUES "
      "('home_jam','g1','Grandma jam',0,0,0)");
  db.execute(
      "INSERT INTO item_aliases_table (id,group_id,canonical_item_id,alias_text,source,weight,created_at,updated_at) VALUES "
      "('h_a','g1','home_jam','grandma jam','correction',5,0,0)");
  db.execute('PRAGMA user_version = 11;');
  db.dispose();
  return path;
}

Future<int> _count(AppDatabase db, String sql) async {
  final rows = await db.customSelect(sql).get();
  return rows.first.data.values.first as int;
}

void main() {
  test('v11→v12 migration adds local_item_signals_table + index, keeps household data',
      () async {
    final dir = Directory.systemTemp.createTempSync('mitv11');
    addTearDown(() => dir.deleteSync(recursive: true));

    final path = _buildV11Db(dir);
    // Opening triggers drift's onUpgrade(11 -> 12).
    final db = AppDatabase(NativeDatabase(File(path)));
    addTearDown(db.close);

    // Force the connection open so the migration runs.
    await db.customSelect('SELECT 1').get();

    // The new pre-promotion tally table exists...
    expect(
        await _count(db,
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='local_item_signals_table'"),
        1);
    // ...and is usable through the generated API.
    expect(await db.select(db.localItemSignalsTable).get(), isEmpty);

    // Its lookup index exists.
    expect(
        await _count(db,
            "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='idx_local_item_signals_group_id'"),
        1);

    // Existing household grocery data is untouched.
    expect(await _count(db, "SELECT COUNT(*) FROM canonical_items_table WHERE group_id='g1'"), 1);
    expect(await _count(db, "SELECT COUNT(*) FROM item_aliases_table WHERE group_id='g1'"), 1);
  });
}
