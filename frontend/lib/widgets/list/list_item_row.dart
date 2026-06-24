import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/list_models.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../animated_check_toggle.dart';
import '../animated_strikethrough.dart';
import '../app_icon.dart';

class ListItemRow extends StatelessWidget {
  const ListItemRow({
    super.key,
    required this.item,
    required this.onToggle,
    this.photoUrl,
    this.currencySymbol = '\$',
    this.claimedLabel,
    this.onPhotoTap,
    this.onLongPress,
    this.reorderIndex,
    this.failedToSync = false,
  });

  final ListItem item;
  final ValueChanged<bool> onToggle;
  final String? photoUrl;
  final String currencySymbol;
  final String? claimedLabel;
  final VoidCallback? onPhotoTap;
  final VoidCallback? onLongPress;
  final int? reorderIndex;

  /// When true this item has a change the server rejected (a dead-lettered
  /// outbox op). Shown so the optimistic local row isn't silently passed off as
  /// saved. Tap the sync banner to retry or discard it.
  final bool failedToSync;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final row = Material(
      color: colorScheme.surface,
      child: InkWell(
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
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
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (reorderIndex != null) ...[
                Semantics(
                  label: l10n.listItemReorder,
                  child: Tooltip(
                    message: l10n.listItemReorder,
                    child: ReorderableDragStartListener(
                      index: reorderIndex!,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: AppIcon(
                            name: 'dragHandle',
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              AnimatedCheckToggle(
                value: item.checked,
                onChanged: onToggle,
                semanticLabelOn: l10n.listItemMarkUnchecked(item.name),
                semanticLabelOff: l10n.listItemMarkChecked(item.name),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              if (photoUrl != null) ...[
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
                            width: 28,
                            height: 28,
                            child: Image.network(
                              photoUrl!,
                              fit: BoxFit.cover,
                              cacheWidth: (28 *
                                      MediaQuery.devicePixelRatioOf(context) *
                                      1.5)
                                  .round(),
                              errorBuilder: (_, __, ___) => AppIcon(
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
                const SizedBox(width: MitlistSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedStrikethrough(
                      text: item.name,
                      struck: item.checked,
                      style: textTheme.bodyLarge?.copyWith(height: 1.25),
                      color: colorScheme.onSurface,
                    ),
                    if (failedToSync)
                      Text(
                        l10n.listItemFailedSave,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                          height: 1.3,
                        ),
                      )
                    else if (item.note.isNotEmpty)
                      Text(
                        item.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ),
              if (failedToSync)
                Padding(
                  padding: const EdgeInsets.only(left: MitlistSpacing.sm),
                  child: AppIcon(
                    name: 'exclamationTriangle',
                    size: 18,
                    color: colorScheme.error,
                  ),
                ),
              if (item.quantity > 1 || item.unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: MitlistSpacing.sm),
                  child: Text(
                    item.unit.isNotEmpty
                        ? '${_formatQuantity(item.quantity)} ${item.unit}'
                        : '${_formatQuantity(item.quantity)}×',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MitlistTypography.monoBody(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (item.priceCents != null && item.priceCents! > 0)
                Padding(
                  padding: const EdgeInsets.only(left: MitlistSpacing.sm),
                  child: Text(
                    '$currencySymbol${(item.priceCents! / 100).toStringAsFixed(2)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MitlistTypography.monoBody(
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              if (claimedLabel != null)
                Padding(
                  padding: const EdgeInsets.only(left: MitlistSpacing.sm),
                  child: Text(
                    claimedLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (onLongPress == null) return row;

    return Semantics(
      button: true,
      hint: l10n.listItemLongPressHint,
      child: row,
    );
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
