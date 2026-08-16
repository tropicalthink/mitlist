import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/chore_models.dart';
import 'package:mitlist/models/finance_models.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/providers/chore_provider.dart';
import 'package:mitlist/providers/finance_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/list_provider.dart';
import 'package:mitlist/widgets/board/artifact_scraps.dart';
import 'package:mitlist/widgets/hub/onboarding_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const groupId = '11111111-1111-1111-1111-111111111111';

  final household = Group(
    id: groupId,
    name: 'Flat 4B',
    isPersonal: false,
    memberCount: 2,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget host(List<Override> overrides) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: HubQuickStart(groupId: groupId),
          ),
        ),
      ),
    );
  }

  group('HubQuickStart', () {
    testWidgets('sequences steps and keeps invite out of progress',
        (tester) async {
      await tester.pumpWidget(host([
        cachedGroupsProvider.overrideWith((ref) async => [household]),
        cachedListsByGroupProvider
            .overrideWith((ref, id) => Stream.value(const <ItemList>[])),
        cachedCurrentChoresByGroupProvider
            .overrideWith((ref, id) => Stream.value(const <CurrentChore>[])),
        cachedExpensesByGroupProvider
            .overrideWith((ref, id) => Stream.value(const <Expense>[])),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Get the house going'), findsOneWidget);
      expect(find.text('Invite flatmates'), findsOneWidget);
      expect(find.text('Create a list'), findsOneWidget);
      expect(find.text('Add a chore'), findsOneWidget);
      expect(find.text('Track an expense'), findsOneWidget);

      // Nothing is done yet, and the flatmate who already joined
      // (memberCount 2) does not count toward progress: invite is an offer,
      // not a step.
      expect(find.text('0 of 3 done'), findsOneWidget);

      // Every step shows the ghost of the thing it creates, and exactly one
      // — the leading step — wears the solid plus badge.
      expect(
        find.byWidgetPredicate((w) => w is ListScrap && w.ghost),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is ChoreScrap && w.ghost),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is ReceiptScrap && w.ghost),
        findsOneWidget,
      );
      expect(find.byType(ScrapPlusBadge), findsOneWidget);

      // The invite slip shows the household's seats.
      expect(find.byType(InviteSeats), findsOneWidget);

      // Every stamp-carrying note (two waiting steps + the invite slip) has a
      // stamp widget; only the invite slip's is scaled in, because a second
      // member genuinely exists. The press affordances are also AnimatedScale
      // ancestors, always at 1.0, so the discriminating count is the hidden
      // stamps.
      expect(find.text('DONE'), findsNWidgets(3));
      final stamps = tester.widgetList<AnimatedScale>(
        find.ancestor(
          of: find.text('DONE'),
          matching: find.byType(AnimatedScale),
        ),
      );
      expect(stamps.where((s) => s.scale == 0.0).length, 2);
    });

    testWidgets('advances the lead step as real things appear', (tester) async {
      final list = ItemList(
        id: '22222222-2222-2222-2222-222222222222',
        groupId: groupId,
        name: 'Groceries',
        type: 'shopping',
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      await tester.pumpWidget(host([
        cachedGroupsProvider.overrideWith((ref) async => [household]),
        cachedListsByGroupProvider
            .overrideWith((ref, id) => Stream.value([list])),
        cachedCurrentChoresByGroupProvider
            .overrideWith((ref, id) => Stream.value(const <CurrentChore>[])),
        cachedExpensesByGroupProvider
            .overrideWith((ref, id) => Stream.value(const <Expense>[])),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('1 of 3 done'), findsOneWidget);
      // The list ghost has filled in — the real artifact is on the board —
      // and the chore step takes the lead.
      expect(
        find.byWidgetPredicate((w) => w is ListScrap && !w.ghost),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) =>
            w is Stack &&
            w.children.any((c) => c is ChoreScrap) &&
            w.children
                .whereType<Positioned>()
                .any((p) => p.child is ScrapPlusBadge)),
        findsOneWidget,
      );
    });

    testWidgets('retires once all three steps are done, even solo',
        (tester) async {
      final soloHousehold = Group(
        id: groupId,
        name: 'Flat 4B',
        isPersonal: false,
        memberCount: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final list = ItemList(
        id: '22222222-2222-2222-2222-222222222222',
        groupId: groupId,
        name: 'Groceries',
        type: 'shopping',
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      await tester.pumpWidget(host([
        cachedGroupsProvider.overrideWith((ref) async => [soloHousehold]),
        cachedListsByGroupProvider
            .overrideWith((ref, id) => Stream.value([list])),
        cachedCurrentChoresByGroupProvider.overrideWith(
            (ref, id) => Stream.value([_currentChore(groupId)])),
        cachedExpensesByGroupProvider
            .overrideWith((ref, id) => Stream.value([_expense(groupId)])),
      ]));
      await tester.pumpAndSettle();

      // A solo household that has done the real work is done onboarding;
      // no one is nagged into inviting.
      expect(find.text('Get the house going'), findsNothing);
    });

    testWidgets('renders nothing until the local caches have answered',
        (tester) async {
      final pending = StreamController<List<ItemList>>();
      addTearDown(pending.close);

      await tester.pumpWidget(host([
        cachedGroupsProvider.overrideWith((ref) async => [household]),
        cachedListsByGroupProvider.overrideWith((ref, id) => pending.stream),
        cachedCurrentChoresByGroupProvider
            .overrideWith((ref, id) => Stream.value(const <CurrentChore>[])),
        cachedExpensesByGroupProvider
            .overrideWith((ref, id) => Stream.value(const <Expense>[])),
      ]));
      await tester.pump();
      await tester.pump();

      expect(find.text('Get the house going'), findsNothing);
    });
  });
}

CurrentChore _currentChore(String groupId) => CurrentChore(
      chore: Chore(
        id: '44444444-4444-4444-4444-444444444444',
        groupId: groupId,
        name: 'Take out the bins',
        rotationType: 'round-robin',
        frequency: 'weekly',
        isActive: true,
        createdAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
      ),
      dueStatus: 'due',
      assignedToMe: true,
    );

Expense _expense(String groupId) => Expense(
      id: '55555555-5555-5555-5555-555555555555',
      groupId: groupId,
      payerId: '66666666-6666-6666-6666-666666666666',
      amount: 1200,
      baseAmount: 1200,
      description: 'Groceries',
      category: 'groceries',
      currency: 'EUR',
      date: DateTime.utc(2026, 1, 2),
      createdAt: DateTime.utc(2026, 1, 2),
    );
