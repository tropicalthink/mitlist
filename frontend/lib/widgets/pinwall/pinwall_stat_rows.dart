import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/chore_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/list_provider.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../utils/haptics.dart';

/// Which chrome a [PinwallStatRow] renders in:
///  - [inline]: the hub's collapsible snapshot row — icon, bold label, muted
///    value right-aligned, trailing chevron.
///  - [indexCard]: the board's manila index-card line — icon, label + accent
///    subtitle stacked, bold value on the right, ruled bottom border.
enum PinwallStatRowStyle { inline, indexCard }

/// The shared presentation for a single household stat line. The two
/// surfaces (hub snapshot, board index card) look different, so this only
/// unifies the row *chrome*; the domain-specific value computation lives in
/// the `Pinwall*StatRow` widgets below so it isn't duplicated between
/// screens.
class PinwallStatRow extends StatelessWidget {
  const PinwallStatRow({
    super.key,
    required this.style,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.ink,
    required this.muted,
    this.subtitle,
    this.rule,
    this.onTap,
  });

  final PinwallStatRowStyle style;
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color ink;
  final Color muted;
  final String? subtitle;
  final Color? rule;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    void handleTap() {
      unawaited(Haptics.light());
      onTap!();
    }

    if (style == PinwallStatRowStyle.indexCard) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: rule ?? Colors.transparent, width: 1),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap == null ? null : handleTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                64,
                MitlistSpacing.sm + 2,
                MitlistSpacing.md,
                MitlistSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(width: MitlistSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: textTheme.bodyMedium?.copyWith(
                            color: ink,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: textTheme.labelSmall?.copyWith(color: accent),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: MitlistSpacing.sm),
                  Text(
                    value,
                    style: textTheme.titleLarge?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: '$label: $value',
      child: InkWell(
        onTap: onTap == null ? null : handleTap,
        borderRadius: BorderRadius.circular(MitlistTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: MitlistSpacing.sm),
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  style: textTheme.labelMedium?.copyWith(color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: MitlistSpacing.xs),
              Icon(Icons.chevron_right, size: 18, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chores due-today + overdue, shared between the hub snapshot and the
/// board's index card so the counting logic isn't duplicated.
class PinwallChoresStatRow extends ConsumerWidget {
  const PinwallChoresStatRow({
    super.key,
    required this.groupId,
    required this.style,
    required this.ink,
    required this.muted,
    this.rule,
  });

  final String groupId;
  final PinwallStatRowStyle style;
  final Color ink;
  final Color muted;
  final Color? rule;

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
    final total = choresDue + choresOverdue;

    final theme = Theme.of(context).colorScheme;
    final accent = choresOverdue > 0
        ? theme.error
        : (choresDue > 0 ? theme.secondary : theme.tertiary);

    final String value;
    final String? subtitle;
    if (style == PinwallStatRowStyle.indexCard) {
      value = '$total';
      subtitle = choresOverdue > 0
          ? '$choresOverdue ${l10n.hubStatsOverdue}'
          : (choresDue > 0 ? l10n.hubStatsDue : l10n.hubStatsAllDone);
    } else {
      value = choresOverdue > 0
          ? '$choresOverdue ${l10n.hubStatsOverdue}'
          : (total > 0 ? '$total ${l10n.hubStatsDue}' : l10n.hubStatsAllDone);
      subtitle = null;
    }

    return PinwallStatRow(
      style: style,
      icon: Icons.cleaning_services_outlined,
      label: l10n.hubStatsChores,
      value: value,
      subtitle: subtitle,
      accent: accent,
      ink: ink,
      muted: muted,
      rule: rule,
      onTap: () => context.goNamed('chores'),
    );
  }
}

String _formatCents(int cents) => (cents / 100).toStringAsFixed(0);

/// Household balance, shared between the hub snapshot and the board's index
/// card.
class PinwallFinanceStatRow extends ConsumerWidget {
  const PinwallFinanceStatRow({
    super.key,
    required this.groupId,
    required this.style,
    required this.ink,
    required this.muted,
    this.rule,
  });

  final String groupId;
  final PinwallStatRowStyle style;
  final Color ink;
  final Color muted;
  final Color? rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final finance = ref.watch(cachedFinanceSummaryByGroupProvider(groupId));
    final summary = finance.valueOrNull;
    final balance = summary != null
        ? summary.balances.fold<int>(0, (sum, b) => sum + b.total)
        : 0;

    final theme = Theme.of(context).colorScheme;
    // The board's index card falls back to its ink-derived `muted` for a
    // settled balance instead of the hub's `onSurfaceVariant` — preserved
    // as-is from the two original implementations.
    final settledAccent =
        style == PinwallStatRowStyle.indexCard ? muted : theme.onSurfaceVariant;
    final accent =
        balance > 0 ? theme.tertiary : (balance < 0 ? theme.error : settledAccent);
    final amount = balance > 0
        ? '+\$${_formatCents(balance)}'
        : (balance < 0 ? '-\$${_formatCents(-balance)}' : '\$${_formatCents(balance)}');

    final String value;
    final String? subtitle;
    if (style == PinwallStatRowStyle.indexCard) {
      value = amount;
      subtitle = balance != 0 ? l10n.hubStatsOpen : l10n.expenseSettled;
    } else {
      value = '$amount · ${balance != 0 ? l10n.hubStatsOpen : l10n.expenseSettled}';
      subtitle = null;
    }

    return PinwallStatRow(
      style: style,
      icon: Icons.receipt_outlined,
      label: l10n.hubStatsBalance,
      value: value,
      subtitle: subtitle,
      accent: accent,
      ink: ink,
      muted: muted,
      rule: rule,
      onTap: () => context.goNamed('money'),
    );
  }
}

/// Active shopping/general list count, shared between the hub snapshot and
/// the board's index card.
class PinwallListsStatRow extends ConsumerWidget {
  const PinwallListsStatRow({
    super.key,
    required this.groupId,
    required this.style,
    required this.ink,
    required this.muted,
    this.rule,
  });

  final String groupId;
  final PinwallStatRowStyle style;
  final Color ink;
  final Color muted;
  final Color? rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final lists = ref.watch(cachedListsByGroupProvider(groupId));
    final listCount = lists.valueOrNull
            ?.where((l) => l.type == 'shopping' || l.type == 'general')
            .length ??
        0;

    final theme = Theme.of(context).colorScheme;
    final accent = listCount > 0 ? theme.primary : theme.tertiary;
    final countLabel =
        listCount == 1 ? l10n.hubStatsActiveList : l10n.hubStatsActiveLists;

    final String value;
    final String? subtitle;
    if (style == PinwallStatRowStyle.indexCard) {
      value = '$listCount';
      subtitle = countLabel;
    } else {
      value = '$listCount · $countLabel';
      subtitle = null;
    }

    return PinwallStatRow(
      style: style,
      icon: Icons.shopping_cart_outlined,
      label: l10n.hubStatsLists,
      value: value,
      subtitle: subtitle,
      accent: accent,
      ink: ink,
      muted: muted,
      rule: rule,
      onTap: () => context.goNamed('lists'),
    );
  }
}
