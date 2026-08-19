import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/scan/household_suggestion_engine.dart';
import '../../theme/animations.dart';
import '../../theme/list_tile_accent.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../app_button.dart';
import '../app_card.dart';
import '../app_icon.dart';

class ListComposerBar extends StatelessWidget {
  const ListComposerBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onAdd,
    required this.onScan,
    this.suggestions = const [],
    this.showProductSuggestions = false,
    this.onSuggestionSelected,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onAdd;
  final VoidCallback onScan;
  final List<HouseholdSuggestion> suggestions;
  final bool showProductSuggestions;
  final ValueChanged<HouseholdSuggestion>? onSuggestionSelected;

  Widget _buildSuggestions(BuildContext context) {
    if (!showProductSuggestions) return const SizedBox.shrink();

    final brightness = Theme.of(context).brightness;
    final cards = suggestions
        .map((suggestion) => _ComposerSuggestionCard(
              suggestion: suggestion,
              accent: ListTileAccent.fromSeed(
                suggestion.canonicalItemId ?? suggestion.name,
                brightness,
              ),
              onTap: () {
                controller.text = suggestion.name;
                onSuggestionSelected?.call(suggestion);
                onAdd();
              },
            ))
        .toList(growable: false);

    // Reserve this slot at a fixed height for the whole time the composer is
    // focused, whether or not cards have arrived yet — suggestions land in two
    // independent async waves (fast local grocery/restock, then a slower
    // network product-history fetch) that each rebuild this row, so sizing to
    // checking `suggestions.isEmpty` made the bar resize per wave/keystroke
    // settling once on focus.
    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
      child: SizedBox(
        height: MitlistSpacing.space16,
        child: ListView.separated(
          clipBehavior: Clip.none,
          scrollDirection: Axis.horizontal,
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: MitlistSpacing.sm),
          itemBuilder: (context, index) => cards[index],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    // Bar sits on the base surface; the input uses an elevated surface token
    // so its background contrasts with the (onSurface) text in both themes.
    final barColor = colorScheme.surface;
    final fieldFill = colorScheme.surfaceContainerHighest;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: barColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outline,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          MitlistSpacing.md,
          MitlistSpacing.sm,
          MitlistSpacing.md,
          MitlistSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: MitlistAnimations.micro,
              curve: MitlistAnimations.easeEnter,
              child: _buildSuggestions(context),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onAdd(),
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.composerNewItem,
                      hintText: l10n.composerItemHint,
                      filled: true,
                      fillColor: fieldFill,
                    ),
                  ),
                ),
                const SizedBox(width: MitlistSpacing.sm),
                AppButton(
                  icon: AppIcon(
                    name: 'camera',
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  variant: AppButtonVariant.outline,
                  onPressed: onScan,
                  size: AppButtonSize.lg,
                  tooltip: l10n.composerScanList,
                ),
                const SizedBox(width: MitlistSpacing.sm),
                AppButton(
                  icon: AppIcon(
                    name: 'plus',
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: onAdd,
                  size: AppButtonSize.lg,
                  tooltip: l10n.composerAddItem,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerSuggestionCard extends StatelessWidget {
  const _ComposerSuggestionCard({
    required this.suggestion,
    required this.accent,
    required this.onTap,
  });

  final HouseholdSuggestion suggestion;
  final ListTileAccent accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail =
        suggestion.category.isNotEmpty ? suggestion.category : suggestion.unit;
    return SizedBox(
      width: MitlistSpacing.space20 * 2,
      height: MitlistSpacing.space14,
      child: AppCard(
        interactive: true,
        padding: AppCardPadding.sm,
        backgroundColor: accent.tileBackground,
        semanticLabel: suggestion.name,
        onTap: onTap,
        child: Row(
          children: [
            AppIcon(
              name: suggestion.hasIntelligence ? 'bolt' : 'inventoryOutline',
              size: MitlistSpacing.space5,
              color: accent.iconColor,
            ),
            const SizedBox(width: MitlistSpacing.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: accent.titleColor,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                  ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MitlistTypography.labelXSmall(
                        color: accent.snippetOnTile,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: MitlistSpacing.xs),
            AppIcon(
              name: 'plus',
              size: MitlistSpacing.space4,
              color: accent.iconColor,
            ),
          ],
        ),
      ),
    );
  }
}
