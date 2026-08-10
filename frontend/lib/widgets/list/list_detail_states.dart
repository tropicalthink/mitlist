import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/spacing.dart';
import '../alert.dart';
import '../app_button.dart';
import '../app_icon.dart';
import '../empty_state.dart';

/// Error state for the list detail screen: the failure message with retry and
/// dismiss affordances.
class ListDetailErrorView extends StatelessWidget {
  const ListDetailErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppAlert(type: AppAlertType.error, message: message),
            const SizedBox(height: MitlistSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: MitlistSpacing.md,
              runSpacing: MitlistSpacing.sm,
              children: [
                AppButton(
                  text: l10n.commonRetry,
                  variant: AppButtonVariant.outline,
                  onPressed: onRetry,
                ),
                AppButton(
                  text: l10n.commonDismiss,
                  variant: AppButtonVariant.ghost,
                  onPressed: onDismiss,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state for a list with no items: scan-this-list (primary) and
/// type-an-item (secondary) calls to action.
class ListDetailEmptyView extends StatelessWidget {
  const ListDetailEmptyView({
    super.key,
    required this.onScan,
    required this.onType,
  });

  final VoidCallback onScan;
  final VoidCallback onType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/checklist.lottie',
          icon: AppIcon(name: 'queueList'),
          title: l10n.listDetailNothingHere,
          description: l10n.listDetailNothingHereDesc,
          actions: [
            AppButton(
              text: l10n.listDetailScanThisList,
              size: AppButtonSize.xl,
              icon: const AppIcon(name: 'camera'),
              onPressed: onScan,
            ),
            AppButton(
              text: l10n.listDetailTypeItem,
              variant: AppButtonVariant.outline,
              onPressed: onType,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when a search filter matches no items.
class ListDetailSearchEmptyView extends StatelessWidget {
  const ListDetailSearchEmptyView({super.key, required this.onClearSearch});

  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(
              name: 'magnifyingGlass',
              size: 40,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            Text(
              l10n.listDetailNoMatch,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: MitlistSpacing.md),
            AppButton(
              text: l10n.commonClearSearch,
              variant: AppButtonVariant.outline,
              onPressed: onClearSearch,
            ),
          ],
        ),
      ),
    );
  }
}
