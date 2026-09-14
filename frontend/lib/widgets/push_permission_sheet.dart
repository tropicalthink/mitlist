import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/spacing.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';
import 'app_icon.dart';

/// The in-app explainer shown before the OS notification dialog.
///
/// Resolves to true when the user wants notifications (the caller then asks
/// the OS), false for "not now", and null when the sheet was dismissed.
Future<bool?> showPushPermissionSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showAppBottomSheet<bool>(
    context: context,
    title: l10n.pushPromptTitle,
    body: const _PushPermissionBody(),
  );
}

class _PushPermissionBody extends StatelessWidget {
  const _PushPermissionBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(MitlistSpacing.sm),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(MitlistSpacing.sm),
              ),
              child: AppIcon(
                name: 'bell',
                size: 24,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: MitlistSpacing.md),
            Expanded(
              child: Text(
                l10n.pushPromptBody,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.lg),
        AppButton(
          text: l10n.pushPromptEnable,
          icon: const AppIcon(name: 'bell', size: 18),
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        AppButton(
          text: l10n.pushPromptLater,
          variant: AppButtonVariant.ghost,
          color: AppButtonColor.neutral,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(height: MitlistSpacing.sm),
      ],
    );
  }
}
