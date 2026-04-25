import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/theme.dart';
import '../theme/typography.dart';

class AppFilterPill extends StatelessWidget {
  const AppFilterPill({
    super.key,
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MitlistSpacing.space7,
      padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.space2),
      decoration: BoxDecoration(
        color: MitlistColors.surfacePrimary,
        borderRadius:
            const BorderRadius.all(Radius.circular(MitlistTheme.radiusMd)),
        border: const Border.fromBorderSide(
          BorderSide(color: MitlistColors.borderPrimary, width: 2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: MitlistTypography.labelXSmall(),
          ),
          const SizedBox(width: MitlistSpacing.space1),
          GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: MitlistSpacing.space7,
              height: MitlistSpacing.space7,
              child: const Center(
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: MitlistColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
