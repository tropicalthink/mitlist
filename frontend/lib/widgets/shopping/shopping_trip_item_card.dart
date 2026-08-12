import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/list_models.dart';
import '../../theme/animations.dart';
import '../../theme/grocery_category_visual.dart';
import '../../theme/list_tile_accent.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../animated_check_toggle.dart';
import '../animated_strikethrough.dart';
import '../app_card.dart';
import '../app_icon.dart';

/// The one-handed picking target used during a shopping trip. Canonical
/// category color and icon make an aisle glanceable; the entire card toggles
/// the item while the embedded check control keeps its explicit semantics.
class ShoppingTripItemCard extends StatefulWidget {
  const ShoppingTripItemCard({
    super.key,
    required this.item,
    required this.isChecked,
    required this.onToggle,
    this.groceryCategory,
  });

  final ListItem item;
  final bool isChecked;
  final VoidCallback onToggle;
  final String? groceryCategory;

  @override
  State<ShoppingTripItemCard> createState() => _ShoppingTripItemCardState();
}

class _ShoppingTripItemCardState extends State<ShoppingTripItemCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MitlistAnimations.checkToggle,
      value: widget.isChecked ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(ShoppingTripItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isChecked != oldWidget.isChecked) {
      widget.isChecked ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final accent = ListTileAccent.fromSeed(
      GroceryCategoryVisual.seed(
        widget.groceryCategory,
        widget.item.canonicalItemId ?? widget.item.name,
      ),
      Theme.of(context).brightness,
    );
    final openText = accent.titleColor;
    final openSecondary = accent.snippetOnTile;
    final checkedText = colorScheme.onSurfaceVariant;
    final amount = _amountLabel(widget.item);
    final price = widget.item.priceCents != null && widget.item.priceCents! > 0
        ? '€${(widget.item.priceCents! / 100).toStringAsFixed(2)}'
        : null;
    final metadata = [amount, price]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .join(' · ');
    final semanticLabel = widget.isChecked
        ? l10n.shoppingTripMarkNotPurchased(widget.item.name)
        : l10n.shoppingTripMarkPurchased(widget.item.name);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = disableAnimations
            ? (widget.isChecked ? 1.0 : 0.0)
            : _controller.value;
        final hop = disableAnimations ? 0.0 : -math.sin(math.pi * t) * 3.0;
        final secondaryColor = Color.lerp(openSecondary, checkedText, t)!;

        return Transform.translate(
          offset: Offset(0, hop),
          child: AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.none,
            backgroundColor: widget.isChecked
                ? colorScheme.surfaceContainerLow
                : accent.tileBackground,
            interactive: true,
            onTap: widget.onToggle,
            semanticLabel: semanticLabel,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MitlistSpacing.sm,
                  vertical: MitlistSpacing.sm,
                ),
                child: Row(
                  children: [
                    AnimatedCheckToggle(
                      value: widget.isChecked,
                      onChanged: (_) => widget.onToggle(),
                      semanticLabelOn: l10n.shoppingTripMarkNotPurchased(
                        widget.item.name,
                      ),
                      semanticLabelOff: l10n.shoppingTripMarkPurchased(
                        widget.item.name,
                      ),
                    ),
                    const SizedBox(width: MitlistSpacing.xs),
                    ExcludeSemantics(
                      child: AppIcon(
                        name: GroceryCategoryVisual.iconName(
                          widget.groceryCategory,
                        ),
                        size: 24,
                        color:
                            widget.isChecked ? checkedText : accent.iconColor,
                      ),
                    ),
                    const SizedBox(width: MitlistSpacing.sm),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedStrikethrough(
                            text: widget.item.name,
                            struck: widget.isChecked,
                            color: openText,
                            struckColor: checkedText,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          if (metadata.isNotEmpty)
                            Text(
                              metadata,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MitlistTypography.monoBody(
                                color: secondaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String? _amountLabel(ListItem item) {
    if (item.quantity <= 0 || (item.quantity == 1 && item.unit.isEmpty)) {
      return null;
    }
    final quantity = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(1);
    return item.unit.isEmpty ? '$quantity×' : '$quantity ${item.unit}';
  }
}
