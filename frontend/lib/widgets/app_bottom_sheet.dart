import 'package:flutter/material.dart';

import '../theme/animations.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import '../theme/theme.dart';

/// A custom bottom sheet matching the mitlist design system.
///
/// Use [showAppBottomSheet] to display with the correct shape and animation.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(MitlistTheme.radiusLg),
        ),
        border: Border(
          top: BorderSide(color: colorScheme.outline, width: 2),
          left: BorderSide(color: colorScheme.outline, width: 2),
          right: BorderSide(color: colorScheme.outline, width: 2),
        ),
        boxShadow: MitlistShadows.shadowFloating,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: MitlistSpacing.sm),
          Center(
            child: Container(
              width: MitlistSpacing.space10,
              height: MitlistSpacing.space1,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.all(
                  Radius.circular(MitlistTheme.radiusFull),
                ),
              ),
            ),
          ),
          SizedBox(height: MitlistSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: MitlistSpacing.md),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                MitlistSpacing.lg,
                MitlistSpacing.space0,
                MitlistSpacing.lg,
                MitlistSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows an [AppBottomSheet] with a slide-up animation and scrim backdrop.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required String title,
  required Widget body,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
    isScrollControlled: true,
    sheetAnimationStyle: AnimationStyle(duration: MitlistAnimations.medium),
    builder: (context) => AppBottomSheet(title: title, body: body),
  );
}
