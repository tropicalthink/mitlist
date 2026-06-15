import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon.dart';
import '../widgets/empty_state.dart';

/// A boundary widget that displays a friendly error fallback when
/// [hasError] is true, otherwise renders the [builder] child.
///
/// The fallback uses [AppEmptyState] (error variant) with a retry
/// [AppButton].
class MitlistErrorBoundary extends StatelessWidget {
  final WidgetBuilder builder;
  final bool hasError;
  final VoidCallback? onRetry;

  const MitlistErrorBoundary({
    super.key,
    required this.builder,
    this.hasError = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (hasError) {
      return Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: AppEmptyState(
          isError: true,
          lottieAsset: 'assets/animations/lottie/404.lottie',
          icon: const AppIcon(name: 'exclamationTriangle'),
          title: l10n.errorBoundaryTitle,
          description: l10n.errorBoundaryDesc,
          paddingPreset: AppEmptyStatePadding.md,
          actions: [
            AppButton(
              text: l10n.commonRetry,
              icon: const AppIcon(name: 'arrowPath'),
              onPressed: onRetry,
            ),
          ],
        ),
      );
    }

    return Builder(builder: builder);
  }
}
