import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/chore_models.dart';
import '../../models/list_models.dart';
import '../../providers/chore_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../screens/money/expense_format.dart';
import '../../theme/spacing.dart';
import '../../utils/haptics.dart';
import '../../utils/home_summary.dart';

/// Which chrome a [PinwallStatRow] renders in:
///  - [tile]: one of the count tiles under Home's "Needs you" card — icon
///    and label, the value large, the accent caption under it.
///  - [indexCard]: the board's manila index-card line — icon, label + accent
///    subtitle stacked, bold value on the right, ruled bottom border.
enum PinwallStatRowStyle { tile, indexCard }

/// The shared presentation for a single household stat. The two surfaces
/// (Home's tiles, the board's index card) look different, so this only
/// unifies the *chrome*; the domain-specific value computation lives in the
/// `Pinwall*StatRow` widgets below (through `utils/home_summary.dart`) so it
/// isn't duplicated between screens.
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
                            style:
                                textTheme.labelSmall?.copyWith(color: accent),
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
      button: onTap != null,
      label: [label, value, if (subtitle != null) subtitle].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap == null ? null : handleTap,
        child: Padding(
          padding: const EdgeInsets.all(MitlistSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: accent),
                  const SizedBox(width: MitlistSpacing.xs),
                  Expanded(
                    child: Text(
                      label,
                      style: textTheme.labelSmall?.copyWith(color: muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MitlistSpacing.xs),
              // A long amount ("CHF 1,234.50") shrinks rather than clipping
              // in a third of a phone's width.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: textTheme.titleLarge?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: textTheme.labelSmall?.copyWith(color: accent),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The caller's chores due today + overdue. Chores on someone else's turn
/// are not counted: this answers "what is on me".
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
    final mine = choresOnMe(
      chores.valueOrNull ?? const <CurrentChore>[],
      DateTime.now(),
    );
    final overdue = mine.overdue.length;
    final due = mine.dueToday.length;

    final theme = Theme.of(context).colorScheme;
    final accent = overdue > 0
        ? theme.error
        : (due > 0 ? theme.secondary : theme.tertiary);

    return PinwallStatRow(
      style: style,
      icon: Icons.cleaning_services_outlined,
      label: l10n.hubStatsChores,
      value: '${overdue + due}',
      subtitle: overdue > 0
          ? l10n.hubStatsOverdueCount(overdue)
          : (due > 0 ? l10n.hubStatsDue : l10n.hubStatsNothingOnYou),
      accent: accent,
      ink: ink,
      muted: muted,
      rule: rule,
      onTap: () => context.goNamed('chores'),
    );
  }
}

/// The caller's net position in the household currency.
class PinwallFinanceStatRow extends ConsumerWidget {
  const PinwallFinanceStatRow({
    super.key,
    required this.groupId,
    required this.currentUserId,
    required this.style,
    required this.ink,
    required this.muted,
    this.rule,
  });

  final String groupId;
  final String? currentUserId;
  final PinwallStatRowStyle style;
  final Color ink;
  final Color muted;
  final Color? rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final summary =
        ref.watch(cachedFinanceSummaryByGroupProvider(groupId)).valueOrNull;
    final currency = ref
            .watch(cachedGroupsProvider)
            .valueOrNull
            ?.firstWhereOrNull((g) => g.id == groupId)
            ?.currency ??
        'USD';
    final balance = myBalance(summary, currentUserId);
    final cents = balance.cents;

    final theme = Theme.of(context).colorScheme;
    // The board's index card falls back to its ink-derived `muted` for a
    // settled balance instead of Home's `onSurfaceVariant` — preserved as-is
    // from the two original implementations.
    final settledAccent =
        style == PinwallStatRowStyle.indexCard ? muted : theme.onSurfaceVariant;

    return PinwallStatRow(
      style: style,
      icon: Icons.receipt_outlined,
      label: l10n.hubStatsBalance,
      value: formatExpenseCurrency(cents.abs() / 100, currency: currency),
      subtitle: cents < 0
          ? l10n.hubBalanceYouOweLabel
          : cents > 0
              ? l10n.hubBalanceOwedToYouLabel
              : (balance.hasExpenses
                  ? l10n.hubBalanceSettledUp
                  : l10n.hubBalanceNoExpenses),
      accent: cents > 0
          ? theme.tertiary
          : (cents < 0 ? theme.error : settledAccent),
      ink: ink,
      muted: muted,
      rule: rule,
      onTap: () => context.goNamed('money'),
    );
  }
}

/// Unchecked items across the household's active lists. Counts come from
/// the local item cache (the same source as the Lists tab's "N left"); Home
/// fetches the items of lists this device has not synced yet
/// (`ListRepository.fetchUnsyncedItems`) so the total is not limited to
/// their preview lines.
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
    final items = openListItems(
      ref.watch(cachedListsByGroupProvider(groupId)).valueOrNull ??
          const <ItemList>[],
      ref.watch(listItemCountsProvider(groupId)).valueOrNull ?? const {},
    );

    final theme = Theme.of(context).colorScheme;
    return PinwallStatRow(
      style: style,
      icon: Icons.shopping_cart_outlined,
      label: l10n.hubStatsLists,
      value: '${items.open}',
      // Ticked-off lists read "All done"; lists with nothing on them say so.
      subtitle: items.open > 0
          ? l10n.hubStatsItemsLeftLabel(items.open)
          : (items.total > 0 ? l10n.listOpenCount(0) : l10n.hubStatsListsEmpty),
      accent: items.open > 0 ? theme.primary : theme.tertiary,
      ink: ink,
      muted: muted,
      rule: rule,
      onTap: () => context.goNamed('lists'),
    );
  }
}
