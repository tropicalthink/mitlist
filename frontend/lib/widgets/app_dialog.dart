import 'package:flutter/material.dart';

import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import '../theme/theme.dart';
import '../theme/typography.dart';

/// A custom dialog matching the mitlist design system.
///
/// Use [showAppDialog] to display with the correct animation and backdrop.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.md,
        vertical: MitlistSpacing.lg,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: MitlistColors.surfacePrimary,
          borderRadius: BorderRadius.all(
            Radius.circular(MitlistTheme.radiusLg),
          ),
          border: Border.fromBorderSide(
            BorderSide(color: MitlistColors.borderPrimary, width: 2),
          ),
          boxShadow: MitlistShadows.shadowMedium,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(title: title, textTheme: textTheme),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(MitlistSpacing.lg),
                child: body,
              ),
            ),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.textTheme});

  final String title;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: MitlistColors.borderPrimary, width: 2),
        ),
      ),
      padding: const EdgeInsets.only(
        left: MitlistSpacing.lg,
        right: MitlistSpacing.sm,
        top: MitlistSpacing.sm,
        bottom: MitlistSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: textTheme.titleLarge,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
            iconSize: MitlistSpacing.space5,
            color: MitlistColors.textPrimary,
            tooltip: 'Close',
            constraints: const BoxConstraints(
              minWidth: MitlistSpacing.space8,
              minHeight: MitlistSpacing.space8,
            ),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(MitlistSpacing.lg),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          'Press back to close',
          style: MitlistTypography.labelXSmall(
            color: MitlistColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Shows an [AppDialog] with fade + scale animation and a scrim backdrop.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required String title,
  required Widget body,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: MitlistColors.neutral950.withValues(alpha: 0.6),
    transitionDuration: MitlistAnimations.medium,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );

      return FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) => SafeArea(
      child: AppDialog(title: title, body: body),
    ),
  );
}
