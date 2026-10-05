// Quick add creates things (plans/048 stage 3): every option opens its
// creation sheet or composer instead of only switching tabs.

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/list_provider.dart';
import 'package:mitlist/sheets/chore_creation_sheet.dart';
import 'package:mitlist/sheets/create_list_sheet.dart';
import 'package:mitlist/sheets/expense_creation_sheet.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/widgets/hub/quick_add_sheet.dart';
import 'package:mitlist/widgets/pinwall/pinwall_composer.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _groupId = '11111111-1111-1111-1111-111111111111';
final _now = DateTime.utc(2026, 1, 1);

ItemList _list(String id, String name) => ItemList(
      id: id,
      groupId: _groupId,
      name: name,
      type: 'shopping',
      createdAt: _now,
      updatedAt: _now,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Home with a Quick add button, under a router that stubs the screens the
  /// sheet can navigate to.
  Future<void> pumpHome(WidgetTester tester, List<ItemList> lists) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(() => db.close());

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                child: TextButton(
                  onPressed: () => showQuickAddSheet(
                    context,
                    ref,
                    groupId: _groupId,
                    me: null,
                  ),
                  child: const Text('open quick add'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/lists/:listId',
          name: 'listDetail',
          builder: (context, state) =>
              Text('list ${state.pathParameters['listId']}'),
        ),
        GoRoute(
          path: '/scanner',
          name: 'scanner',
          builder: (context, state) => const Text('scanner screen'),
        ),
        GoRoute(
          path: '/trip',
          name: 'shoppingTrip',
          builder: (context, state) => const Text('trip screen'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          cachedGroupsProvider.overrideWith(
            (ref) async => [
              Group(
                id: _groupId,
                name: 'Flat 3B',
                createdAt: _now,
                updatedAt: _now,
              ),
            ],
          ),
          cachedListsByGroupProvider(_groupId)
              .overrideWith((ref) => Stream.value(lists)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open quick add'));
    await settle(tester);
  }

  Future<void> choose(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await settle(tester);
  }

  testWidgets('"Add expense" opens the expense sheet', (tester) async {
    await pumpHome(tester, const []);
    await choose(tester, 'ADD EXPENSE');
    expect(find.byType(ExpenseCreationSheet), findsOneWidget);
  });

  testWidgets('"Add chore" opens the chore sheet', (tester) async {
    await pumpHome(tester, const []);
    await choose(tester, 'ADD CHORE');
    expect(find.byType(ChoreCreationSheet), findsOneWidget);
  });

  testWidgets('"Pin a note" opens the note composer', (tester) async {
    await pumpHome(tester, const []);
    await choose(tester, 'PIN A NOTE');
    expect(find.byType(PinwallComposer), findsOneWidget);
  });

  testWidgets('"Scan a receipt or list" opens the scanner', (tester) async {
    await pumpHome(tester, const []);
    await choose(tester, 'SCAN A RECEIPT OR LIST');
    expect(find.text('scanner screen'), findsOneWidget);
  });

  group('"Add to a list"', () {
    testWidgets('with no lists opens the new-list sheet', (tester) async {
      await pumpHome(tester, const []);
      await choose(tester, 'ADD TO A LIST');
      expect(find.byType(CreateListSheet), findsOneWidget);
    });

    testWidgets('with one list goes straight into it', (tester) async {
      await pumpHome(tester, [_list('list-1', 'Groceries')]);
      await choose(tester, 'ADD TO A LIST');
      expect(find.text('list list-1'), findsOneWidget);
    });

    testWidgets('with several lists asks which one', (tester) async {
      await pumpHome(tester, [
        _list('list-1', 'Groceries'),
        _list('list-2', 'Hardware'),
      ]);
      await choose(tester, 'ADD TO A LIST');
      expect(find.text('Add to which list?'), findsOneWidget);

      await choose(tester, 'Hardware');
      expect(find.text('list list-2'), findsOneWidget);
    });
  });

  group('"Start shopping trip"', () {
    testWidgets('is hidden with no lists to shop from', (tester) async {
      await pumpHome(tester, const []);
      expect(find.text('START SHOPPING TRIP'), findsNothing);
    });

    testWidgets('opens the trip once there is a list', (tester) async {
      await pumpHome(tester, [_list('list-1', 'Groceries')]);
      await choose(tester, 'START SHOPPING TRIP');
      expect(find.text('trip screen'), findsOneWidget);
    });
  });
}

/// Sheets animate in and some screens loop animations, so pump a few frames
/// instead of settling.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}
