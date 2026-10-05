import 'package:collection/collection.dart';

import '../models/chore_models.dart';
import '../models/finance_models.dart';
import '../models/list_models.dart';
import '../models/pinwall_models.dart';

// What Home summarises for the signed-in member, computed from the household's
// cached data. Needs you, its count tiles, the board's index card and the nav
// badge all count through these, so no two surfaces disagree.

/// The caller's open chores due today, and overdue ones (oldest first).
/// Chores on someone else's turn are not on the caller.
({List<CurrentChore> overdue, List<CurrentChore> dueToday}) choresOnMe(
  Iterable<CurrentChore> chores,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final overdue = <CurrentChore>[];
  final dueToday = <CurrentChore>[];
  for (final c in chores) {
    final due = c.pendingAssignment?.dueDate;
    if (!c.assignedToMe ||
        due == null ||
        c.pendingAssignment?.status == 'completed') {
      continue;
    }
    if (due.isBefore(today)) {
      overdue.add(c);
    } else if (due.isBefore(tomorrow)) {
      dueToday.add(c);
    }
  }
  overdue.sort((a, b) =>
      a.pendingAssignment!.dueDate!.compareTo(b.pendingAssignment!.dueDate!));
  return (overdue: overdue, dueToday: dueToday);
}

/// The caller's net position in cents: positive when owed, negative when
/// owing. Summing every member's total would always give zero, so only the
/// caller's own entry counts. The summary only has entries for members with
/// money activity, so [hasExpenses] false means nothing has been recorded,
/// which is not the same as everyone being square.
({int cents, bool hasExpenses}) myBalance(
  FinanceSummary? summary,
  String? userId,
) {
  final cents =
      summary?.balances.firstWhereOrNull((b) => b.userId == userId)?.total ?? 0;
  return (
    cents: cents,
    hasExpenses: summary != null && summary.balances.isNotEmpty,
  );
}

/// The largest payment the caller should make, skipping any pair that
/// already has a settlement waiting for confirmation (the Money tab hides
/// those too, so nobody settles twice).
ReimbursementSuggestion? largestDebt(
  FinanceSummary? summary,
  Iterable<Settlement> settlements,
  String? userId,
) {
  if (summary == null || userId == null) return null;
  final pending = {
    for (final s in settlements)
      if (s.status == SettlementStatus.pending) '${s.fromUserId}>${s.toUserId}',
  };
  return summary.reimbursements
      .where((r) => r.fromUserId == userId)
      .where((r) => !pending.contains('${r.fromUserId}>${r.toUserId}'))
      .sorted((a, b) => b.amount.compareTo(a.amount))
      .firstOrNull;
}

/// Unchecked items across the household's active lists, and the list with
/// the most of them. Counts come from the local item cache (the same source
/// as the Lists tab's "N left").
({int open, int total, ItemList? busiest, int busiestOpen}) openListItems(
  Iterable<ItemList> lists,
  Map<String, ({int open, int total})> counts,
) {
  var open = 0;
  var total = 0;
  ItemList? busiest;
  var busiestOpen = 0;
  for (final list in lists) {
    if (list.isArchived) continue;
    final c = counts[list.id];
    if (c == null) continue;
    open += c.open;
    total += c.total;
    if (c.open > busiestOpen) {
      busiest = list;
      busiestOpen = c.open;
    }
  }
  return (open: open, total: total, busiest: busiest, busiestOpen: busiestOpen);
}

/// Pinwall notes with a reminder set for later today, soonest first.
List<PinwallPost> remindersLaterToday(
  Iterable<PinwallPost> posts,
  DateTime now,
) {
  final tomorrow =
      DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  return posts.where((p) {
    final at = p.remindAt?.toLocal();
    return at != null && !at.isBefore(now) && at.isBefore(tomorrow);
  }).sorted((a, b) => a.remindAt!.compareTo(b.remindAt!));
}
