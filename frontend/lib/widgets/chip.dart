import 'package:flutter/material.dart';
import '../theme/spacing.dart';
import '../theme/theme.dart';

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.onLongPress,
    this.leading,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  /// Secondary action on the chip itself — used for destructive edits (remove
  /// this zone) that shouldn't take a permanent × on every chip.
  final VoidCallback? onLongPress;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor =
        selected ? colorScheme.onSurface : colorScheme.surface;
    final foregroundColor =
        selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onSelected != null ? () => onSelected!(!selected) : null,
      onLongPress: onLongPress,
      child: Container(
        height: MitlistSpacing.space11,
        padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.space3),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius:
              const BorderRadius.all(Radius.circular(MitlistTheme.radiusMd)),
          border: Border.fromBorderSide(
            BorderSide(color: colorScheme.outline, width: 2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              SizedBox(
                width: MitlistSpacing.space4,
                height: MitlistSpacing.space4,
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(
                      color: foregroundColor,
                      size: MitlistSpacing.space4,
                    ),
                    child: leading!,
                  ),
                ),
              ),
              const SizedBox(width: MitlistSpacing.space1),
            ],
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: foregroundColor),
            ),
          ],
        ),
      ),
    );
  }
}
