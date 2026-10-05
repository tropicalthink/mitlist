// Home's "Needs you" card (plans/048 stage 4): what is on the caller, the two
// zero states, and the inline actions going through the offline-first
// repositories; plus what a member who just joined sees (stage 7).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/auth_models.dart';
import 'package:mitlist/models/chore_models.dart';
import 'package:mitlist/models/finance_models.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/models/meal_plan_models.dart';
import 'package:mitlist/models/pinwall_models.dart';
import 'package:mitlist/providers/chore_provider.dart';
import 'package:mitlist/providers/finance_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/list_provider.dart';
import 'package:mitlist/providers/meal_plan_provider.dart';
import 'package:mitlist/providers/pinwall_provider.dart';
import 'package:mitlist/repositories/chore_repository.dart';
import 'package:mitlist/repositories/finance_repository.dart';
import 'package:mitlist/widgets/hub/needs_you_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _groupId = '11111111-1111-1111-1111-111111111111';
const _meId = 'user-1';
final _created = DateTime.utc(2026, 1, 1);

final _me = User(
  id: _meId,
  email: 'me@example.com',
  firstName: 'Me',
  lastName: 'Test',
  isActive: true,
  isVerified: true,
  isGuest: false,
  createdAt: _created,
  updatedAt: _created,
);

DateTime _today(int hour) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, hour);
}

CurrentChore _chore(String id, String name,
    {int daysLate = 0, bool mine = true}) {
  final due = _today(9).subtract(Duration(days: daysLate));
  return CurrentChore(
    chore: Chore(
      id: id,
      groupId: _groupId,
      name: name,
      description: null,
      rotationType: 'round_robin',
      frequency: 'weekly',
      isActive: true,
      createdAt: _created,
      updatedAt: _created,
    ),
    pendingAssignment: ChoreAssignment(
      id: 'a-$id',
      choreId: id,
      userId: mine ? _meId : 'user-2',
      dueDate: due,
      status: 'pending',
      assignedAt: _created,
      completedAt: null,
    ),
    dueStatus: daysLate > 0 ? 'overdue' : 'due',
    assignedToMe: mine,
  );
}

/// The caller owes Sam half of a 25.00 expense Sam paid.
const _iOweSam = FinanceSummary(
  balances: [
    BalanceEntry(
        userId: _meId, displayName: 'Me', paid: 0, owed: 1250, total: -1250),
    BalanceEntry(
        userId: 'user-2',
        displayName: 'Sam',
        paid: 2500,
        owed: 1250,
        total: 1250),
  ],
  reimbursements: [
    ReimbursementSuggestion(
      fromUserId: _meId,
      fromDisplayName: 'Me',
      toUserId: 'user-2',
      toDisplayName: 'Sam',
      amount: 1250,
    ),
  ],
);

final _groceries = ItemList(
  id: 'list-1',
  groupId: _groupId,
  name: 'Groceries',
  type: 'shopping',
  createdAt: _created,
  updatedAt: _created,
);

class _FakeChoreRepository implements ChoreRepository {
  final completed = <String>[];

  @override
  Future<void> completeOfflineFirst(String choreId, {String? groupId}) async {
    completed.add(choreId);
  }

  @override
  Future<void> undoOfflineFirst(String choreId, {String? groupId}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFinanceRepository implements FinanceRepository {
  final recorded = <CreateSettlementRequest>[];

  @override
  Future<Settlement> recordSettlementOfflineFirst({
    required String groupId,
    required CreateSettlementRequest req,
    required String createdBy,
  }) async {
    recorded.add(req);
    return Settlement(
      id: 'local-1',
      groupId: groupId,
      fromUserId: req.fromUserId,
      toUserId: req.toUserId,
      amount: req.amount,
      status: SettlementStatus.pending,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester, {
  List<CurrentChore> chores = const [],
  FinanceSummary finance =
      const FinanceSummary(balances: [], reimbursements: []),
  List<ItemList> lists = const [],
  Map<String, ({int open, int total})> counts = const {},
  List<Settlement> settlements = const [],
  List<TodayMeal> meals = const [],
  _FakeChoreRepository? choreRepo,
  _FakeFinanceRepository? financeRepo,
  Size surface = const Size(800, 1400),
}) async {
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cachedCurrentChoresByGroupProvider(_groupId)
            .overrideWith((ref) => Stream.value(chores)),
        cachedFinanceSummaryByGroupProvider(_groupId)
            .overrideWith((ref) => Stream.value(finance)),
        cachedListsByGroupProvider(_groupId)
            .overrideWith((ref) => Stream.value(lists)),
        listItemCountsProvider(_groupId)
            .overrideWith((ref) => Stream.value(counts)),
        cachedSettlementsByGroupProvider(_groupId)
            .overrideWith((ref) => Stream.value(settlements)),
        todayMealPlansProvider(_groupId).overrideWith((ref) async => meals),
        pinwallPostsByGroupProvider(_groupId)
            .overrideWith((ref) => Stream.value(const <PinwallPost>[])),
        cachedGroupsProvider.overrideWith(
          (ref) async => [
            Group(
              id: _groupId,
              name: 'Flat 3B',
              currency: 'EUR',
              createdAt: _created,
              updatedAt: _created,
            ),
          ],
        ),
        choreRepositoryProvider
            .overrideWith((ref) async => choreRepo ?? _FakeChoreRepository()),
        financeRepositoryProvider.overrideWith(
            (ref) async => financeRepo ?? _FakeFinanceRepository()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          // Home's layout: a toolbar, then the card first in a padded list.
          appBar: const PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight),
            child: SizedBox(height: kToolbarHeight),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [NeedsYouSection(groupId: _groupId, me: _me)],
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _rows(String kind) => find.byWidgetPredicate((w) {
      final key = w.key;
      return key is ValueKey<String> &&
          key.value.startsWith('needs-you-$kind:');
    });

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows what is on the caller, then what the house has open',
      (tester) async {
    await _pump(
      tester,
      chores: [
        _chore('c1', 'Take out bins', daysLate: 2),
        _chore('c2', 'Vacuum'),
        _chore('c3', 'Clean bathroom', mine: false, daysLate: 1),
      ],
      finance: _iOweSam,
      lists: [_groceries],
      counts: {'list-1': (open: 3, total: 5)},
      meals: [
        (
          plan: MealPlan(
            id: 'meal-1',
            groupId: _groupId,
            date: _today(0),
            slot: 'dinner',
            recipeId: 'recipe-1',
            servings: 2,
            createdAt: _created,
            updatedAt: _created,
          ),
          recipe: null,
        ),
      ],
    );

    expect(find.text('Needs you'), findsOneWidget);
    expect(find.text('Take out bins'), findsOneWidget);
    expect(find.text('2 days overdue'), findsOneWidget);
    expect(find.text('Vacuum'), findsOneWidget);
    expect(find.text('Due today'), findsOneWidget);
    // A flatmate's turn is not on the caller.
    expect(find.text('Clean bathroom'), findsNothing);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('You owe €12.50'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('3 items left'), findsOneWidget);
    expect(find.text('Tonight'), findsOneWidget);
    expect(find.text('All caught up'), findsNothing);
    expect(find.text('Not set up yet'), findsNothing);
    // The count tiles sit under the rows.
    expect(find.text('You owe'), findsOneWidget);
    expect(find.text('items left'), findsOneWidget);
  });

  testWidgets('caps the card at five rows and chores at three', (tester) async {
    await _pump(
      tester,
      chores: [
        for (var i = 0; i < 6; i++) _chore('c$i', 'Chore $i', daysLate: i + 1),
      ],
      finance: _iOweSam,
      lists: [_groceries],
      counts: {'list-1': (open: 3, total: 5)},
    );

    expect(_rows('chore'), findsNWidgets(3));
    expect(_rows('money'), findsOneWidget);
    expect(_rows('list'), findsOneWidget);
    // Oldest first.
    expect(find.text('Chore 5'), findsOneWidget);
    expect(find.text('Chore 0'), findsNothing);
  });

  testWidgets('"All caught up" when the house is in use but nothing is on you',
      (tester) async {
    await _pump(
      tester,
      chores: [_chore('c1', 'Clean bathroom', mine: false, daysLate: 1)],
      lists: [_groceries],
      counts: {'list-1': (open: 3, total: 5)},
    );

    expect(find.text('All caught up'), findsOneWidget);
    expect(find.text('Not set up yet'), findsNothing);
    // The house's open list still shows under it.
    expect(find.text('Groceries'), findsOneWidget);
  });

  testWidgets('"Not set up yet" when the household has nothing in it',
      (tester) async {
    await _pump(tester);

    expect(find.text('Not set up yet'), findsOneWidget);
    expect(find.text('All caught up'), findsNothing);
    expect(find.text('No expenses yet'), findsOneWidget);
    expect(find.text('Lists are empty'), findsOneWidget);
  });

  testWidgets('a payment already waiting for confirmation is not asked again',
      (tester) async {
    await _pump(
      tester,
      finance: _iOweSam,
      settlements: [
        Settlement(
          id: 's-1',
          groupId: _groupId,
          fromUserId: _meId,
          toUserId: 'user-2',
          amount: 1250,
          status: SettlementStatus.pending,
          createdBy: _meId,
          createdAt: _created,
        ),
      ],
    );

    expect(_rows('money'), findsNothing);
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets('Done completes the chore through the offline-first repository',
      (tester) async {
    final repo = _FakeChoreRepository();
    await _pump(
      tester,
      chores: [_chore('c1', 'Take out bins', daysLate: 1)],
      choreRepo: repo,
    );

    await tester.tap(find.text('DONE'));
    await _settle(tester);

    expect(repo.completed, ['c1']);
    expect(find.text('Take out bins done'), findsOneWidget);
  });

  testWidgets('Settle confirms, then queues the settlement', (tester) async {
    final repo = _FakeFinanceRepository();
    await _pump(tester, finance: _iOweSam, financeRepo: repo);

    await tester.tap(find.text('SETTLE'));
    await _settle(tester);
    expect(find.text('You’ll pay Sam €12.50'), findsOneWidget);

    await tester.tap(find.text('CONFIRM'));
    await _settle(tester);

    expect(repo.recorded, hasLength(1));
    expect(repo.recorded.single.fromUserId, _meId);
    expect(repo.recorded.single.toUserId, 'user-2');
    expect(repo.recorded.single.amount, 1250);
  });

  testWidgets(
      'on a 360x800 phone the caller\'s chore, balance and lists are '
      'above the fold', (tester) async {
    await _pump(
      tester,
      surface: const Size(360, 800),
      chores: [_chore('c1', 'Take out bins', daysLate: 1)],
      finance: _iOweSam,
      lists: [_groceries],
      counts: {'list-1': (open: 14, total: 20)},
    );

    // Leave room for the bottom navigation bar.
    const fold = 800 - 80;
    for (final text in ['Take out bins', 'You owe', '14', 'items left']) {
      expect(tester.getBottomLeft(find.text(text)).dy, lessThan(fold),
          reason: '"$text" should be visible without scrolling');
    }
  });

  group('someone who just joined', () {
    setUp(() {
      // Set by the join landing, the join sheet and the code join.
      SharedPreferences.setMockInitialValues(
          {'hub_quick_start_joined:$_groupId': true});
    });

    testWidgets(
        '"Nothing on you yet", then what the house is working on, '
        'read-only', (tester) async {
      await _pump(
        tester,
        chores: [
          _chore('c1', 'Clean bathroom', mine: false, daysLate: 1),
          _chore('c2', 'Water plants', mine: false),
          _chore('c3', 'Vacuum', mine: false, daysLate: 2),
          // Not due yet: not something the house is behind on.
          _chore('c4', 'Defrost freezer', mine: false, daysLate: -3),
        ],
        lists: [_groceries],
        counts: {'list-1': (open: 3, total: 5)},
      );

      expect(find.text('Nothing on you yet'), findsOneWidget);
      expect(find.text("Here's what the house is working on."), findsOneWidget);
      expect(find.text('All caught up'), findsNothing);
      // Two of the housemates' chores, most overdue first, marked as theirs.
      expect(_rows('house-chore'), findsNWidgets(2));
      expect(find.text('Vacuum'), findsOneWidget);
      expect(find.text('2 days overdue \u00b7 Not your turn'), findsOneWidget);
      expect(find.text('Clean bathroom'), findsOneWidget);
      expect(find.text('Water plants'), findsNothing);
      expect(find.text('Defrost freezer'), findsNothing);
      // Nothing to do on someone else's turn.
      expect(find.text('DONE'), findsNothing);
      // The house's open list still shows.
      expect(find.text('Groceries'), findsOneWidget);
    });

    testWidgets('once something is on them, the usual rows', (tester) async {
      await _pump(
        tester,
        chores: [
          _chore('c1', 'Take out bins'),
          _chore('c2', 'Clean bathroom', mine: false, daysLate: 1),
        ],
      );

      expect(find.text('Nothing on you yet'), findsNothing);
      expect(find.text('Take out bins'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);
      expect(_rows('house-chore'), findsNothing);
    });

    testWidgets('a household with nothing in it is "Not set up yet"',
        (tester) async {
      await _pump(tester);

      expect(find.text('Not set up yet'), findsOneWidget);
      expect(find.text('Nothing on you yet'), findsNothing);
    });
  });
}
