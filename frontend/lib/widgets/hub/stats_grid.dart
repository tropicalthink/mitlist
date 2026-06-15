import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/chore_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/pinwall_provider.dart';
import '../../theme/spacing.dart';
import '../app_card.dart';
import '../skeleton.dart';

class StatsGrid extends StatelessWidget {
  const StatsGrid({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _ChoresStatCard(groupId: groupId)),
        const SizedBox(width: MitlistSpacing.sm),
        Expanded(child: _FinanceStatCard(groupId: groupId)),
        const SizedBox(width: MitlistSpacing.sm),
        Expanded(child: _ListsStatCard(groupId: groupId)),
        _PinwallRemindersStatCard(groupId: groupId),
      ],
    );
  }
}

class _ChoresStatCard extends ConsumerWidget {
  const _ChoresStatCard({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final chores = ref.watch(cachedCurrentChoresByGroupProvider(groupId));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    final choresDue = chores.valueOrNull?.where((c) {
          final due = c.pendingAssignment?.dueDate;
          return due != null &&
              due.isBefore(tomorrow) &&
              due.isAfter(today.subtract(const Duration(days: 1))) &&
              c.pendingAssignment?.status != 'completed';
        }).length ??
        0;

    final choresOverdue = chores.valueOrNull?.where((c) {
          final due = c.pendingAssignment?.dueDate;
          return due != null &&
              due.isBefore(today) &&
              c.pendingAssignment?.status != 'completed';
        }).length ??
        0;

    final totalChoreCount = choresDue + choresOverdue;

    return RepaintBoundary(
      child: _StatCard(
        icon: Icons.cleaning_services_outlined,
        label: l10n.hubStatsChores,
        value: totalChoreCount > 0 ? '$totalChoreCount' : '0',
        subtitle: choresOverdue > 0
            ? '$choresOverdue ${l10n.hubStatsOverdue}'
            : (choresDue > 0 ? l10n.hubStatsDue : l10n.hubStatsAllDone),
        color: choresOverdue > 0
            ? Theme.of(context).colorScheme.error
            : (choresDue > 0
                ? Theme.of(context).colorScheme.secondary
                : Theme.of(context).colorScheme.tertiary),
        onTap: () => context.goNamed('chores'),
      ),
    );
  }
}

class _FinanceStatCard extends ConsumerWidget {
  const _FinanceStatCard({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final finance = ref.watch(cachedFinanceSummaryByGroupProvider(groupId));
    final summary = finance.valueOrNull;
    final balance = summary != null
        ? summary.balances.fold<int>(0, (sum, b) => sum + b.total)
        : 0;

    return RepaintBoundary(
      child: _StatCard(
        icon: Icons.receipt_outlined,
        label: l10n.hubStatsBalance,
        value: balance > 0
            ? '+\$${_fmt(balance)}'
            : (balance < 0 ? '-\$${_fmt(-balance)}' : '\$${_fmt(balance)}'),
        subtitle: balance != 0 ? l10n.hubStatsOpen : l10n.expenseSettled,
        color: balance > 0
            ? Theme.of(context).colorScheme.tertiary
            : (balance < 0
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurfaceVariant),
        onTap: () => context.goNamed('money'),
      ),
    );
  }

  String _fmt(int cents) => (cents / 100).toStringAsFixed(0);
}

class _ListsStatCard extends ConsumerWidget {
  const _ListsStatCard({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final lists = ref.watch(cachedListsByGroupProvider(groupId));
    final listCount = lists.valueOrNull
            ?.where((l) => l.type == 'shopping' || l.type == 'general')
            .length ??
        0;

    return RepaintBoundary(
      child: _StatCard(
        icon: Icons.shopping_cart_outlined,
        label: l10n.hubStatsLists,
        value: '$listCount',
        subtitle: listCount == 1 ? l10n.hubStatsActiveList : l10n.hubStatsActiveLists,
        color: listCount > 0
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.tertiary,
        onTap: () => context.goNamed('lists'),
      ),
    );
  }
}

class _PinwallRemindersStatCard extends ConsumerWidget {
  const _PinwallRemindersStatCard({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pinwall = ref.watch(pinwallPostsByGroupProvider(groupId));
    final pinnedWithReminders = pinwall.valueOrNull
            ?.where((p) => p.remindAt != null)
            .length ??
        0;

    if (pinnedWithReminders <= 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: MitlistSpacing.sm),
        Expanded(
          child: RepaintBoundary(
            child: _StatCard(
              icon: Icons.alarm_outlined,
              label: l10n.hubStatsReminders,
              value: '$pinnedWithReminders',
              subtitle: pinnedWithReminders == 1
                  ? l10n.hubStatsPinwallReminder
                  : l10n.hubStatsPinwallReminders,
              color: Theme.of(context).colorScheme.primary,
              onTap: () {
                final scroll = PrimaryScrollController.maybeOf(context);
                if (scroll != null) {
                  scroll.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value, $subtitle',
      button: true,
      child: AppCard(
        variant: AppCardVariant.outlined,
        padding: AppCardPadding.sm,
        interactive: true,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: MitlistSpacing.xs),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class StatsGridSkeleton extends StatelessWidget {
  const StatsGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeleton(
                    width: 16, height: 16),
                const SizedBox(height: MitlistSpacing.xs),
                const AppSkeleton(
                    width: 40, height: 20),
                const SizedBox(height: MitlistSpacing.space1),
                AppSkeleton(
                    width: 60, height: 12),
              ],
            ),
          ),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        Expanded(
          child: AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeleton(
                    width: 16, height: 16),
                const SizedBox(height: MitlistSpacing.xs),
                const AppSkeleton(
                    width: 60, height: 20),
                const SizedBox(height: MitlistSpacing.space1),
                AppSkeleton(
                    width: 50, height: 12),
              ],
            ),
          ),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        Expanded(
          child: AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeleton(
                    width: 16, height: 16),
                const SizedBox(height: MitlistSpacing.xs),
                const AppSkeleton(
                    width: 30, height: 20),
                const SizedBox(height: MitlistSpacing.space1),
                AppSkeleton(
                    width: 55, height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
