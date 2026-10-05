import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/chore_models.dart';
import 'package:mitlist/models/finance_models.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/models/pinwall_models.dart';
import 'package:mitlist/utils/home_summary.dart';

const _groupId = '11111111-1111-1111-1111-111111111111';
const _me = 'user-1';
final _now = DateTime(2026, 3, 10, 12);

CurrentChore _chore(
  String id, {
  required DateTime? due,
  bool mine = true,
  String status = 'pending',
}) =>
    CurrentChore(
      chore: Chore(
        id: id,
        groupId: _groupId,
        name: 'Chore $id',
        description: null,
        rotationType: 'none',
        frequency: 'weekly',
        isActive: true,
        createdAt: _now,
        updatedAt: _now,
      ),
      pendingAssignment: ChoreAssignment(
        id: 'a-$id',
        choreId: id,
        userId: mine ? _me : 'user-2',
        dueDate: due,
        status: status,
        assignedAt: _now,
        completedAt: null,
      ),
      dueStatus: 'due',
      assignedToMe: mine,
    );

BalanceEntry _balance(String userId, int total) => BalanceEntry(
      userId: userId,
      displayName: userId,
      paid: total > 0 ? total : 0,
      owed: total < 0 ? -total : 0,
      total: total,
    );

ReimbursementSuggestion _owe(String from, String to, int amount) =>
    ReimbursementSuggestion(
      fromUserId: from,
      fromDisplayName: from,
      toUserId: to,
      toDisplayName: to,
      amount: amount,
    );

ItemList _list(String id, {bool archived = false}) => ItemList(
      id: id,
      groupId: _groupId,
      name: 'List $id',
      type: 'shopping',
      isArchived: archived,
      createdAt: _now,
      updatedAt: _now,
    );

void main() {
  group('choresOnMe', () {
    test('splits the caller\'s chores into overdue (oldest first) and today',
        () {
      final result = choresOnMe([
        _chore('late', due: _now.subtract(const Duration(days: 1))),
        _chore('later', due: _now.subtract(const Duration(days: 4))),
        _chore('today', due: DateTime(2026, 3, 10, 18)),
        _chore('tomorrow', due: DateTime(2026, 3, 11, 9)),
        _chore('theirs', due: _now, mine: false),
        _chore('done', due: _now, status: 'completed'),
        _chore('undated', due: null),
      ], _now);

      expect(result.overdue.map((c) => c.chore.id), ['later', 'late']);
      expect(result.dueToday.map((c) => c.chore.id), ['today']);
    });
  });

  group('myBalance', () {
    test('is the caller\'s own entry, not the household sum', () {
      final summary = FinanceSummary(
        balances: [_balance(_me, -1250), _balance('user-2', 1250)],
        reimbursements: const [],
      );
      expect(myBalance(summary, _me), (cents: -1250, hasExpenses: true));
    });

    test('tells "nothing recorded" from "square"', () {
      expect(
        myBalance(
          const FinanceSummary(balances: [], reimbursements: []),
          _me,
        ),
        (cents: 0, hasExpenses: false),
      );
      expect(
        myBalance(
          FinanceSummary(balances: [_balance('user-2', 0)], reimbursements: []),
          _me,
        ),
        (cents: 0, hasExpenses: true),
      );
    });
  });

  group('largestDebt', () {
    final summary = FinanceSummary(
      balances: const [],
      reimbursements: [
        _owe(_me, 'sam', 500),
        _owe(_me, 'alex', 1200),
        _owe('sam', 'alex', 9000),
      ],
    );

    test('is the biggest payment the caller makes', () {
      expect(largestDebt(summary, const [], _me)?.toUserId, 'alex');
    });

    test('skips a pair already waiting for confirmation', () {
      final pending = Settlement(
        id: 's-1',
        groupId: _groupId,
        fromUserId: _me,
        toUserId: 'alex',
        amount: 1200,
        status: SettlementStatus.pending,
        createdBy: _me,
        createdAt: _now,
      );
      expect(largestDebt(summary, [pending], _me)?.toUserId, 'sam');
    });

    test('is null for a caller who owes nothing', () {
      expect(largestDebt(summary, const [], 'alex'), isNull);
      expect(largestDebt(summary, const [], null), isNull);
    });
  });

  group('openListItems', () {
    test('sums open items over active lists and finds the busiest', () {
      final result = openListItems(
        [_list('a'), _list('b'), _list('gone', archived: true), _list('c')],
        {
          'a': (open: 2, total: 5),
          'b': (open: 7, total: 7),
          'gone': (open: 40, total: 40),
        },
      );
      expect(result.open, 9);
      expect(result.total, 12);
      expect(result.busiest?.id, 'b');
      expect(result.busiestOpen, 7);
    });

    test('has no busiest list when everything is ticked off', () {
      final result = openListItems([_list('a')], {'a': (open: 0, total: 3)});
      expect(result.busiest, isNull);
      expect(result.total, 3);
    });
  });

  group('remindersLaterToday', () {
    PinwallPost post(String id, DateTime? remindAt) => PinwallPost(
          id: id,
          groupId: _groupId,
          userId: _me,
          content: id,
          createdAt: _now,
          remindAt: remindAt,
        );

    test('keeps today\'s upcoming reminders, soonest first', () {
      final result = remindersLaterToday([
        post('past', DateTime(2026, 3, 10, 9)),
        post('evening', DateTime(2026, 3, 10, 19)),
        post('afternoon', DateTime(2026, 3, 10, 15)),
        post('tomorrow', DateTime(2026, 3, 11, 8)),
        post('none', null),
      ], _now);
      expect(result.map((p) => p.id), ['afternoon', 'evening']);
    });
  });
}
