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
import 'package:mitlist/widgets/pinwall/pinwall_stat_rows.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _groupId = '11111111-1111-1111-1111-111111111111';
final _now = DateTime.utc(2026, 1, 2, 12);

const _ink = Colors.black87;
const _muted = Colors.black45;

/// Pumps [child] under a provider scope with the given household data, and
/// a localized [MaterialApp].
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  List<CurrentChore> chores = const [],
  FinanceSummary? finance,
  List<ItemList> lists = const [],
  Map<String, ({int open, int total})> itemCounts = const {},
  String currency = 'USD',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      // A fresh container per pump, so one test can render several states.
      key: UniqueKey(),
      overrides: [
        cachedCurrentChoresByGroupProvider(_groupId)
            .overrideWith((ref) => Stream.value(chores)),
        cachedFinanceSummaryByGroupProvider(_groupId).overrideWith(
          (ref) => Stream.value(
            finance ?? const FinanceSummary(balances: [], reimbursements: []),
          ),
        ),
        cachedListsByGroupProvider(_groupId)
            .overrideWith((ref) => Stream.value(lists)),
        listItemCountsProvider(_groupId)
            .overrideWith((ref) => Stream.value(itemCounts)),
        cachedGroupsProvider.overrideWith(
          (ref) async => [
            Group(
              id: _groupId,
              name: 'Flat 3B',
              currency: currency,
              createdAt: _now,
              updatedAt: _now,
            ),
          ],
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

CurrentChore _overdueChore({
  String id = 'chore-1',
  DateTime? due,
  bool mine = true,
}) =>
    CurrentChore(
      chore: Chore(
        id: id,
        groupId: _groupId,
        name: 'Vacuum',
        description: null,
        rotationType: 'none',
        frequency: 'daily',
        isActive: true,
        createdAt: _now,
        updatedAt: _now,
      ),
      pendingAssignment: ChoreAssignment(
        id: 'assignment-1',
        choreId: id,
        userId: 'user-1',
        dueDate: due ?? _now.subtract(const Duration(days: 2)),
        status: 'pending',
        assignedAt: _now,
        completedAt: null,
      ),
      dueStatus: 'overdue',
      assignedToMe: mine,
    );

ItemList _list(String id, {String type = 'shopping', bool archived = false}) =>
    ItemList(
      id: id,
      groupId: _groupId,
      name: 'List $id',
      type: type,
      isArchived: archived,
      createdAt: _now,
      updatedAt: _now,
    );

const _caller = 'user-1';

/// Two members: the caller paid nothing and owes their half of a 25.00
/// expense the flatmate paid.
const _callerOwes = FinanceSummary(
  balances: [
    BalanceEntry(
      userId: _caller,
      displayName: 'Me',
      paid: 0,
      owed: 1250,
      total: -1250,
    ),
    BalanceEntry(
      userId: 'user-2',
      displayName: 'Sam',
      paid: 2500,
      owed: 1250,
      total: 1250,
    ),
  ],
  reimbursements: [
    ReimbursementSuggestion(
      fromUserId: _caller,
      fromDisplayName: 'Me',
      toUserId: 'user-2',
      toDisplayName: 'Sam',
      amount: 1250,
    ),
  ],
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PinwallStatRow', () {
    testWidgets('tile style renders label, value, and caption', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinwallStatRow(
              style: PinwallStatRowStyle.tile,
              icon: Icons.receipt_outlined,
              label: 'Balance',
              value: '+\$25',
              subtitle: 'Owed to you',
              accent: Colors.green,
              ink: _ink,
              muted: _muted,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Balance'), findsOneWidget);
      expect(find.text('+\$25'), findsOneWidget);
      expect(find.text('Owed to you'), findsOneWidget);
    });

    testWidgets('indexCard style renders label, subtitle, and value stacked',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinwallStatRow(
              style: PinwallStatRowStyle.indexCard,
              icon: Icons.receipt_outlined,
              label: 'Balance',
              value: '+\$25',
              subtitle: 'Open',
              accent: Colors.green,
              ink: _ink,
              muted: _muted,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Balance'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('+\$25'), findsOneWidget);
      // indexCard style has no trailing chevron.
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });
  });

  group('PinwallChoresStatRow', () {
    testWidgets('tile style shows the count and the overdue caption',
        (tester) async {
      await _pump(
        tester,
        const PinwallChoresStatRow(
          groupId: _groupId,
          style: PinwallStatRowStyle.tile,
          ink: _ink,
          muted: _muted,
        ),
        chores: [_overdueChore()],
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('1 overdue'), findsOneWidget);
    });

    testWidgets('indexCard style splits count and overdue subtitle',
        (tester) async {
      await _pump(
        tester,
        const PinwallChoresStatRow(
          groupId: _groupId,
          style: PinwallStatRowStyle.indexCard,
          ink: _ink,
          muted: _muted,
        ),
        chores: [_overdueChore()],
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('1 overdue'), findsOneWidget);
    });
  });

  group('PinwallChoresStatRow counts only what is on the caller', () {
    testWidgets('a flatmate\'s overdue chore is not on you', (tester) async {
      await _pump(
        tester,
        const PinwallChoresStatRow(
          groupId: _groupId,
          style: PinwallStatRowStyle.tile,
          ink: _ink,
          muted: _muted,
        ),
        chores: [_overdueChore(mine: false)],
      );

      expect(find.text('0'), findsOneWidget);
      expect(find.text('Nothing on you'), findsOneWidget);
    });

    testWidgets('due today and overdue both count', (tester) async {
      final now = DateTime.now();
      await _pump(
        tester,
        const PinwallChoresStatRow(
          groupId: _groupId,
          style: PinwallStatRowStyle.tile,
          ink: _ink,
          muted: _muted,
        ),
        chores: [
          _overdueChore(),
          _overdueChore(
            id: 'chore-2',
            due: DateTime(now.year, now.month, now.day, 12),
          ),
        ],
      );

      // Both count; the caption leads with the overdue one.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1 overdue'), findsOneWidget);
    });
  });

  group('PinwallFinanceStatRow', () {
    testWidgets('shows what the caller owes in the household currency',
        (tester) async {
      await _pump(
        tester,
        const PinwallFinanceStatRow(
          groupId: _groupId,
          currentUserId: _caller,
          style: PinwallStatRowStyle.tile,
          ink: _ink,
          muted: _muted,
        ),
        finance: _callerOwes,
        currency: 'EUR',
      );

      // The household sum is zero; the caller's own position is not.
      expect(find.text('€12.50'), findsOneWidget);
      expect(find.text('You owe'), findsOneWidget);
    });

    testWidgets('shows what the flatmate is owed from their side',
        (tester) async {
      await _pump(
        tester,
        const PinwallFinanceStatRow(
          groupId: _groupId,
          currentUserId: 'user-2',
          style: PinwallStatRowStyle.tile,
          ink: _ink,
          muted: _muted,
        ),
        finance: _callerOwes,
        currency: 'EUR',
      );

      expect(find.text('€12.50'), findsOneWidget);
      expect(find.text('Owed to you'), findsOneWidget);
    });

    testWidgets('indexCard style splits the amount and its direction',
        (tester) async {
      await _pump(
        tester,
        const PinwallFinanceStatRow(
          groupId: _groupId,
          currentUserId: _caller,
          style: PinwallStatRowStyle.indexCard,
          ink: _ink,
          muted: _muted,
        ),
        finance: _callerOwes,
        currency: 'EUR',
      );

      expect(find.text('€12.50'), findsOneWidget);
      expect(find.text('You owe'), findsOneWidget);
    });

    testWidgets('tells "nothing recorded" apart from "settled up"',
        (tester) async {
      const row = PinwallFinanceStatRow(
        groupId: _groupId,
        currentUserId: _caller,
        style: PinwallStatRowStyle.tile,
        ink: _ink,
        muted: _muted,
      );

      await _pump(tester, row);
      expect(find.text('No expenses yet'), findsOneWidget);

      await _pump(
        tester,
        row,
        finance: const FinanceSummary(
          balances: [
            BalanceEntry(
              userId: _caller,
              displayName: 'Me',
              paid: 1000,
              owed: 1000,
              total: 0,
            ),
          ],
          reimbursements: [],
        ),
      );
      expect(find.text('Settled up'), findsOneWidget);
    });
  });

  group('PinwallListsStatRow', () {
    testWidgets('counts open items on every active list', (tester) async {
      await _pump(
        tester,
        const PinwallListsStatRow(
          groupId: _groupId,
          style: PinwallStatRowStyle.tile,
          ink: _ink,
          muted: _muted,
        ),
        lists: [
          _list('list-1'),
          _list('list-2', type: 'todo'),
          _list('list-3', archived: true),
        ],
        itemCounts: {
          'list-1': (open: 3, total: 5),
          'list-2': (open: 2, total: 2),
          'list-3': (open: 7, total: 7),
        },
      );

      expect(find.text('5'), findsOneWidget);
      expect(find.text('items left'), findsOneWidget);
    });

    testWidgets('indexCard style splits count and caption', (tester) async {
      await _pump(
        tester,
        const PinwallListsStatRow(
          groupId: _groupId,
          style: PinwallStatRowStyle.indexCard,
          ink: _ink,
          muted: _muted,
        ),
        lists: [_list('list-1')],
        itemCounts: {'list-1': (open: 1, total: 4)},
      );

      expect(find.text('1'), findsOneWidget);
      expect(find.text('item left'), findsOneWidget);
    });

    testWidgets('ticked-off lists read "All done", empty ones say so',
        (tester) async {
      const row = PinwallListsStatRow(
        groupId: _groupId,
        style: PinwallStatRowStyle.tile,
        ink: _ink,
        muted: _muted,
      );

      await _pump(
        tester,
        row,
        lists: [_list('list-1')],
        itemCounts: {'list-1': (open: 0, total: 4)},
      );
      expect(find.text('All done'), findsOneWidget);

      await _pump(tester, row, lists: [_list('list-1')]);
      expect(find.text('Lists are empty'), findsOneWidget);
    });
  });
}
