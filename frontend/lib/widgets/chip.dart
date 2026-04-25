import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/theme.dart';

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.leading,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        selected ? MitlistColors.neutral950 : MitlistColors.surfacePrimary;
    final foregroundColor =
        selected ? Colors.white : MitlistColors.textSecondary;

    return GestureDetector(
      onTap: onSelected != null ? () => onSelected!(!selected) : null,
      child: Container(
        height: MitlistSpacing.space8,
        padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.space3),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius:
              const BorderRadius.all(Radius.circular(MitlistTheme.radiusMd)),
          border: const Border.fromBorderSide(
            BorderSide(color: MitlistColors.borderPrimary, width: 2),
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
              label.toUpperCase(),
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
