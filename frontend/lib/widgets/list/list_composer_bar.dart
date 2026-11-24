import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/scan/household_suggestion_engine.dart';
import '../../theme/spacing.dart';
import '../app_icon.dart';
import 'list_suggestion_line.dart';

/// The list's last line, where new items are written: a "+" where the
/// checkbox would be and the words after it, like the next line of a note's
/// checklist. Return adds the item and keeps the keyboard up for the next.
/// "2 avocados" and "500 g flour" are read as amounts.
class ListAddLine extends StatelessWidget {
  const ListAddLine({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onAdd,
    this.onScan,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onAdd;

  /// Read a written or printed list from a photo; null hides the camera.
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: MitlistSpacing.space11,
            height: MitlistSpacing.space11,
            child: Center(
              child: AppIcon(
                name: 'plus',
                size: 22,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              key: const ValueKey('list-add-line'),
              controller: controller,
              focusNode: focusNode,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.3),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              // Return adds; the field stays focused for the next item.
              onSubmitted: (_) => onAdd(),
              onEditingComplete: () {},
              decoration: InputDecoration(
                hintText: l10n.composerAddItem,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: MitlistSpacing.sm + 2,
                ),
              ),
            ),
          ),
          if (onScan != null)
            IconButton(
              key: const ValueKey('list-add-scan'),
              icon: AppIcon(name: 'camera', color: scheme.onSurfaceVariant),
              tooltip: l10n.composerScanList,
              onPressed: onScan,
            ),
        ],
      ),
    );
  }
}

/// What matches the words being typed, as up to [maxLines] faint lines
/// right under the add line. Tapping one adds it, linked to the item it
/// names. A match already on the list says so, because tapping it brings a
/// checked-off row back (or leaves an open one alone) instead of adding.
class ListComposerSuggestions extends StatelessWidget {
  const ListComposerSuggestions({
    super.key,
    required this.controller,
    required this.onAdd,
    this.suggestions = const [],
    this.onSuggestionSelected,
    this.maxLines = 4,
  });

  final TextEditingController controller;
  final VoidCallback onAdd;
  final List<HouseholdSuggestion> suggestions;
  final int maxLines;

  /// A suggestion was tapped; [typedQuery] is the text it replaced.
  final void Function(HouseholdSuggestion suggestion, String typedQuery)?
      onSuggestionSelected;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final suggestion in suggestions.take(maxLines))
          ListSuggestionLine(
            key: ValueKey(
                'suggestion-${suggestion.canonicalItemId ?? suggestion.name}'),
            name: suggestion.name,
            icon: !suggestion.isOnList
                ? 'plus'
                : suggestion.onListChecked
                    ? 'removeDoneOutline'
                    : 'check',
            detail: suggestion.isOnList
                ? (suggestion.onListChecked
                    ? l10n.composerSuggestionCheckedOff
                    : l10n.composerSuggestionOnList)
                : suggestion.category.isNotEmpty
                    ? suggestion.category
                    : null,
            onTap: () {
              // What was typed ("nutella") is gone once the field takes the
              // suggestion's name, so it travels with the pick.
              final typed = controller.text;
              controller.text = suggestion.name;
              onSuggestionSelected?.call(suggestion, typed);
              onAdd();
            },
          ),
      ],
    );
  }
}
