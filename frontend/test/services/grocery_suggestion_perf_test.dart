// ignore_for_file: prefer_single_quotes
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/grocery_seed_loader.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';
import 'package:mitlist/storage/app_database.dart';

AppDatabase _memoryDb() => AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('typed-autocomplete over the full seed', () {
    late AppDatabase db;

    setUp(() async {
      db = _memoryDb();
      await GrocerySeedLoader(db).loadIfNeeded();
    });

    tearDown(() => db.close());

    test('"mil" returns suggestions', () async {
      final svc = GrocerySuggestionService(db);
      final suggestions = await svc.suggest('mil', 'group-1');
      expect(suggestions, isNotEmpty);
    });

    test('prefix search seeks the composite index, not a full scan', () async {
      // A full-table scan per keystroke over the ~280k-row alias seed is what
      // made suggestions feel laggy/absent. The prefix search must be driven by
      // the (group_id, alias_text) composite index; guard against regressing to
      // a group_id-only seek (which leaves a full alias_text scan) or a SCAN.
      final plan = await db
          .customSelect(
              "EXPLAIN QUERY PLAN SELECT * FROM item_aliases_table WHERE "
              "(group_id = 'g' OR group_id = '__global__') AND deleted_at IS NULL "
              "AND alias_text >= 'mil' AND alias_text < 'mim' "
              "ORDER BY weight DESC LIMIT 40")
          .get();
      final detail =
          plan.map((r) => r.data['detail'] as String? ?? '').join(' | ');
      expect(detail, contains('idx_item_aliases_group_alias'),
          reason: 'prefix search must use the composite index; plan: $detail');
      expect(detail, isNot(contains('SCAN item_aliases_table')),
          reason: 'prefix search must not full-scan; plan: $detail');
    });
  });
}
