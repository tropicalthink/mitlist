import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/services/scan/household_suggestion_engine.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/widgets/list/list_composer_bar.dart';

import '../support/fakes.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

Future<void> _insertList(AppDatabase db, String listId) async {
  await db.upsertListsRows([
    ListsTableCompanion(
      id: drift.Value(listId),
      groupId: const drift.Value('group-1'),
      name: const drift.Value('Groceries'),
      type: const drift.Value('shopping'),
      createdAt: drift.Value(DateTime.utc(2026, 1, 1)),
      updatedAt: drift.Value(DateTime.utc(2026, 1, 1)),
    ),
  ]);
}

Future<void> _insertItem(
  AppDatabase db,
  String listId, {
  required String itemId,
  String? canonicalItemId,
}) async {
  await db.upsertListItemsRows([
    ListItemsTableCompanion(
      id: drift.Value(itemId),
      listId: drift.Value(listId),
      name: const drift.Value('Milch'),
      quantity: const drift.Value(1.0),
      unit: const drift.Value('l'),
      checked: const drift.Value(false),
      position: const drift.Value(0),
      canonicalItemId: drift.Value(canonicalItemId),
      createdAt: drift.Value(DateTime.utc(2026, 1, 2)),
      updatedAt: drift.Value(DateTime.utc(2026, 1, 2)),
    ),
  ]);
}

Widget _host(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('grocery chip exposes canonical id before add',
      (WidgetTester tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final events = <String>[];

    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _host(
        ListComposerBar(
          controller: controller,
          focusNode: focusNode,
          onAdd: () => events.add('add:${controller.text}'),
          onScan: () {},
          showProductSuggestions: true,
          suggestions: const [
            HouseholdSuggestion(
              canonicalItemId: 'milk',
              name: 'Milch',
              category: 'dairy',
              unit: 'l',
              sources: {HouseholdSuggestionSource.catalog},
            ),
          ],
          onSuggestionSelected: (s) =>
              events.add('selected:${s.canonicalItemId}'),
        ),
      ),
    );

    await tester.tap(find.text('Milch'));
    await tester.pump();

    expect(controller.text, equals('Milch'));
    expect(events, equals(['selected:milk', 'add:Milch']));
  });

  group('addItemAmountOfflineFirst canonical id', () {
    late AppDatabase db;
    late ListRepository repo;

    setUp(() {
      db = _memoryDb();
      repo = ListRepository(
        db: db,
        remote: FakeListService(),
        autoSync: false,
      );
    });

    tearDown(() => db.close());

    test('new item persists canonical id locally', () async {
      const listId = 'list-new';
      await _insertList(db, listId);

      await repo.addItemAmountOfflineFirst(
        listId,
        name: 'Milch',
        amount: 2,
        unit: 'l',
        canonicalItemId: 'milk',
      );

      final rows = await db.getItemsByListOnce(listId);
      expect(rows, hasLength(1));
      expect(rows.first.canonicalItemId, equals('milk'));
    });

    test('merge upgrades an unlinked row', () async {
      const listId = 'list-upgrade';
      await _insertList(db, listId);
      await _insertItem(db, listId, itemId: 'item-existing');

      await repo.addItemAmountOfflineFirst(
        listId,
        name: 'Milch',
        amount: 1,
        unit: 'l',
        canonicalItemId: 'milk',
      );

      final rows = await db.getItemsByListOnce(listId);
      expect(rows, hasLength(1));
      expect(rows.first.id, equals('item-existing'));
      expect(rows.first.canonicalItemId, equals('milk'));
    });

    test('merge keeps an existing canonical id', () async {
      const listId = 'list-keep';
      await _insertList(db, listId);
      await _insertItem(
        db,
        listId,
        itemId: 'item-existing',
        canonicalItemId: 'milk-old',
      );

      await repo.addItemAmountOfflineFirst(
        listId,
        name: 'Milch',
        amount: 1,
        unit: 'l',
        canonicalItemId: 'milk-new',
      );

      final rows = await db.getItemsByListOnce(listId);
      expect(rows, hasLength(1));
      expect(rows.first.id, equals('item-existing'));
      expect(rows.first.canonicalItemId, equals('milk-old'));
    });
  });
}
