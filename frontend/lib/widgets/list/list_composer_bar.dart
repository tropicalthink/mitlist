import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/scan/household_suggestion_engine.dart';
import '../../theme/animations.dart';
import '../../theme/spacing.dart';
import '../app_button.dart';
import '../app_icon.dart';
import '../chip.dart';

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

    final chips = suggestions
        .map((suggestion) => AppChip(
              label: suggestion.name,
              leading: suggestion.hasIntelligence
                  ? const AppIcon(name: 'bolt', size: 14)
                  : null,
              onSelected: (_) {
                controller.text = suggestion.name;
                onSuggestionSelected?.call(suggestion);
                onAdd();
              },
            ))
        .toList(growable: false);

    // Reserve this slot at a fixed height for the whole time the composer is
    // focused, whether or not chips have arrived yet — suggestions land in two
    // independent async waves (fast local grocery/restock, then a slower
    // network product-history fetch) that each rebuild this row, so sizing to
    // `chips.isEmpty` made the bar visibly resize per wave/keystroke instead of
    // settling once on focus.
    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: chips.length,
          separatorBuilder: (_, __) => const SizedBox(width: MitlistSpacing.sm),
          itemBuilder: (context, index) => chips[index],
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
