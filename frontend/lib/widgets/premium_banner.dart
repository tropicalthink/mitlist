import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/billing_provider.dart';
import '../sheets/premium_sheet.dart';
import '../theme/spacing.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';

/// Warns that a household has run out of free places, and opens the premium
/// sheet.
///
/// Shown where a member is *about* to add someone — the person inviting can
/// pay, whereas the person being blocked on join cannot. Renders nothing at all
/// when billing is disabled on the server, when the household is premium, or
/// while there are still free places, so it is safe to drop into any layout.
class PremiumBanner extends ConsumerWidget {
  const PremiumBanner({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final entitlement =
        ref.watch(householdEntitlementProvider(groupId)).valueOrNull;

    // Null covers both "billing disabled" and "could not load" — in either case
    // there is no paywall to advertise.
    if (entitlement == null || entitlement.canAddMember) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
      child: AppCard(
        variant: AppCardVariant.filled,
        padding: AppCardPadding.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(name: 'userGroup', color: theme.colorScheme.primary),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.billingLimitReachedTitle,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MitlistSpacing.xs),
            Text(
              l10n.billingLimitReachedBody(
                entitlement.freeLimit,
                entitlement.freeLimit + 1,
              ),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: MitlistSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: entitlement.canMovePremiumHere
                    ? l10n.billingMoveHereAction
                    : l10n.billingSubscribe,
                variant: AppButtonVariant.solid,
                color: AppButtonColor.primary,
                onPressed: () =>
                    showPremiumSheet(context, ref, groupId: groupId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
