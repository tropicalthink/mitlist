import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/chore_models.dart';
import 'package:mitlist/models/finance_models.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/providers/chore_provider.dart';
import 'package:mitlist/providers/finance_provider.dart';
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
}) async {
  await tester.pumpWidget(
    ProviderScope(
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

CurrentChore _overdueChore() => CurrentChore(
      chore: Chore(
        id: 'chore-1',
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
        choreId: 'chore-1',
        userId: 'user-1',
        dueDate: _now.subtract(const Duration(days: 2)),
        status: 'pending',
        assignedAt: _now,
        completedAt: null,
      ),
      dueStatus: 'overdue',
      assignedToMe: true,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PinwallStatRow', () {
    testWidgets('inline style renders label, value, and chevron affordance',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinwallStatRow(
              style: PinwallStatRowStyle.inline,
              icon: Icons.receipt_outlined,
              label: 'Balance',
              value: '+\$25',
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
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
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
    testWidgets('inline style folds overdue count into a single value string',
        (tester) async {
      await _pump(
        tester,
        const PinwallChoresStatRow(
          groupId: _groupId,
          style: PinwallStatRowStyle.inline,
          ink: _ink,
          muted: _muted,
        ),
        chores: [_overdueChore()],
      );

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

  group('PinwallFinanceStatRow', () {
    testWidgets('renders a positive balance with the household total',
        (tester) async {
      await _pump(
        tester,
        const PinwallFinanceStatRow(
          groupId: _groupId,
          style: PinwallStatRowStyle.inline,
          ink: _ink,
          muted: _muted,
        ),
        finance: const FinanceSummary(
          balances: [
            BalanceEntry(
              userId: 'user-1',
              displayName: 'Test User',
              paid: 2500,
              owed: 0,
              total: 2500,
            ),
          ],
          reimbursements: [],
        ),
      );

      expect(find.textContaining('+\$25'), findsOneWidget);
    });
  });

  group('PinwallListsStatRow', () {
    testWidgets('counts only shopping/general lists', (tester) async {
      await _pump(
        tester,
        const PinwallListsStatRow(
          groupId: _groupId,
          style: PinwallStatRowStyle.indexCard,
          ink: _ink,
          muted: _muted,
        ),
        lists: [
          ItemList(
            id: 'list-1',
            groupId: _groupId,
            name: 'Groceries',
            type: 'shopping',
            createdAt: _now,
            updatedAt: _now,
          ),
        ],
      );

      expect(find.text('1'), findsOneWidget);
    });
  });
}
