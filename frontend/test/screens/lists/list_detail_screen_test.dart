import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/providers/grocery_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/list_provider.dart';
import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/screens/lists/list_detail_screen.dart';
import 'package:mitlist/services/list_service.dart';
import 'package:mitlist/services/restock_service.dart';
import 'package:mitlist/services/scan/bundled_grocery_suggestion_service.dart';
import 'package:mitlist/services/scan/grocery_suggestion_service.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _gid = '11111111-1111-1111-1111-111111111111';
const _lid = '22222222-2222-2222-2222-222222222222';

class _Service implements ListService {
  @override
  Future<void> flushListNotifications(String listId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Serves a fixed list from the cache and records the edits made to it.
/// Anything else the screen asks of the repository answers "nothing".
class _Repo implements ListRepository {
  _Repo(this.items);

  final List<ListItem> items;
  final List<UpdateListItemRequest> updates = [];

  @override
  Stream<List<ListItem>> watchItemsByList(String listId) => Stream.value(items);

  @override
  Future<List<ListItem>> getItemsByListOnce(String listId) async => items;

  @override
  Future<String?> getGroupId(String listId) async => _gid;

  @override
  Future<String?> getListType(String listId) async => 'shopping';

  @override
  Future<void> refreshListDetail(String listId) async {}

  @override
  String resolveListId(String id) => id;

  @override
  Stream<({String from, String to})> get listIdChanges => const Stream.empty();

  @override
  void triggerAutoSync() {}

  @override
  Future<ListItem> updateItemOfflineFirst(
    String listId,
    String itemId,
    UpdateListItemRequest req,
  ) async {
    updates.add(req);
    return items.firstWhere((i) => i.id == itemId);
  }

  final List<String> deleted = [];
  final List<String> created = [];

  @override
  Future<void> deleteItemOfflineFirst(String listId, String itemId) async {
    deleted.add(itemId);
  }

  @override
  Future<ListItem> createItemOfflineFirst(
    String listId,
    CreateListItemRequest req, {
    bool deferImmediateSync = false,
    String? addedBy,
  }) async {
    created.add(req.name);
    return _item('new-${created.length}', req.name, items.length);
  }

  @override
  Future<ListItem> addItemAmountOfflineFirst(
    String listId, {
    required String name,
    required double amount,
    String unit = '',
    String note = '',
    String? canonicalItemId,
    bool deferImmediateSync = false,
    String? addedBy,
  }) async {
    created.add(name);
    return _item('new-${created.length}', name, items.length, quantity: amount);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<dynamic>.value(null);
}

ListItem _item(
  String id,
  String name,
  int position, {
  double quantity = 1,
  int? priceCents,
}) =>
    ListItem(
      id: id,
      listId: _lid,
      name: name,
      quantity: quantity,
      unit: '',
      checked: false,
      position: position,
      priceCents: priceCents,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

class _Bundled extends BundledGrocerySuggestionService {
  @override
  Future<List<GrocerySuggestion>> suggest(String query, {int limit = 8}) async {
    if (query.trim().isEmpty) return const [];
    return const [
      GrocerySuggestion(
          canonicalItemId: 'milk', name: 'Milk', category: 'Dairy', unit: 'l'),
      GrocerySuggestion(
          canonicalItemId: 'mint', name: 'Mint', category: 'Produce', unit: ''),
    ];
  }
}

Future<_Repo> _open(
  WidgetTester tester,
  List<ListItem> items, {
  List<RestockSuggestion> runningLow = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = AppDatabase(
    DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true),
  );
  addTearDown(db.close);
  final repo = _Repo(items);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      grocerySeedProvider.overrideWith((ref) async {}),
      listServiceProviderAsync.overrideWith((ref) async => _Service()),
      listRepositoryProvider.overrideWith((ref) async => repo),
      cachedGroupsProvider.overrideWith((ref) async => const []),
      runningLowProvider.overrideWith((ref, id) async => runningLow),
      bundledGrocerySuggestionServiceProvider.overrideWithValue(_Bundled()),
    ],
    child: MaterialApp(
      theme: MitlistTheme.light,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ListDetailScreen(listId: _lid, initialListName: 'Groceries'),
    ),
  ));
  await _settle(tester);
  return repo;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Taps an item's words to edit them, then opens its details.
Future<void> _openDetails(WidgetTester tester, String name, String id) async {
  await tester.tap(find.text(name));
  await _settle(tester);
  await tester.tap(find.byKey(ValueKey('item-line-details-$id')));
  await _settle(tester);
}

void main() {
  testWidgets('tapping the words edits them in place; return saves',
      (tester) async {
    final repo = await _open(tester, [
      _item('a', 'Milk', 0),
      _item('b', 'Bananas', 1),
    ]);

    await tester.tap(find.text('Bananas'));
    await _settle(tester);
    final field = find.byKey(const ValueKey('item-line-edit-b'));
    expect(field, findsOneWidget);

    await tester.enterText(field, 'Plantains');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(repo.updates.single.name, 'Plantains');
    expect(field, findsNothing);
    // Return moves on to the add line, like the next line of a checklist.
    final addLine = tester.widget<TextField>(
      find.byKey(const ValueKey('list-add-line')),
    );
    expect(addLine.focusNode!.hasFocus, isTrue);
  });

  testWidgets('emptying a line removes the item', (tester) async {
    final repo = await _open(tester, [
      _item('a', 'Milk', 0),
      _item('b', 'Bananas', 1),
    ]);

    await tester.tap(find.text('Bananas'));
    await _settle(tester);
    await tester.enterText(find.byKey(const ValueKey('item-line-edit-b')), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(repo.deleted, ['b']);
    expect(repo.updates, isEmpty);
  });

  testWidgets('the add line adds on return and stays open for the next',
      (tester) async {
    final repo = await _open(tester, [_item('a', 'Milk', 0)]);

    final addLine = find.byKey(const ValueKey('list-add-line'));
    await tester.tap(addLine);
    await tester.enterText(addLine, 'Eggs');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _settle(tester);

    expect(repo.created, ['Eggs']);
    final field = tester.widget<TextField>(addLine);
    expect(field.controller!.text, isEmpty);
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('one tap on + in the details sheet makes it one more',
      (tester) async {
    final repo = await _open(tester, [
      _item('a', 'Milk', 0),
      _item('b', 'Bananas', 1, quantity: 6),
    ]);

    await _openDetails(tester, 'Bananas', 'b');
    await tester.tap(find.byKey(const ValueKey('item-edit-more')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('item-edit-done')));
    await _settle(tester);

    // Closing the sheet tears down its fields cleanly (the old dialogs
    // disposed theirs mid-animation).
    expect(tester.takeException(), isNull);
    final update = repo.updates.single;
    expect(update.quantity, 7);
    expect(update.name, isNull);
    expect(update.note, isNull);
    expect(update.priceCents, isNull);
  });

  testWidgets('the sheet saves when dismissed by tapping outside',
      (tester) async {
    final repo = await _open(tester, [_item('a', 'Milk', 0)]);

    await _openDetails(tester, 'Milk', 'a');
    await tester.enterText(
        find.byKey(const ValueKey('item-edit-note')), 'oat, not cow');
    await tester.tapAt(const Offset(20, 20));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    expect(repo.updates.single.note, 'oat, not cow');
  });

  testWidgets('an untouched sheet writes nothing; minus stops at one',
      (tester) async {
    final repo = await _open(tester, [_item('a', 'Milk', 0)]);

    await _openDetails(tester, 'Milk', 'a');
    final less = tester.widget<Widget>(
      find.byKey(const ValueKey('item-edit-less')),
    );
    expect((less as dynamic).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('item-edit-done')));
    await _settle(tester);

    expect(repo.updates, isEmpty);
  });

  testWidgets('emptying the price clears it', (tester) async {
    final repo =
        await _open(tester, [_item('a', 'Coffee', 0, priceCents: 899)]);

    await _openDetails(tester, 'Coffee', 'a');
    await tester.enterText(find.byKey(const ValueKey('item-edit-price')), '');
    await tester.tap(find.byKey(const ValueKey('item-edit-done')));
    await _settle(tester);

    expect(repo.updates.single.priceCents, 0);
  });

  testWidgets(
      'typing swaps "you might also need" for matches under the add line',
      (tester) async {
    final repo = await _open(
      tester,
      [_item('a', 'Bananas', 0)],
      runningLow: const [
        RestockSuggestion(
          canonicalItemId: 'coffee',
          name: 'Coffee',
          intervalDays: 14,
          daysSince: 15,
          reason: RestockReason.due,
        ),
      ],
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // At rest: the household's usual buys sit at the end of the list.
    expect(find.text(l10n.scanReviewYouMightNeed), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);

    final addLine = find.byKey(const ValueKey('list-add-line'));
    await tester.tap(addLine);
    await tester.enterText(addLine, 'mi');
    await _settle(tester);

    // Typing: matches appear as lines right under the words…
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Mint'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Milk')).dy,
      greaterThan(tester.getTopLeft(addLine).dy),
    );
    // …and the usual buys step aside.
    expect(find.text('Coffee'), findsNothing);

    await tester.tap(find.text('Mint'));
    await _settle(tester);
    expect(repo.created, ['Mint']);
    expect(find.text('Milk'), findsNothing);
  });
}
