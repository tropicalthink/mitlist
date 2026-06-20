import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/grocery_provider.dart';
import '../../services/restock_service.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../app_icon.dart';

/// A horizontal strip shown above the list items when the household has
/// groceries it is due to rebuy (inferred from on-device purchase cadence).
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
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.md,
        vertical: MitlistSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AppIcon(
                name: 'shoppingCart',
                size: 13,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: MitlistSpacing.xs),
              Text(
                l10n.runningLowHeading,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: MitlistSpacing.xs),
          SizedBox(
            height: 44,
            child: ListView.separated(
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MitlistSpacing.sm,
          vertical: MitlistSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius:
              const BorderRadius.all(Radius.circular(MitlistTheme.radiusMd)),
          border: Border.fromBorderSide(
            BorderSide(color: colorScheme.outline, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  suggestion.name,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: MitlistSpacing.xs),
                AppIcon(
                  name: 'plus',
                  size: 12,
                  color: colorScheme.primary,
                ),
              ],
            ),
            Text(
              l10n.runningLowDaysAgo(suggestion.daysSince),
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
