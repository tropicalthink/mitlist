import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/list_models.dart';
import '../../providers/outbox_provider.dart';
import '../../theme/spacing.dart';
import '../animated_check_toggle.dart';
import '../animated_strikethrough.dart';
import '../app_icon.dart';

/// One line of a list, written like a note's checklist (Apple Notes, Google
/// Keep): a checkbox and the words, nothing boxed around them.
///
/// - The checkbox ticks the item off.
/// - Tapping the words edits them in place; while a line is being edited it
///   shows its two tools, details (amount, note, price, photo) and remove.
/// - Long-pressing picks the line up to move it, when the list allows it.
///
/// Amount, note, price and who added it share one quiet line underneath.
class ListItemLine extends ConsumerWidget {
  const ListItemLine({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onEdit,
    this.editing = false,
    this.editController,
    this.editFocusNode,
    this.onSubmitEdit,
    this.onDetails,
    this.onRemove,
    this.photoUrl,
    this.onPhotoTap,
    this.currencySymbol = '\$',
    this.claimed = false,
    this.addedByName,
    this.reorderIndex,
    this.onMoveUp,
    this.onMoveDown,
  });

  final ListItem item;
  final ValueChanged<bool> onToggle;

  /// Tap on the words: start editing this line.
  final VoidCallback onEdit;

  final bool editing;
  final TextEditingController? editController;
  final FocusNode? editFocusNode;
  final VoidCallback? onSubmitEdit;
  final VoidCallback? onDetails;
  final VoidCallback? onRemove;

  final String? photoUrl;
  final VoidCallback? onPhotoTap;
  final String currencySymbol;
  final bool claimed;

  /// Who added the item, when it was someone other than the viewer.
  final String? addedByName;

  /// Index in the open items' reorderable list; null where lines don't move.
  final int? reorderIndex;

  /// Screen-reader stand-ins for dragging.
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  static String formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// "2 l · ripe ones · €3.00 · Sam": everything about the item but its name.
  String? details(AppLocalizations l10n) {
    final amount = item.quantity > 1 || item.unit.isNotEmpty
        ? (item.unit.isNotEmpty
            ? '${formatQuantity(item.quantity)} ${item.unit}'
            : '${formatQuantity(item.quantity)}×')
        : null;
    final price = item.priceCents != null && item.priceCents! > 0
        ? '$currencySymbol${(item.priceCents! / 100).toStringAsFixed(2)}'
        : null;
    final parts = [
      amount,
      if (item.note.isNotEmpty) item.note,
      price,
      if (claimed) l10n.listItemClaimed,
      if (addedByName != null && addedByName!.isNotEmpty)
        l10n.listItemAddedBy(addedByName!),
    ].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final failedToSync = ref.watch(failedEntityIdsProvider).contains(item.id);
    final nameStyle = theme.textTheme.bodyLarge?.copyWith(height: 1.3);
    final detailStyle = theme.textTheme.bodySmall?.copyWith(
      color: failedToSync ? scheme.error : scheme.onSurfaceVariant,
      height: 1.3,
    );
    final detailText = failedToSync ? l10n.listItemFailedSave : details(l10n);

    final Widget words;
    if (editing && editController != null) {
      words = TextField(
        key: ValueKey('item-line-edit-${item.id}'),
        controller: editController,
        focusNode: editFocusNode,
        style: nameStyle,
        minLines: 1,
        maxLines: 4,
        maxLength: 200,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          counterText: '',
          contentPadding: EdgeInsets.zero,
        ),
        onSubmitted: (_) => onSubmitEdit?.call(),
      );
    } else {
      words = AnimatedStrikethrough(
        text: item.name,
        struck: item.checked,
        style: nameStyle ?? const TextStyle(),
        color: item.checked ? scheme.onSurfaceVariant : scheme.onSurface,
      );
    }

    final line = Padding(
      padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedCheckToggle(
            value: item.checked,
            onChanged: onToggle,
            size: 22,
            semanticLabelOn: l10n.listItemMarkUnchecked(item.name),
            semanticLabelOff: l10n.listItemMarkChecked(item.name),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: MitlistSpacing.sm + 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  words,
                  if (detailText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        detailText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: detailStyle,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (photoUrl != null)
            Semantics(
              button: true,
              label: l10n.listItemViewPhotoFor(item.name),
              child: GestureDetector(
                onTap: onPhotoTap,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: ClipRect(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: Image.network(
                          photoUrl!,
                          fit: BoxFit.cover,
                          cacheWidth: (32 *
                                  MediaQuery.devicePixelRatioOf(context) *
                                  1.5)
                              .round(),
                          errorBuilder: (_, __, ___) => const AppIcon(
                            name: 'imageNotSupportedOutline',
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (editing) ...[
            IconButton(
              key: ValueKey('item-line-details-${item.id}'),
              icon: AppIcon(name: 'tune', color: scheme.onSurfaceVariant),
              tooltip: l10n.listItemDetails,
              onPressed: onDetails,
            ),
            IconButton(
              key: ValueKey('item-line-remove-${item.id}'),
              icon: AppIcon(name: 'xMark', color: scheme.onSurfaceVariant),
              tooltip: l10n.commonDelete,
              onPressed: onRemove,
            ),
          ] else if (failedToSync)
            Padding(
              padding: const EdgeInsets.only(left: MitlistSpacing.sm),
              child: AppIcon(
                name: 'exclamationTriangle',
                size: 18,
                color: scheme.error,
              ),
            ),
        ],
      ),
    );

    // Taps on the tools count as inside the field, so reaching for them
    // does not end the edit first.
    Widget body = TextFieldTapRegion(
      child: Material(
        color: editing ? scheme.surfaceContainerLow : Colors.transparent,
        child: InkWell(
          onTap: editing ? null : onEdit,
          child: line,
        ),
      ),
    );

    if (reorderIndex != null && !editing) {
      body = ReorderableDelayedDragStartListener(
        index: reorderIndex!,
        child: body,
      );
    }

    return Semantics(
      customSemanticsActions: {
        if (onMoveUp != null)
          CustomSemanticsAction(label: l10n.listItemMoveUp): onMoveUp!,
        if (onMoveDown != null)
          CustomSemanticsAction(label: l10n.listItemMoveDown): onMoveDown!,
      },
      child: body,
    );
  }
}
