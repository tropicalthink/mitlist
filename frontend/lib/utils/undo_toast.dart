import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
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

  final l10n = AppLocalizations.of(context)!;

  final snackBar = SnackBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    duration: Duration(seconds: 10),
    content: Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
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
              foregroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: MitlistSpacing.md,
              ),
              minimumSize: Size(
                MitlistSpacing.space11,
                MitlistSpacing.space11,
              ),
              textStyle: MitlistTypography.lightTextTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            child: Text(l10n.commonUndo),
          ),
        ],
      ),
    ),
  );

  scaffoldMessenger.showSnackBar(snackBar);
}
