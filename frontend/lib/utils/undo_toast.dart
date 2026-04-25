import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// Shows a SnackBar with an Undo action.
///
/// Uses `neutral950` background, white text, `primary400` action label,
/// `shadowMedium`, and a 10-second duration.
void showUndoToast(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  final snackBar = SnackBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 10),
    content: Container(
      decoration: BoxDecoration(
        color: MitlistColors.neutral950,
        border: Border.all(
          color: MitlistColors.borderPrimary,
          width: MitlistSpacing.space1 / 2,
        ),
        boxShadow: MitlistShadows.shadowMedium,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.md,
        vertical: MitlistSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: MitlistTypography.lightTextTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              scaffoldMessenger.hideCurrentSnackBar();
              onUndo();
            },
            style: TextButton.styleFrom(
              foregroundColor: MitlistColors.primary400,
              padding: const EdgeInsets.symmetric(
                horizontal: MitlistSpacing.md,
              ),
              minimumSize: const Size(
                MitlistSpacing.space11,
                MitlistSpacing.space11,
              ),
              textStyle: MitlistTypography.lightTextTheme.labelLarge?.copyWith(
                color: MitlistColors.primary400,
              ),
            ),
            child: const Text('UNDO'),
          ),
        ],
      ),
    ),
  );

  scaffoldMessenger.showSnackBar(snackBar);
}
