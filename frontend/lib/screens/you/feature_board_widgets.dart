import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/feature_board_models.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/chip.dart';

/// Pieces shared by the board list and the request detail screen.

String featureBoardStatusLabel(
    AppLocalizations l10n, FeatureBoardStatus status) {
  return switch (status) {
    FeatureBoardStatus.underReview => l10n.featureBoardUnderReview,
    FeatureBoardStatus.inProgress => l10n.featureBoardInProgress,
    FeatureBoardStatus.shipped => l10n.featureBoardShipped,
  };
}

String featureBoardStatusHint(
    AppLocalizations l10n, FeatureBoardStatus status) {
  return switch (status) {
    FeatureBoardStatus.underReview => l10n.featureBoardStatusUnderReviewHint,
    FeatureBoardStatus.inProgress => l10n.featureBoardStatusInProgressHint,
    FeatureBoardStatus.shipped => l10n.featureBoardStatusShippedHint,
  };
}

/// "Just now", "3 hours ago", or a date once it is older than a month.
String featureBoardRelativeTime(
  AppLocalizations l10n,
  DateTime when, {
  DateTime? now,
}) {
  final delta = (now ?? DateTime.now()).difference(when);
  if (delta.inMinutes < 1) return l10n.featureBoardTimeJustNow;
  if (delta.inHours < 1) {
    return l10n.featureBoardTimeMinutesAgo(delta.inMinutes);
  }
  if (delta.inDays < 1) return l10n.featureBoardTimeHoursAgo(delta.inHours);
  if (delta.inDays < 30) return l10n.featureBoardTimeDaysAgo(delta.inDays);
  return DateFormat.yMMMd(l10n.localeName).format(when);
}

/// Status chip. In-progress is the one people are looking for, so it gets the
/// primary tint; shipped is quietly green; under review stays neutral.
class FeatureBoardStatusChip extends StatelessWidget {
  const FeatureBoardStatusChip({super.key, required this.status});

  final FeatureBoardStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      FeatureBoardStatus.underReview => (
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
        ),
      FeatureBoardStatus.inProgress => (
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
        ),
      FeatureBoardStatus.shipped => (
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
        ),
    };
    return _MetaChip(
      label: featureBoardStatusLabel(l10n, status),
      background: background,
      foreground: foreground,
      leading: status == FeatureBoardStatus.inProgress
          ? const AppIcon(name: 'bolt', size: 12)
          : status == FeatureBoardStatus.shipped
              ? const AppIcon(name: 'check', size: 12)
              : null,
    );
  }
}

/// Only bugs get a chip; a feature request is the default and needs no label.
class FeatureBoardKindChip extends StatelessWidget {
  const FeatureBoardKindChip({super.key, required this.kind});

  final FeatureBoardKind kind;

  @override
  Widget build(BuildContext context) {
    if (kind != FeatureBoardKind.bug) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return _MetaChip(
      label: l10n.featureBoardBugChip,
      background: colorScheme.errorContainer,
      foreground: colorScheme.onErrorContainer,
      leading: const AppIcon(name: 'bugReport', size: 12),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.background,
    required this.foreground,
    this.leading,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.space2,
        vertical: MitlistSpacing.space0_5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            const BorderRadius.all(Radius.circular(MitlistTheme.radiusSm)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            IconTheme(
              data: IconThemeData(color: foreground, size: 12),
              child: leading!,
            ),
            const SizedBox(width: MitlistSpacing.space1),
          ],
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Vertical vote pill: chevron on top, count underneath. Filled once the
/// reader has voted; tapping it again takes the vote back.
class FeatureBoardVoteButton extends StatelessWidget {
  const FeatureBoardVoteButton({
    super.key,
    required this.voteCount,
    required this.hasVoted,
    required this.isVoting,
    required this.onPressed,
  });

  final int voteCount;
  final bool hasVoted;
  final bool isVoting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = !isVoting;
    final background = hasVoted ? colorScheme.primary : colorScheme.surface;
    final foreground = hasVoted ? colorScheme.onPrimary : colorScheme.onSurface;

    return Semantics(
      button: enabled,
      label:
          hasVoted ? l10n.featureBoardRemoveUpvote : l10n.featureBoardUpvote,
      value: l10n.featureBoardVotes(voteCount),
      child: Material(
        color: background,
        borderRadius:
            const BorderRadius.all(Radius.circular(MitlistTheme.radiusMd)),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius:
              const BorderRadius.all(Radius.circular(MitlistTheme.radiusMd)),
          child: Container(
            width: MitlistSpacing.space12,
            padding: const EdgeInsets.symmetric(
              vertical: MitlistSpacing.space2,
            ),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(
                  Radius.circular(MitlistTheme.radiusMd)),
              border: Border.all(
                color: hasVoted ? colorScheme.primary : colorScheme.outline,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isVoting)
                  SizedBox(
                    width: MitlistSpacing.space4,
                    height: MitlistSpacing.space4,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                else
                  AppIcon(
                    name: hasVoted ? 'check' : 'chevronUp',
                    size: MitlistSpacing.space4,
                    color: foreground,
                  ),
                const SizedBox(height: MitlistSpacing.space0_5),
                Text(
                  '$voteCount',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Feature/bug picker used by both create forms.
class FeatureBoardKindSelector extends StatelessWidget {
  const FeatureBoardKindSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final FeatureBoardKind value;
  final ValueChanged<FeatureBoardKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.featureBoardKindLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: MitlistSpacing.space2),
        Wrap(
          spacing: MitlistSpacing.space2,
          runSpacing: MitlistSpacing.space2,
          children: [
            AppChip(
              label: l10n.featureBoardKindFeature,
              leading: const AppIcon(name: 'lightbulb'),
              selected: value == FeatureBoardKind.feature,
              onSelected: (_) => onChanged(FeatureBoardKind.feature),
            ),
            AppChip(
              label: l10n.featureBoardKindBug,
              leading: const AppIcon(name: 'bugReport'),
              selected: value == FeatureBoardKind.bug,
              onSelected: (_) => onChanged(FeatureBoardKind.bug),
            ),
          ],
        ),
      ],
    );
  }
}
