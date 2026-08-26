import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/weekly_summary_models.dart';
import '../../providers/weekly_summary_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/odometer.dart';
import '../../widgets/skeleton.dart';

/// The household's week in review, opened from the weekly digest notification.
///
/// Deliberately a root-level route rather than a tab: it is reached from the
/// notification inbox, which also sits outside the shell. Pushing a
/// shell-branch route from there re-instantiates the shell and duplicates the
/// branch navigator GlobalKeys — see `utils/notification_navigation.dart`.
class WeeklySummaryScreen extends ConsumerWidget {
  const WeeklySummaryScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final summary = ref.watch(weeklySummaryProvider(groupId));

    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.weeklySummaryTitle,
        showStandardActions: false,
      ),
      body: RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: () async {
          ref.invalidate(weeklySummaryProvider(groupId));
          try {
            await ref.read(weeklySummaryProvider(groupId).future);
          } catch (_) {
            // A failed refresh already lands in summary.when(error:); letting
            // it escape here would be an unhandled async exception.
          }
        },
        child: summary.when(
          loading: () => const _WeeklySummarySkeleton(),
          error: (_, __) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(MitlistSpacing.md),
            children: [
              const SizedBox(height: MitlistSpacing.xl),
              AppEmptyState(
                icon: const AppIcon(name: 'alertCircleOutline'),
                title: l10n.weeklySummaryLoadFailed,
                description: l10n.weeklySummaryTryAgain,
                isError: true,
                actions: [
                  AppButton(
                    text: l10n.commonRetry,
                    onPressed: () =>
                        ref.invalidate(weeklySummaryProvider(groupId)),
                  ),
                ],
              ),
            ],
          ),
          data: (data) => _WeeklySummaryBody(summary: data),
        ),
      ),
    );
  }
}

class _WeeklySummaryBody extends StatelessWidget {
  const _WeeklySummaryBody({required this.summary});

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (summary.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(MitlistSpacing.md),
        children: [
          const SizedBox(height: MitlistSpacing.xl),
          AppEmptyState(
            icon: const AppIcon(name: 'chartBar'),
            title: l10n.weeklySummaryEmptyTitle,
            description: l10n.weeklySummaryEmptyBody,
            actions: [
              AppButton(
                text: l10n.weeklySummaryOpenHousehold,
                icon: const AppIcon(name: 'arrowRight'),
                // goNamed, not pushNamed: 'home' lives inside the stateful
                // shell and pushing it from this root-level route duplicates
                // the branch navigator keys.
                onPressed: () => context.goNamed('home'),
              ),
            ],
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MitlistSpacing.md),
      children: [
        _HeadlineCard(summary: summary),
        const SizedBox(height: MitlistSpacing.md),
        _YourShareCard(summary: summary),
        const SizedBox(height: MitlistSpacing.md),
        _BreakdownCard(summary: summary),
        const SizedBox(height: MitlistSpacing.md),
        _NudgeCard(summary: summary),
        const SizedBox(height: MitlistSpacing.xl),
      ],
    );
  }
}

/// The hero: one big number, the week-over-week delta, and a seven-day bar
/// chart. Everything else on the screen explains this card.
class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.summary});

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateRange = DateFormat.MMMd(locale);

    return AppCard(
      variant: AppCardVariant.filled,
      tint: AppCardTint.primary,
      padding: AppCardPadding.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${dateRange.format(summary.periodStart)} – '
            '${dateRange.format(summary.periodEnd)}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MitlistOdometer(
                value: summary.total,
                textStyle: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ) ??
                    const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: MitlistSpacing.xs),
                child: Text(
                  l10n.weeklySummaryActivities(summary.total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MitlistSpacing.sm),
          _DeltaChip(
            delta: summary.delta,
            percent: summary.deltaPercent,
            emphasize: true,
          ),
          const SizedBox(height: MitlistSpacing.lg),
          _Sparkline(days: summary.days, peak: summary.peakDay),
        ],
      ),
    );
  }
}

/// Seven rounded bars, one per day, scaled against the busiest day.
///
/// A zero day still renders a visible stub so the week reads as seven days
/// rather than as a chart with holes in it.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.days, required this.peak});

  final List<WeeklyDayCount> days;
  final int peak;

  static const double _maxBarHeight = 72;
  static const double _minBarHeight = 4;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final weekday = DateFormat.E(locale);
    final today = DateTime.now();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in days)
          Expanded(
            child: Semantics(
              label: '${weekday.format(day.date)}: ${day.count}',
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: MitlistSpacing.space0_5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${day.count}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: day.count == 0
                            ? theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5)
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight:
                            day.count == peak ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: MitlistSpacing.xs),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      height: _barHeight(day.count),
                      decoration: BoxDecoration(
                        color: _barColor(context, day),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: MitlistSpacing.xs),
                    Text(
                      _isSameDay(day.date, today)
                          ? weekday.format(day.date).toUpperCase()
                          : weekday.format(day.date),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: _isSameDay(day.date, today)
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  double _barHeight(int count) {
    if (count <= 0) return _minBarHeight;
    return _minBarHeight + (_maxBarHeight - _minBarHeight) * (count / peak);
  }

  Color _barColor(BuildContext context, WeeklyDayCount day) {
    final scheme = Theme.of(context).colorScheme;
    if (day.count == 0) {
      return scheme.onSurfaceVariant.withValues(alpha: 0.15);
    }
    // The busiest day is the one worth noticing, so only it gets full primary.
    if (day.count == peak) return scheme.primary;
    return scheme.primary.withValues(alpha: 0.45);
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// "You contributed N of M" — the personal half of the story.
class _YourShareCard extends StatelessWidget {
  const _YourShareCard({required this.summary});

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final percent = (summary.mineShare * 100).round();

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(name: 'userCircle', color: theme.colorScheme.primary),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: Text(
                  l10n.weeklySummaryYourShareTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                '$percent%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Text(
            l10n.weeklySummaryYourShareBody(summary.mine, summary.total),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: MitlistSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: summary.mineShare.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor:
                  theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Text(
            _personalLine(l10n),
            style: theme.textTheme.bodySmall?.copyWith(
              color: summary.personalImprovement
                  ? MitlistColors.success600
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight:
                  summary.personalImprovement ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (summary.memberCount > 1) ...[
            const SizedBox(height: MitlistSpacing.sm),
            Row(
              children: [
                AppIcon(
                  name: 'userGroup',
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: MitlistSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.weeklySummaryActiveMembers(
                        summary.activeMembers, summary.memberCount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _personalLine(AppLocalizations l10n) {
    final diff = summary.mine - summary.minePrevious;
    if (diff > 0) return l10n.weeklySummaryPersonalUp(diff);
    if (diff < 0) return l10n.weeklySummaryPersonalDown(-diff);
    return l10n.weeklySummaryPersonalSame;
  }
}

/// Per-category counts with their week-over-week deltas.
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.summary});

  final WeeklySummary summary;

  /// Category key → icon. Keys are the server's stable API values; an unknown
  /// key (a category added server-side before this client ships) falls back to
  /// a neutral icon rather than throwing.
  static const Map<String, String> _icons = {
    'lists': 'shoppingCartOutline',
    'expenses': 'banknotes',
    'chores': 'cleaningServices',
    'meals': 'restaurantOutline',
    'recipes': 'restaurantMenu',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.weeklySummaryBreakdownTitle,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: MitlistSpacing.md),
          for (final category in summary.categories) ...[
            _CategoryRow(
              icon: _icons[category.category] ?? 'listBullet',
              label: _label(l10n, category.category),
              category: category,
              peak: _peakCategoryCount,
            ),
            if (category != summary.categories.last)
              const SizedBox(height: MitlistSpacing.sm),
          ],
        ],
      ),
    );
  }

  /// The largest single category, used to scale the inline bars. Never zero:
  /// this card only renders when the household had activity.
  int get _peakCategoryCount => summary.categories
      .fold<int>(1, (max, c) => c.count > max ? c.count : max);

  String _label(AppLocalizations l10n, String key) {
    switch (key) {
      case 'lists':
        return l10n.weeklySummaryCategoryLists;
      case 'expenses':
        return l10n.weeklySummaryCategoryExpenses;
      case 'chores':
        return l10n.weeklySummaryCategoryChores;
      case 'meals':
        return l10n.weeklySummaryCategoryMeals;
      case 'recipes':
        return l10n.weeklySummaryCategoryRecipes;
      default:
        return key;
    }
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.icon,
    required this.label,
    required this.category,
    required this.peak,
  });

  final String icon;
  final String label;
  final WeeklyCategoryCount category;
  final int peak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quiet = category.count == 0;

    return Opacity(
      opacity: quiet ? 0.55 : 1,
      child: Row(
        children: [
          AppIcon(
            name: icon,
            size: 20,
            color: quiet
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyMedium),
                const SizedBox(height: MitlistSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (category.count / peak).clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.10),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: MitlistSpacing.sm),
          Text(
            '${category.count}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: MitlistSpacing.sm),
          SizedBox(
            width: 56,
            child: Align(
              alignment: Alignment.centerRight,
              child: _DeltaChip(delta: category.delta, percent: null),
            ),
          ),
        ],
      ),
    );
  }
}

/// A "▲ +6" / "▼ -2" / "—" pill. [percent] is shown instead of the raw delta
/// when supplied, which is how the headline reads week-over-week.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({
    required this.delta,
    required this.percent,
    this.emphasize = false,
  });

  final int delta;
  final int? percent;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final up = delta > 0;
    final flat = delta == 0;
    final color = flat
        ? theme.colorScheme.onSurfaceVariant
        : (up ? MitlistColors.success600 : MitlistColors.warning700);

    final String text;
    if (emphasize) {
      if (percent == null) {
        // No previous week to compare against — a percentage here would read as
        // "up 100%" from nothing, which is noise, not a signal.
        text = l10n.weeklySummaryFirstWeek;
      } else if (flat) {
        text = l10n.weeklySummarySameAsLastWeek;
      } else {
        text = l10n.weeklySummaryPercentVsLastWeek(percent!.abs());
      }
    } else {
      text = flat ? '—' : '${up ? '+' : '−'}${delta.abs()}';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: emphasize ? MitlistSpacing.sm : MitlistSpacing.xs,
        vertical: emphasize ? MitlistSpacing.xs : 0,
      ),
      decoration: emphasize
          ? BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!flat) ...[
            Icon(
              up ? Icons.arrow_upward : Icons.arrow_downward,
              size: emphasize ? 14 : 12,
              color: color,
            ),
            const SizedBox(width: MitlistSpacing.xs),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (emphasize
                      ? theme.textTheme.labelLarge
                      : theme.textTheme.labelSmall)
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// The closing nudge. Which of the three it shows depends on what the numbers
/// actually say — a household that slipped should not be congratulated, and
/// someone who contributed nothing should be invited in rather than ranked.
class _NudgeCard extends StatelessWidget {
  const _NudgeCard({required this.summary});

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final (title, body, icon) = _nudge(l10n);

    return AppCard(
      variant: AppCardVariant.filled,
      padding: AppCardPadding.md,
      backgroundColor: theme.brightness == Brightness.light
          ? MitlistColors.noteMint
          : MitlistColors.noteMintDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                name: icon,
                color: theme.brightness == Brightness.light
                    ? MitlistColors.noteMintDark
                    : MitlistColors.noteMint,
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.brightness == Brightness.light
                        ? MitlistColors.noteMintDark
                        : MitlistColors.noteMint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.brightness == Brightness.light
                  ? MitlistColors.noteMintDark
                  : MitlistColors.noteMint,
            ),
          ),
          const SizedBox(height: MitlistSpacing.md),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              text: l10n.weeklySummaryOpenHousehold,
              variant: AppButtonVariant.solid,
              color: AppButtonColor.primary,
              icon: const AppIcon(name: 'arrowRight'),
              // goNamed: 'home' is a shell-branch route and cannot be pushed
              // from here without duplicating the branch navigator keys.
              onPressed: () => context.goNamed('home'),
            ),
          ),
        ],
      ),
    );
  }

  (String, String, String) _nudge(AppLocalizations l10n) {
    if (summary.mine == 0) {
      return (
        l10n.weeklySummaryNudgeJoinTitle,
        l10n.weeklySummaryNudgeJoinBody,
        'userPlus',
      );
    }
    if (summary.delta > 0) {
      return (
        l10n.weeklySummaryNudgeRollTitle,
        l10n.weeklySummaryNudgeRollBody(summary.total),
        'bolt',
      );
    }
    return (
      l10n.weeklySummaryNudgeSlipTitle,
      l10n.weeklySummaryNudgeSlipBody,
      'arrowPath',
    );
  }
}

class _WeeklySummarySkeleton extends StatelessWidget {
  const _WeeklySummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MitlistSpacing.md),
      children: const [
        AppSkeleton(
            width: double.infinity,
            height: 220,
            borderRadius: AppSkeletonRadius.sm),
        SizedBox(height: MitlistSpacing.md),
        AppSkeleton(
            width: double.infinity,
            height: 150,
            borderRadius: AppSkeletonRadius.sm),
        SizedBox(height: MitlistSpacing.md),
        AppSkeleton(
            width: double.infinity,
            height: 220,
            borderRadius: AppSkeletonRadius.sm),
      ],
    );
  }
}
