import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/list_models.dart';
import '../../theme/grocery_category_visual.dart';
import '../../theme/list_tile_accent.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../animated_check_toggle.dart';
import '../animated_strikethrough.dart';
import '../app_card.dart';
import '../app_icon.dart';

class ListItemRow extends StatelessWidget {
  const ListItemRow({
    super.key,
    required this.item,
    required this.onToggle,
    this.onTap,
    this.photoUrl,
    this.currencySymbol = '\$',
    this.claimedLabel,
    this.addedByName,
    this.onPhotoTap,
    this.onLongPress,
    this.reorderIndex,
    this.failedToSync = false,
    this.shoppingVisual = false,
    this.groceryCategory,
  });

  final ListItem item;
  final ValueChanged<bool> onToggle;

  /// Tap anywhere on the row. Wired to the check toggle so the whole 56px row
  /// is a target, not just the checkbox.
  final VoidCallback? onTap;
  final String? photoUrl;
  final String currencySymbol;
  final String? claimedLabel;

  /// Display name of the household member who added the item, shown as a
  /// small line under the row. Null when it was the viewer or unknown.
  final String? addedByName;
  final VoidCallback? onPhotoTap;
  final VoidCallback? onLongPress;
  final int? reorderIndex;
  final bool shoppingVisual;
  final String? groceryCategory;

  /// When true this item has a change the server rejected (a dead-lettered
  /// outbox op). Shown so the optimistic local row isn't silently passed off as
  /// saved. Tap the sync banner to retry or discard it.
  final bool failedToSync;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final accent = shoppingVisual
        ? ListTileAccent.fromSeed(
            GroceryCategoryVisual.seed(
              groceryCategory,
              item.canonicalItemId ?? item.name,
            ),
            Theme.of(context).brightness,
          )
        : null;
    final showCategoryColor = shoppingVisual && !item.checked;
    final primaryTextColor =
        showCategoryColor ? accent!.titleColor : colorScheme.onSurface;
    final secondaryTextColor = showCategoryColor
        ? accent!.snippetOnTile
        : colorScheme.onSurfaceVariant;
    final categoryIconColor = item.checked
        ? colorScheme.onSurfaceVariant
        : accent?.iconColor ?? colorScheme.onSurfaceVariant;
    final amountLabel = item.quantity > 1 || item.unit.isNotEmpty
        ? (item.unit.isNotEmpty
            ? '${_formatQuantity(item.quantity)} ${item.unit}'
            : '${_formatQuantity(item.quantity)}×')
        : null;
    final priceLabel = item.priceCents != null && item.priceCents! > 0
        ? '$currencySymbol${(item.priceCents! / 100).toStringAsFixed(2)}'
        : null;
    final claimedMetadata = claimedLabel?.replaceFirst(RegExp(r'^·\s*'), '');
    final shoppingMetadata = [amountLabel, priceLabel, claimedMetadata]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .join(' · ');

    final content = Container(
      decoration: shoppingVisual
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
      padding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.sm,
        vertical: MitlistSpacing.sm,
      ),
      constraints: BoxConstraints(minHeight: shoppingVisual ? 64 : 56),
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
                        color: secondaryTextColor,
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
          if (shoppingVisual && photoUrl == null) ...[
            ExcludeSemantics(
              child: AppIcon(
                name: GroceryCategoryVisual.iconName(groceryCategory),
                size: 22,
                color: categoryIconColor,
              ),
            ),
            const SizedBox(width: MitlistSpacing.sm),
          ],
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
                  style: textTheme.bodyLarge?.copyWith(
                    height: 1.25,
                    fontWeight: shoppingVisual ? FontWeight.w700 : null,
                  ),
                  color: primaryTextColor,
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
                      color: secondaryTextColor,
                      height: 1.3,
                    ),
                  ),
                if (shoppingVisual && shoppingMetadata.isNotEmpty)
                  Text(
                    shoppingMetadata,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MitlistTypography.monoBody(
                      color: secondaryTextColor,
                    ),
                  ),
                if (addedByName != null && addedByName!.isNotEmpty)
                  Text(
                    l10n.listItemAddedBy(addedByName!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MitlistTypography.labelXSmall(
                      color: secondaryTextColor,
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
          if (!shoppingVisual && amountLabel != null)
            Padding(
              padding: const EdgeInsets.only(left: MitlistSpacing.sm),
              child: Text(
                amountLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MitlistTypography.monoBody(
                  color: secondaryTextColor,
                ),
              ),
            ),
          if (!shoppingVisual && priceLabel != null)
            Padding(
              padding: const EdgeInsets.only(left: MitlistSpacing.sm),
              child: Text(
                priceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MitlistTypography.monoBody(
                  color: colorScheme.primary,
                ),
              ),
            ),
          if (!shoppingVisual && claimedLabel != null)
            Padding(
              padding: const EdgeInsets.only(left: MitlistSpacing.sm),
              child: Text(
                claimedLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: secondaryTextColor,
                ),
              ),
            ),
        ],
      ),
    );

    final Widget row;
    if (shoppingVisual) {
      row = AppCard(
        variant: AppCardVariant.outlined,
        padding: AppCardPadding.none,
        backgroundColor: item.checked
            ? colorScheme.surfaceContainerLow
            : accent!.tileBackground,
        interactive: true,
        onTap: onTap,
        onLongPress: onLongPress,
        semanticLabel: item.name,
        child: content,
      );
    } else {
      row = Material(
        color: colorScheme.surface,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: content,
        ),
      );
    }

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
