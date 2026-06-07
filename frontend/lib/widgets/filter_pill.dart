import 'package:flutter/material.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: MitlistSpacing.space11,
      padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.space2),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius:
            const BorderRadius.all(Radius.circular(MitlistTheme.radiusMd)),
        border: Border.fromBorderSide(
          BorderSide(color: colorScheme.outline, width: 2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: MitlistTypography.labelXSmall(),
          ),
          const SizedBox(width: MitlistSpacing.space1),
          Semantics(
            button: true,
            label: 'Remove $label filter',
            child: GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: MitlistSpacing.space11,
                height: MitlistSpacing.space11,
                child: Center(
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
