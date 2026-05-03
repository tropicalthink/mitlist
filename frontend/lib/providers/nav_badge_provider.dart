import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chore_models.dart';
import '../models/finance_models.dart';
import '../services/group_id_validator.dart';
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

final navBadgeCountsProvider = FutureProvider<NavBadgeCounts>((ref) async {
  try {
    final groupSvc = await ref.read(groupServiceProviderAsync.future);
    final groups = await groupSvc.listGroups(limit: 1);
    final groupId = groups.isNotEmpty ? groups.first.id : null;
    if (!isValidGroupId(groupId)) {
      return const NavBadgeCounts();
    }

    final gid = groupId!;

    final choresF = ref.read(cachedCurrentChoresByGroupProvider(gid).future);
    final financeF =
        ref.read(cachedFinanceSummaryByGroupProvider(gid).future);

    final results = await Future.wait([
      choresF,
      financeF,
    ], eagerError: false);

    final chores = results[0] as List<CurrentChore>;
    final summary = results[1] as FinanceSummary?;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final choreCount = chores.where((c) {
      final due = c.pendingAssignment?.dueDate;
      return due != null &&
          due.isBefore(today.add(const Duration(days: 1))) &&
          c.pendingAssignment?.status != 'completed';
    }).length;

    final settlementCount =
        summary?.reimbursements.length ?? 0;

    return NavBadgeCounts(
      choreCount: choreCount,
      settlementCount: settlementCount,
    );
  } catch (_) {
    return const NavBadgeCounts();
  }
});
