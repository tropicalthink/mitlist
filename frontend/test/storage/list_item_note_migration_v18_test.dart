// ignore_for_file: prefer_single_quotes
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

/// v17's list_items_table (added_by is its newest column). v18 only adds the
/// item note, so this proves the column appears, existing rows read an empty
/// note, and a note written afterwards is kept.
const _v17Schema = '''
CREATE TABLE "list_items_table" (
  "id" TEXT NOT NULL, "list_id" TEXT NOT NULL, "name" TEXT NOT NULL,
  "quantity" REAL NOT NULL, "unit" TEXT NOT NULL,
  "checked" INTEGER NOT NULL CHECK ("checked" IN (0, 1)),
  "position" INTEGER NOT NULL, "price_cents" INTEGER, "canonical_item_id" TEXT,
  "added_by" TEXT,
  "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL,
  PRIMARY KEY ("id"));
''';

void main() {
  test('v17→v18 adds list_items_table.note, keeping existing rows', () async {
    final dir = Directory.systemTemp.createTempSync('mitv17');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/mitlist_v17.sqlite';
    final raw = s3.sqlite3.open(path);
    raw.execute(_v17Schema);
    raw.execute(
        "INSERT INTO list_items_table (id,list_id,name,quantity,unit,checked,position,added_by,created_at,updated_at) VALUES "
        "('i1','l1','Milk',1.0,'',0,0,'u1',0,0)");
    raw.execute('PRAGMA user_version = 17;');
    raw.dispose();

    final db = AppDatabase(NativeDatabase(File(path)));
    addTearDown(db.close);

    final columns = await db
        .customSelect("SELECT name FROM pragma_table_info('list_items_table')")
        .get();
    expect(columns.map((r) => r.read<String>('name')), contains('note'));

    final rows = await db.getItemsByListOnce('l1');
    expect(rows.single.name, 'Milk');
    expect(rows.single.addedBy, 'u1');
    expect(rows.single.note, '');

    await (db.update(db.listItemsTable)..where((t) => t.id.equals('i1')))
        .write(const ListItemsTableCompanion(note: Value('organic')));
    expect((await db.getItemsByListOnce('l1')).single.note, 'organic');
  });
}
