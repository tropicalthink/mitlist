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
import 'package:mitlist/providers/onboarding_provider.dart';
import 'package:mitlist/widgets/hub/onboarding_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

const groupId = '11111111-1111-1111-1111-111111111111';

Group _household({int? members = 1}) => Group(
      id: groupId,
      name: 'Flat 4B',
      isPersonal: false,
      memberCount: members,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

final _list = ItemList(
  id: '22222222-2222-2222-2222-222222222222',
  groupId: groupId,
  name: 'Groceries',
  type: 'shopping',
  createdAt: DateTime.utc(2026, 1, 2),
  updatedAt: DateTime.utc(2026, 1, 2),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(
    WidgetTester tester, {
    Group? household,
    List<ItemList> lists = const [],
    List<CurrentChore> chores = const [],
    List<Expense> expenses = const [],
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cachedGroupsProvider
              .overrideWith((ref) async => [household ?? _household()]),
          cachedListsByGroupProvider
              .overrideWith((ref, id) => Stream.value(lists)),
          cachedCurrentChoresByGroupProvider
              .overrideWith((ref, id) => Stream.value(chores)),
          cachedExpensesByGroupProvider
              .overrideWith((ref, id) => Stream.value(expenses)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  HubQuickStart(groupId: groupId),
                  HubSoloInviteCard(groupId: groupId),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text)).dy;

  group('HubQuickStart', () {
    testWidgets('a new household starts at 1 of 5 with invite next',
        (tester) async {
      await pump(tester);

      expect(find.text('Get the house going'), findsOneWidget);
      for (final step in [
        'Household created',
        'Invite someone',
        'Create a list',
        'Add a chore',
        'Track an expense',
      ]) {
        expect(find.text(step), findsOneWidget);
      }
      expect(find.text('Flat 4B is set up'), findsOneWidget);
      // "Household created" starts ticked.
      expect(find.text('1 of 5 done'), findsOneWidget);
      expect(
          find.bySemanticsLabel('Next step: Invite someone'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Household created. Done'),
        findsOneWidget,
      );
    });

    testWidgets('steps tick as real things appear', (tester) async {
      await pump(tester, household: _household(members: 2), lists: [_list]);

      // A second member ticks the invite; the list ticks its step.
      expect(find.text('3 of 5 done'), findsOneWidget);
      expect(find.bySemanticsLabel('Next step: Add a chore'), findsOneWidget);
    });

    testWidgets('asking someone to join ticks the invite step', (tester) async {
      await pump(
        tester,
        prefs: {'hub_quick_start_invited:$groupId': true},
      );

      expect(find.text('2 of 5 done'), findsOneWidget);
      expect(find.bySemanticsLabel('Next step: Create a list'), findsOneWidget);
    });

    testWidgets('the first-run intent moves its step to the first open place',
        (tester) async {
      await pump(
        tester,
        prefs: {'hub_quick_start_intent:$groupId': 'money'},
      );

      expect(
        find.bySemanticsLabel('Next step: Track an expense'),
        findsOneWidget,
      );
      expect(
        top(tester, 'Track an expense'),
        lessThan(top(tester, 'Invite someone')),
      );
      // Done steps keep their place at the top.
      expect(
        top(tester, 'Household created'),
        lessThan(top(tester, 'Track an expense')),
      );
    });

    testWidgets('folds into a bar for this household and opens again',
        (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Fold quick start'));
      await tester.pumpAndSettle();

      expect(find.text('Quick start · 1 of 5'), findsOneWidget);
      expect(find.text('Create a list'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('hub_quick_start_collapsed:$groupId'), isTrue);

      await tester.tap(find.text('Quick start · 1 of 5'));
      await tester.pumpAndSettle();

      expect(find.text('Create a list'), findsOneWidget);
      expect(prefs.getBool('hub_quick_start_collapsed:$groupId'), isFalse);
    });

    testWidgets('a household folded elsewhere does not fold this one',
        (tester) async {
      await pump(
        tester,
        prefs: {'hub_quick_start_collapsed:another-household': true},
      );

      expect(find.text('Create a list'), findsOneWidget);
    });

    testWidgets('retires once every step is done', (tester) async {
      await pump(
        tester,
        household: _household(members: 2),
        lists: [_list],
        chores: [_currentChore()],
        expenses: [_expense()],
      );

      expect(find.text('Get the house going'), findsNothing);
      expect(find.textContaining('Quick start'), findsNothing);
    });

    testWidgets('renders nothing until the local caches have answered',
        (tester) async {
      final pending = StreamController<List<ItemList>>();
      addTearDown(pending.close);
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cachedGroupsProvider.overrideWith((ref) async => [_household()]),
            cachedListsByGroupProvider
                .overrideWith((ref, id) => pending.stream),
            cachedCurrentChoresByGroupProvider.overrideWith(
                (ref, id) => Stream.value(const <CurrentChore>[])),
            cachedExpensesByGroupProvider
                .overrideWith((ref, id) => Stream.value(const <Expense>[])),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: HubQuickStart(groupId: groupId)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Get the house going'), findsNothing);
    });
  });

  group('HubQuickStart for someone who joined', () {
    const joined = {'hub_quick_start_joined:$groupId': true};

    testWidgets('a household in use gives the joiner four steps of their own',
        (tester) async {
      await pump(
        tester,
        household: _household(members: 3),
        lists: [_list],
        prefs: joined,
      );

      expect(find.text('Get the house going'), findsOneWidget);
      for (final step in [
        'Joined Flat 4B',
        'Tick something off a list',
        'Take or complete a chore',
        'Check your balance',
      ]) {
        expect(find.text(step), findsOneWidget);
      }
      // None of the creator's setup steps.
      expect(find.text('Household created'), findsNothing);
      expect(find.text('Invite someone'), findsNothing);
      expect(find.text('Create a list'), findsNothing);
      expect(find.text('1 of 4 done'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Joined Flat 4B. Done'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Next step: Tick something off a list'),
        findsOneWidget,
      );
    });

    testWidgets('the markers set elsewhere tick the steps', (tester) async {
      await pump(
        tester,
        household: _household(members: 3),
        chores: [_currentChore()],
        prefs: joined,
      );
      expect(find.text('1 of 4 done'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(HubQuickStart)),
      );
      // What ticking an item (list detail) and completing a chore (Chores
      // tab, Needs you) record, followed by the invalidation they do.
      await markHubQuickStartStep(groupId, HubQuickStartStep.tick);
      await markHubQuickStartStep(groupId, HubQuickStartStep.chore);
      container.invalidate(hubQuickStartPrefsProvider(groupId));
      await tester.pumpAndSettle();

      expect(find.text('3 of 4 done'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Next step: Check your balance'),
        findsOneWidget,
      );

      // Opening Money is the last one; the card then retires.
      await markHubQuickStartStep(groupId, HubQuickStartStep.balance);
      container.invalidate(hubQuickStartPrefsProvider(groupId));
      await tester.pumpAndSettle();

      expect(find.text('Get the house going'), findsNothing);
      expect(find.textContaining('Quick start'), findsNothing);
    });

    testWidgets('joining a household that is still empty gives the setup steps',
        (tester) async {
      await pump(
        tester,
        household: _household(members: 2),
        prefs: joined,
      );

      expect(find.text('Joined Flat 4B'), findsNothing);
      expect(find.text('Household created'), findsOneWidget);
      expect(find.text('Create a list'), findsOneWidget);
      // Two members already, so the invite step is done.
      expect(find.text('2 of 5 done'), findsOneWidget);
    });

    testWidgets('another household\'s join does not change this one',
        (tester) async {
      await pump(
        tester,
        household: _household(members: 3),
        lists: [_list],
        prefs: {'hub_quick_start_joined:another-household': true},
      );

      expect(find.text('Joined Flat 4B'), findsNothing);
      expect(find.text('Household created'), findsOneWidget);
    });
  });

  group('HubSoloInviteCard', () {
    testWidgets(
        'shows while the household has one member, '
        'whatever the checklist says', (tester) async {
      await pump(
        tester,
        lists: [_list],
        chores: [_currentChore()],
        expenses: [_expense()],
        prefs: {'hub_quick_start_invited:$groupId': true},
      );

      // The checklist is finished, the house is still empty.
      expect(find.text('Get the house going'), findsNothing);
      expect(find.text('You\'re the only one here'), findsOneWidget);
      expect(find.text('SHARE INVITE LINK'), findsOneWidget);
      expect(find.text('SHOW CODE'), findsOneWidget);
    });

    testWidgets('goes once a second member joins', (tester) async {
      await pump(tester, household: _household(members: 2));
      expect(find.text('You\'re the only one here'), findsNothing);
    });

    testWidgets('stays quiet while the member count is unknown',
        (tester) async {
      await pump(tester, household: _household(members: null));
      expect(find.text('You\'re the only one here'), findsNothing);
    });
  });
}

CurrentChore _currentChore() => CurrentChore(
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

Expense _expense() => Expense(
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
