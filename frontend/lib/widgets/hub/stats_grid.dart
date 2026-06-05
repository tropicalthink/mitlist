import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/chore_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/pinwall_provider.dart';
import '../../theme/spacing.dart';
import '../app_card.dart';
import '../skeleton.dart';

class StatsGrid extends ConsumerWidget {
  const StatsGrid({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chores =
        ref.watch(cachedCurrentChoresByGroupProvider(groupId));
    final finance =
        ref.watch(cachedFinanceSummaryByGroupProvider(groupId));
    final lists = ref.watch(cachedListsByGroupProvider(groupId));
    final pinwall = ref.watch(pinwallPostsByGroupProvider(groupId));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(Duration(days: 1));

    final choresDue = chores.valueOrNull
            ?.where((c) {
              final due = c.pendingAssignment?.dueDate;
              return due != null &&
                  due.isBefore(tomorrow) &&
                  due.isAfter(today.subtract(Duration(days: 1))) &&
                  c.pendingAssignment?.status != 'completed';
            })
            .length ??
        0;

    final choresOverdue = chores.valueOrNull
            ?.where((c) {
              final due = c.pendingAssignment?.dueDate;
              return due != null &&
                  due.isBefore(today) &&
                  c.pendingAssignment?.status != 'completed';
            })
            .length ??
        0;

    final totalChoreCount = choresDue + choresOverdue;

    final summary = finance.valueOrNull;
    final balance = summary != null
        ? summary.balances.fold<int>(
            0, (sum, b) => sum + b.total)
        : 0;

    final listCount = lists.valueOrNull
            ?.where((l) => l.type == 'shopping' || l.type == 'general')
            .length ??
        0;

    final pinnedWithReminders = pinwall.valueOrNull
            ?.where((p) => p.remindAt != null)
            .length ??
        0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.cleaning_services_outlined,
            label: 'Chores',
            value: totalChoreCount > 0 ? '$totalChoreCount' : '0',
            subtitle: choresOverdue > 0
                ? '$choresOverdue overdue'
                : (choresDue > 0 ? 'due today' : 'all done'),
            color: choresOverdue > 0
                ? Theme.of(context).colorScheme.error
                : (choresDue > 0
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.tertiary),
            onTap: () => context.pushNamed('chores'),
          ),
        ),
        SizedBox(width: MitlistSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: Icons.receipt_outlined,
            label: 'Balance',
            value: balance > 0
                ? '+\$${_fmt(balance)}'
                : (balance < 0
                    ? '-\$${_fmt(-balance)}'
                    : '\$${_fmt(balance)}'),
            subtitle: balance != 0 ? 'open' : 'settled',
            color: balance > 0
                ? Theme.of(context).colorScheme.tertiary
                : (balance < 0
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant),
            onTap: () => context.pushNamed('money'),
          ),
        ),
        SizedBox(width: MitlistSpacing.sm),
        Expanded(
          child: _StatCard(
            icon: Icons.shopping_cart_outlined,
            label: 'Lists',
            value: '$listCount',
            subtitle: listCount == 1
                ? 'active list'
                : 'active lists',
            color: listCount > 0
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.tertiary,
            onTap: () => context.pushNamed('lists'),
          ),
        ),
        if (pinnedWithReminders > 0) ...[
          SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: _StatCard(
              icon: Icons.alarm_outlined,
              label: 'Reminders',
              value: '$pinnedWithReminders',
              subtitle: pinnedWithReminders == 1
                  ? 'pinwall reminder'
                  : 'pinwall reminders',
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
        ],
      ],
    );
  }

  String _fmt(int cents) {
    return (cents / 100).toStringAsFixed(0);
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
    return AppCard(
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
            subtitle,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
