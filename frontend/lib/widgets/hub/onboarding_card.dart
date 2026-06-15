import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/onboarding_provider.dart';
import '../../sheets/create_list_sheet.dart';
import '../../sheets/invite_household_sheet.dart';
import '../../theme/spacing.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_card.dart';

class HubQuickStart extends StatelessWidget {
  final String groupId;
  final VoidCallback? onDismiss;

  const HubQuickStart({super.key, required this.groupId, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    final titleSmall = Theme.of(context).textTheme.titleSmall;

    Widget actionTile({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.all(MitlistSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 28, color: colorScheme.primary),
                const SizedBox(height: MitlistSpacing.sm),
                Text(
                  label,
                  style: titleSmall,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppCard(
      variant: AppCardVariant.elevated,
      padding: AppCardPadding.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.lg,
              MitlistSpacing.md,
              MitlistSpacing.sm,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.hubOnboardingGetStarted,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Semantics(
                  button: true,
                  label: l10n.hubOnboardingDismiss,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      dismissHubQuickStart();
                      onDismiss?.call();
                    },
                    tooltip: l10n.hubOnboardingDismiss,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.sm,
              0,
              MitlistSpacing.sm,
              MitlistSpacing.sm,
            ),
            child: Text(
              l10n.hubOnboardingDescription,
              style: bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.sm,
              0,
              MitlistSpacing.sm,
              MitlistSpacing.sm,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: actionTile(
                      icon: Icons.person_add_outlined,
                      label: l10n.hubOnboardingInvite,
                      onTap: () async {
                        await Haptics.light();
                        if (context.mounted) {
                          await InviteHouseholdSheet.show(
                            context,
                            groupId: groupId,
                          );
                        }
                      },
                    ),
                  ),
                  Container(
                    width: 2,
                    color: colorScheme.outline,
                  ),
                  Expanded(
                    child: actionTile(
                      icon: Icons.checklist_outlined,
                      label: l10n.hubOnboardingCreateList,
                      onTap: () async {
                        await Haptics.light();
                        if (context.mounted) {
                          await CreateListSheet.show(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 2,
            color: colorScheme.outline,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.sm,
              MitlistSpacing.sm,
              MitlistSpacing.sm,
              MitlistSpacing.sm,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: actionTile(
                      icon: Icons.assignment_turned_in_outlined,
                      label: l10n.hubOnboardingAddChore,
                      onTap: () {
                        Haptics.light();
                        context.goNamed('chores');
                      },
                    ),
                  ),
                  Container(
                    width: 2,
                    color: colorScheme.outline,
                  ),
                  Expanded(
                    child: actionTile(
                      icon: Icons.receipt_long_outlined,
                      label: l10n.hubOnboardingTrackExpense,
                      onTap: () {
                        Haptics.light();
                        context.goNamed('money');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
