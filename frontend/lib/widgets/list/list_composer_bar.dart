import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/list_models.dart';
import '../../services/scan/grocery_suggestion_service.dart';
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
    this.productSuggestions = const [],
    this.grocerySuggestions = const [],
    this.showProductSuggestions = false,
    this.onGrocerySuggestionSelected,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onAdd;
  final VoidCallback onScan;
  final List<Product> productSuggestions;

  /// Offline, alias-powered suggestions from the canonical grocery seed,
  /// shown ahead of backend product history.
  final List<GrocerySuggestion> grocerySuggestions;
  final bool showProductSuggestions;

  /// Called when a grocery (seed) suggestion chip is tapped, before [onAdd],
  /// so the caller can capture the canonical link for the item about to be
  /// created. Product-history chips carry no canonical id and don't call this.
  final ValueChanged<GrocerySuggestion>? onGrocerySuggestionSelected;

  Widget _buildSuggestions(BuildContext context) {
    if (!showProductSuggestions) return const SizedBox.shrink();

    // Grocery (seed) suggestions lead; backend products fill in, deduped by
    // name so the same item never appears twice.
    final seen = <String>{};
    final chips = <Widget>[];
    void addChip(
      String name, {
      required bool fromSeed,
      GrocerySuggestion? suggestion,
    }) {
      final key = name.toLowerCase();
      if (name.isEmpty || !seen.add(key)) return;
      chips.add(AppChip(
        label: name,
        leading: fromSeed ? const AppIcon(name: 'bolt', size: 14) : null,
        onSelected: (_) {
          controller.text = name;
          if (suggestion != null) {
            onGrocerySuggestionSelected?.call(suggestion);
          }
          onAdd();
        },
      ));
    }

    for (final g in grocerySuggestions) {
      addChip(g.name, fromSeed: true, suggestion: g);
    }
    for (final p in productSuggestions) {
      addChip(p.name, fromSeed: false);
    }
    if (chips.isEmpty) return const SizedBox.shrink();

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
