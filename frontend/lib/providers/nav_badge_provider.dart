import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chore_models.dart';
import '../router.dart' show currentGroupIdProvider;
import '../services/group_id_validator.dart';
import '../utils/active_group_context.dart';
import '../utils/home_summary.dart';
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

  // The caller's due and overdue chores, the same count Home's Needs you
  // shows: a flatmate's turn is not something this badge should nag about.
  final mine = choresOnMe(chores, DateTime.now());
  final choreCount = mine.overdue.length + mine.dueToday.length;

  final settlementCount = summary?.reimbursements.length ?? 0;

  return NavBadgeCounts(
    choreCount: choreCount,
    settlementCount: settlementCount,
  );
});
