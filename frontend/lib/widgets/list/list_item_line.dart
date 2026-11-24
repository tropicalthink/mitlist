import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/list_models.dart';
import '../../providers/outbox_provider.dart';
import '../../theme/spacing.dart';
import '../animated_check_toggle.dart';
import '../animated_strikethrough.dart';
import '../../utils/list_item_edit.dart';
import '../app_icon.dart';

/// One line of a list, written like a note's checklist (Apple Notes, Google
/// Keep): a checkbox and the words, nothing boxed around them.
///
/// - The checkbox ticks the item off; nothing else on the line does.
/// - Tapping the words edits them in place, with the caret where the tap
///   landed. While a line is edited its note can open as a second field
///   under the name; the screen pins the other details (amount, unit,
///   price, photo, delete) in a row above the keyboard.
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
    this.onEditAt,
    this.noteController,
    this.noteFocusNode,
    this.showNoteField = false,
    this.onSubmitNote,
    this.editTapRegionGroupId,
    this.photoUrl,
    this.onPhotoTap,
    this.currencySymbol = '\$',
    this.claimed = false,
    this.addedByName,
    this.reorderIndex,
    this.onMoveUp,
    this.onMoveDown,
    this.checked,
  });

  final ListItem item;
  final ValueChanged<bool> onToggle;

  /// Tap on the words: start editing this line.
  final VoidCallback onEdit;

  final bool editing;
  final TextEditingController? editController;
  final FocusNode? editFocusNode;
  final VoidCallback? onSubmitEdit;

  /// Tap on the name itself: start editing with the caret at that character
  /// offset. Without it a tap anywhere on the line calls [onEdit].
  final ValueChanged<int>? onEditAt;

  /// The note's own field, shown under the name while editing when
  /// [showNoteField] is set.
  final TextEditingController? noteController;
  final FocusNode? noteFocusNode;
  final bool showNoteField;

  /// Return in the note field.
  final VoidCallback? onSubmitNote;

  /// Shared with the edit controls outside the line, so a tap there counts
  /// as inside this line's fields.
  final Object? editTapRegionGroupId;

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

  /// Shown ticked state when it runs ahead of [item] (the shopping trip
  /// ticks a line before the cache row it was read from catches up).
  final bool? checked;

  static String formatQuantity(double value) => formatItemAmount(value);

  /// The character of [text] under [position] when laid out like the
  /// line's name in [maxWidth].
  static int caretOffsetAt(
    BuildContext context,
    String text,
    TextStyle? style,
    Offset position,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final offset = painter.getPositionForOffset(position).offset;
    painter.dispose();
    return offset.clamp(0, text.length);
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
    final detailText = failedToSync
        ? l10n.listItemFailedSave
        // While editing, the details sit in the controls above the keyboard.
        : editing
            ? null
            : details(l10n);
    final tapGroup = editTapRegionGroupId ?? EditableText;
    const bareField = InputDecoration(
      isCollapsed: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      filled: false,
      counterText: '',
      contentPadding: EdgeInsets.zero,
    );

    Widget words;
    if (editing && editController != null) {
      words = TextField(
        key: ValueKey('item-line-edit-${item.id}'),
        controller: editController,
        focusNode: editFocusNode,
        groupId: tapGroup,
        style: nameStyle,
        minLines: 1,
        maxLines: 4,
        maxLength: 200,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        decoration: bareField,
        onSubmitted: (_) => onSubmitEdit?.call(),
      );
      if (showNoteField && noteController != null) {
        words = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            words,
            Padding(
              padding: const EdgeInsets.only(top: MitlistSpacing.xs),
              child: TextField(
                key: ValueKey('item-line-note-${item.id}'),
                controller: noteController,
                focusNode: noteFocusNode,
                groupId: tapGroup,
                style: detailStyle,
                minLines: 1,
                maxLines: 3,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: bareField.copyWith(
                  hintText: l10n.listItemNoteLabel,
                  hintStyle: detailStyle,
                ),
                onSubmitted: (_) => onSubmitNote?.call(),
              ),
            ),
          ],
        );
      }
    } else {
      words = AnimatedStrikethrough(
        text: item.name,
        struck: checked ?? item.checked,
        style: nameStyle ?? const TextStyle(),
        color: (checked ?? item.checked)
            ? scheme.onSurfaceVariant
            : scheme.onSurface,
      );
      if (onEditAt != null) {
        final shown = words;
        words = LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            key: ValueKey('item-line-name-${item.id}'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => onEditAt!(
              caretOffsetAt(
                context,
                item.name,
                nameStyle,
                details.localPosition,
                constraints.maxWidth,
              ),
            ),
            child: shown,
          ),
        );
      }
    }

    final line = Padding(
      padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedCheckToggle(
            value: checked ?? item.checked,
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
          if (failedToSync)
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

    // Taps anywhere on the line (and on the edit controls sharing its
    // group) count as inside the field, so reaching for them does not end
    // the edit first.
    Widget body = TapRegion(
      groupId: tapGroup,
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
