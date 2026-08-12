import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/grocery_provider.dart';
import '../../services/restock_service.dart';
import '../../theme/list_tile_accent.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../app_card.dart';
import '../app_icon.dart';

/// A horizontal shelf shown above shopping-list items when the household prior
/// has useful additions. Each card explains whether it is due, familiar, or
/// associated with the current list instead of presenting every signal as
/// "running low".
///
/// Renders [SizedBox.shrink] while loading, on error, or when there are no
/// suggestions after filtering out [currentItemNames] — never shows spinners
/// or error UI so it never clutters the list view.
class RunningLowStrip extends ConsumerWidget {
  const RunningLowStrip({
    super.key,
    required this.groupId,
    required this.currentItemNames,
    required this.onAdd,
  });

  /// The household group whose purchase history the predictor reads.
  final String groupId;

  /// Lowercased names of items already on the open list. Matching suggestions
  /// are filtered out client-side so the strip never re-proposes things the
  /// user already added.
  final Set<String> currentItemNames;

  /// Called when the user taps a chip. The screen is responsible for writing
  /// the item to the list via the existing offline-first write path.
  final void Function(RestockSuggestion suggestion) onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(runningLowProvider(groupId));

    // While loading or on error: invisible, no spinner, no error UI.
    return asyncValue.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (suggestions) {
        final filtered = suggestions
            .where((s) => !currentItemNames.contains(s.name.toLowerCase()))
            .toList();
        if (filtered.isEmpty) return const SizedBox.shrink();

        return _RunningLowStripContent(
          suggestions: filtered,
          onAdd: onAdd,
        );
      },
    );
  }
}

class _RunningLowStripContent extends StatelessWidget {
  const _RunningLowStripContent({
    required this.suggestions,
    required this.onAdd,
  });

  final List<RestockSuggestion> suggestions;
  final void Function(RestockSuggestion suggestion) onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline,
            width: 2,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        MitlistSpacing.md,
        MitlistSpacing.md,
        MitlistSpacing.md,
        MitlistSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: MitlistSpacing.space8,
                height: MitlistSpacing.space8,
                color: colorScheme.primary,
                child: Center(
                  child: AppIcon(
                    name: 'bolt',
                    size: MitlistSpacing.space4,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: Text(
                  l10n.scanReviewYouMightNeed,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${suggestions.length}',
                style: MitlistTypography.monoBody(
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: MitlistSpacing.sm),
          SizedBox(
            height: MitlistSpacing.space20 + MitlistSpacing.sm,
            child: ListView.separated(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: MitlistSpacing.sm),
              itemBuilder: (context, index) {
                final s = suggestions[index];
                return _RestockChip(
                  suggestion: s,
                  onTap: () => onAdd(s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RestockChip extends StatelessWidget {
  const _RestockChip({
    required this.suggestion,
    required this.onTap,
  });

  final RestockSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final accent = ListTileAccent.fromSeed(
      suggestion.canonicalItemId,
      Theme.of(context).brightness,
    );
    final reason = switch (suggestion.reason) {
      RestockReason.due => (l10n.restockReasonDue, 'clockOutline'),
      RestockReason.usual => (l10n.restockReasonUsual, 'repeat'),
      RestockReason.goesWith => (l10n.restockReasonGoesWith, 'link'),
    };
    final daysAgo = l10n.runningLowDaysAgo(suggestion.daysSince);

    return SizedBox(
      width: MitlistSpacing.space20 * 2,
      child: AppCard(
        interactive: true,
        animated: true,
        padding: AppCardPadding.sm,
        backgroundColor: accent.tileBackground,
        semanticLabel: '${suggestion.name}. ${reason.$1}. $daysAgo',
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AppIcon(
                  name: reason.$2,
                  size: MitlistSpacing.space4,
                  color: accent.iconColor,
                ),
                const SizedBox(width: MitlistSpacing.xs),
                Expanded(
                  child: Text(
                    reason.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: accent.snippetOnTile,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              suggestion.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium?.copyWith(
                color: accent.titleColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    daysAgo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: accent.snippetOnTile,
                    ),
                  ),
                ),
                AppIcon(
                  name: 'plus',
                  size: MitlistSpacing.space4,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
