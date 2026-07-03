import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/spacing.dart';
import '../../../widgets/alert.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/skeleton.dart';

/// Skeleton placeholder shown while the first page of expenses loads.
class ExpenseLoadingBody extends StatelessWidget {
  const ExpenseLoadingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
      child: Column(
        children: [
          const AppSkeleton(
            width: double.infinity,
            height: MitlistSpacing.space12,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          const AppSkeleton(
            width: double.infinity,
            height: MitlistSpacing.space12,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          const AppSkeleton(
            width: double.infinity,
            height: MitlistSpacing.space12,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          AppSkeleton(
            width: double.infinity,
            height: MitlistSpacing.space12,
          ),
        ],
      ),
    );
  }
}

/// Full-body error state with a retry action.
class ExpenseErrorBody extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const ExpenseErrorBody({super.key, this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Column(
        children: [
          AppAlert(
            type: AppAlertType.error,
            message: message ?? l10n.commonFailedToLoad,
          ),
          const SizedBox(height: MitlistSpacing.md),
          AppButton(
            text: l10n.commonRetry,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Shown when the account has no active household to record expenses in.
class ExpenseNoHouseholdBody extends StatelessWidget {
  final VoidCallback onOpenHouseholds;

  const ExpenseNoHouseholdBody({super.key, required this.onOpenHouseholds});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/House.lottie',
          icon: AppIcon(name: 'home', size: 56),
          title: l10n.commonNoHousehold,
          description: l10n.commonCreateJoinHousehold,
          actions: [
            AppButton(
              text: l10n.commonGoToHouseholds,
              onPressed: onOpenHouseholds,
            ),
          ],
        ),
      ),
    );
  }
}
