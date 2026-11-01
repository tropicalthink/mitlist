import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/providers/grocery_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/list_provider.dart';
import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/screens/shopping/shopping_trip_screen.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _gid = '11111111-1111-1111-1111-111111111111';

/// The trip's lists and items as the local cache holds them; ticks write
/// through to it, the way the offline-first repository does.
class _Repo implements ListRepository {
  _Repo(this.items);

  final Map<String, List<ListItem>> items;
  final List<(String, bool)> writes = [];
  Object? failWith;

  @override
  Future<List<ItemList>> getListsByGroupOnce(String groupId) async => [
        ItemList(
          id: 'l1',
          groupId: _gid,
          name: 'Groceries',
          type: 'shopping',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ];

  @override
  Future<List<ListItem>> getItemsByListOnce(String listId) async =>
      items[listId] ?? const [];

  @override
  Future<void> refreshShoppingTrip(String groupId, List<String> ids) async {}

  @override
  Future<ListItem> updateItemOfflineFirst(
    String listId,
    String itemId,
    UpdateListItemRequest req,
  ) async {
    if (failWith case final error?) throw error;
    writes.add((itemId, req.checked!));
    final list = items[listId]!;
    final i = list.indexWhere((e) => e.id == itemId);
    list[i] = _item(itemId, list[i].name, checked: req.checked!);
    return list[i];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<dynamic>.value(0);
}

ListItem _item(String id, String name, {bool checked = false}) => ListItem(
      id: id,
      listId: 'l1',
      name: name,
      quantity: 1,
      unit: '',
      checked: checked,
      position: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

Future<_Repo> _open(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final db = AppDatabase(
    DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true),
  );
  addTearDown(db.close);
  final repo = _Repo({
    'l1': [_item('a', 'Milk'), _item('b', 'Eggs')],
  });
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      grocerySeedProvider.overrideWith((ref) async {}),
      listRepositoryProvider.overrideWith((ref) async => repo),
      cachedGroupsProvider.overrideWith((ref) async => [
            Group(
              id: _gid,
              name: 'Flat 4B',
              isPersonal: false,
              memberCount: 2,
              createdAt: DateTime.utc(2026, 1, 1),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          ]),
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
      home: const ShoppingTripScreen(),
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

void main() {
  testWidgets('a tick is saved the moment it is made', (tester) async {
    final repo = await _open(tester);

    await tester.tap(find.text('Milk'));
    await _settle(tester);

    expect(repo.writes, [('a', true)]);
    // It stays on the trip, ticked, so a mis-tap can be taken back…
    expect(find.text('Milk'), findsOneWidget);

    await tester.tap(find.text('Milk'));
    await _settle(tester);

    // …and taking it back is saved too.
    expect(repo.writes, [('a', true), ('a', false)]);
  });

  testWidgets('a tick that cannot be saved is undone and says so',
      (tester) async {
    final repo = await _open(tester);
    repo.failWith = StateError('disk full');

    await tester.tap(find.text('Eggs'));
    await _settle(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      find.text(l10n.shoppingTripBasketBar(2, '')),
      findsOneWidget,
    );
  });

  testWidgets('finishing writes nothing more and clears the ticked lines',
      (tester) async {
    final repo = await _open(tester);

    await tester.tap(find.text('Milk'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('trip-finish')));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 3));

    expect(repo.writes, [('a', true)]);
    expect(find.text('Milk'), findsNothing);
    expect(find.text('Eggs'), findsOneWidget);
  });
}
