import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chore_models.dart';
import '../router.dart' show currentGroupIdProvider;
import '../services/group_id_validator.dart';
import '../utils/active_group_context.dart';
import 'chore_provider.dart';
import 'finance_provider.dart';
import 'group_provider.dart';

class NavBadgeCounts {
  const NavBadgeCounts({
    this.choreCount = 0,
    this.settlementCount = 0,
  });
  final int choreCount;
  final int settlementCount;

  int get total => choreCount + settlementCount;
}

/// Reactive badge counts derived from cached chore/finance streams.
final navBadgeCountsProvider = Provider<NavBadgeCounts>((ref) {
  ref.watch(currentGroupIdProvider);
  final groups = ref.watch(cachedGroupsProvider).valueOrNull;
  if (groups == null) return const NavBadgeCounts();

  final groupId = resolveActiveGroupId(
    groups,
    ref.read(currentGroupIdProvider),
  );
  if (!isValidGroupId(groupId)) {
    return const NavBadgeCounts();
  }

  final gid = groupId!;
  final chores =
      ref.watch(cachedCurrentChoresByGroupProvider(gid)).valueOrNull ??
          const <CurrentChore>[];
  final summary =
      ref.watch(cachedFinanceSummaryByGroupProvider(gid)).valueOrNull;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final choreCount = chores.where((c) {
    final due = c.pendingAssignment?.dueDate;
    return due != null &&
        due.isBefore(today.add(const Duration(days: 1))) &&
        c.pendingAssignment?.status != 'completed';
  }).length;

  final settlementCount = summary?.reimbursements.length ?? 0;

  return NavBadgeCounts(
    choreCount: choreCount,
    settlementCount: settlementCount,
  );
});
