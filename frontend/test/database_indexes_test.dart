import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/storage/app_database.dart';

void main() {
  group('AppDatabase schema v4 indexes', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(
        drift.DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
    });

    tearDown(() => db.close());

    test('all expected idx_ indexes are created on a fresh database', () async {
      // Trigger onCreate by executing any query that forces the DB to open.
      await db.customSelect('SELECT 1').get();

      final rows = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%' ORDER BY name",
          )
          .get();

      final names = rows.map((r) => r.data['name'] as String).toSet();

      const expected = {
        'idx_lists_table_group_id',
        'idx_list_items_table_list_id',
        'idx_expenses_table_group_id',
        'idx_outbox_ops_created_at',
        'idx_canonical_items_table_group_id',
        'idx_item_aliases_table_group_id',
        'idx_item_aliases_table_alias_text',
        'idx_corrections_table_group_id',
        'idx_store_aisles_table_group_id',
        'idx_purchase_history_table_group_id',
        'idx_purchase_history_table_canonical_item_id',
        'idx_item_cooccurrence_table_group_id',
      };

      for (final idx in expected) {
        expect(names, contains(idx), reason: 'missing index: $idx');
      }

      // Sanity: count should be at least the expected set size.
      expect(names.length, greaterThanOrEqualTo(expected.length));
    });
  });
}
