import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/chore_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../sheets/chore_creation_sheet.dart';
import '../../sheets/create_list_sheet.dart';
import '../../sheets/expense_creation_sheet.dart';
import '../../sheets/invite_household_sheet.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/board/artifact_scraps.dart';
import '../../widgets/board/cork_board.dart';

/// The landing beat of the first run, told in objects instead of sentences.
///
/// Each step is a ghost of the thing it creates — a list scrap with dashed
/// checkboxes, a blank chore note, a receipt with no amounts — the same
/// miniatures the welcome screen showed filled. The next step leads at full
/// size with the solid plus badge; tapping it opens the create sheet right
/// here. When the real thing exists, the ghost fills in and takes the DONE
/// stamp: the artifact itself is the progress report.
///
/// Inviting flatmates is a separate slip showing the household's seats — one
/// solid circle per member, dashed circles for the empty chairs. It never
/// counts toward progress: a solo user finishes the quick start alone, and
/// the empty chairs simply wait.
class HubQuickStart extends ConsumerWidget {
  final String groupId;
  final VoidCallback? onDismiss;

  const HubQuickStart({super.key, required this.groupId, this.onDismiss});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final groupsAsync = ref.watch(cachedGroupsProvider);
    final listsAsync = ref.watch(cachedListsByGroupProvider(groupId));
    final choresAsync = ref.watch(cachedCurrentChoresByGroupProvider(groupId));
    final expensesAsync = ref.watch(cachedExpensesByGroupProvider(groupId));

    // Don't flash a to-do strip at an established household: wait until the
    // local caches have answered before deciding anything is "not done".
    if (!groupsAsync.hasValue ||
        !listsAsync.hasValue ||
        !choresAsync.hasValue ||
        !expensesAsync.hasValue) {
      return const SizedBox.shrink();
    }

    final groups = groupsAsync.valueOrNull ?? const [];
    final memberCount = groups
        .where((g) => g.id == groupId)
        .map((g) => g.memberCount)
        .firstOrNull;
    final lists = listsAsync.valueOrNull ?? const [];
    final chores = choresAsync.valueOrNull ?? const [];
    final expenses = expensesAsync.valueOrNull ?? const [];

    final steps = <_QuickStep>[
      _QuickStep(
        label: l10n.hubOnboardingCreateList,
        done: lists.isNotEmpty,
        artifact: (ghost) =>
            ListScrap(label: l10n.hubOnboardingCreateList, ghost: ghost),
        onTap: () {
          Haptics.light();
          CreateListSheet.show(context);
        },
      ),
      _QuickStep(
        label: l10n.hubOnboardingAddChore,
        done: chores.isNotEmpty,
        artifact: (ghost) =>
            ChoreScrap(label: l10n.hubOnboardingAddChore, ghost: ghost),
        onTap: () {
          Haptics.light();
          ChoreCreationSheet.show(context);
        },
      ),
      _QuickStep(
        label: l10n.hubOnboardingTrackExpense,
        done: expenses.isNotEmpty,
        artifact: (ghost) =>
            ReceiptScrap(label: l10n.hubOnboardingTrackExpense, ghost: ghost),
        onTap: () {
          Haptics.light();
          ExpenseCreationSheet.show(context);
        },
      ),
    ];

    final doneCount = steps.where((s) => s.done).length;

    // The household is going; the strip's work is over. Inviting deliberately
    // doesn't hold this back — the seats slip is an offer, not homework.
    if (doneCount == steps.length) return const SizedBox.shrink();

    final nextIndex = steps.indexWhere((s) => !s.done);
    final next = steps[nextIndex];
    final rest = [
      for (var i = 0; i < steps.length; i++)
        if (i != nextIndex) steps[i],
    ];
    final reduce = MediaQuery.of(context).disableAnimations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.hubChecklistTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              l10n.hubChecklistProgress(doneCount, steps.length),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  AppToast.info(context, l10n.hubQuickStartDismissedToast);
                },
                tooltip: l10n.hubOnboardingDismiss,
              ),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final nextW = math.min(280.0, constraints.maxWidth * 0.68);
            const gap = MitlistSpacing.space3;
            final smallW = (constraints.maxWidth - gap) / 2;

            return Column(
              children: [
                // The one thing to do next: the ghost artifact at full size,
                // wearing the solid plus badge. A gentle swap when a step
                // completes and the next ghost takes the lead.
                AnimatedSwitcher(
                  duration: reduce ? Duration.zero : MitlistAnimations.medium,
                  switchInCurve: MitlistAnimations.easeEnter,
                  switchOutCurve: MitlistAnimations.easeExit,
                  child: KeyedSubtree(
                    key: ValueKey(nextIndex),
                    child: SizedBox(
                      width: nextW,
                      child: Transform.rotate(
                        angle: -0.020,
                        child: BoardPressable(
                          semanticLabel:
                              l10n.hubQuickStartNextSemantic(next.label),
                          onTap: next.onTap,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              next.artifact(true),
                              const Positioned(
                                right: -8,
                                bottom: -8,
                                child: ScrapPlusBadge(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MitlistSpacing.space5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < rest.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      SizedBox(
                        width: smallW,
                        child: Transform.rotate(
                          angle: (i.isEven ? 1 : -1) * (0.014 + 0.006 * i),
                          child: _SmallStep(step: rest[i], l10n: l10n),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: MitlistSpacing.space5),
        Transform.rotate(
          angle: 0.010,
          child: _InviteSlip(
            l10n: l10n,
            members: memberCount ?? 1,
            onTap: () {
              Haptics.light();
              InviteHouseholdSheet.show(context, groupId: groupId);
            },
          ),
        ),
      ],
    );
  }
}

class _QuickStep {
  const _QuickStep({
    required this.label,
    required this.done,
    required this.artifact,
    required this.onTap,
  });

  final String label;
  final bool done;

  /// Builds the step's miniature artifact; `ghost` false renders the filled
  /// (welcome-collage) form.
  final Widget Function(bool ghost) artifact;
  final VoidCallback onTap;
}

/// A step that isn't leading right now. Waiting: the ghost at small size,
/// still tappable for anyone jumping ahead. Done: the filled artifact with
/// the DONE stamp — the real thing, visibly on the board.
class _SmallStep extends StatelessWidget {
  const _SmallStep({required this.step, required this.l10n});

  final _QuickStep step;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return BoardPressable(
      semanticLabel:
          step.done ? '${step.label}. ${l10n.hubChecklistDone}' : step.label,
      onTap: step.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          step.artifact(!step.done),
          _DoneStamp(visible: step.done, l10n: l10n),
        ],
      ),
    );
  }
}

/// Inviting the rest of the house, shown as seats: solid circles for the
/// members already here, dashed circles for the empty chairs. Stamped when
/// someone actually joins; never counted against progress.
class _InviteSlip extends StatelessWidget {
  const _InviteSlip({
    required this.l10n,
    required this.members,
    required this.onTap,
  });

  final AppLocalizations l10n;
  final int members;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Paper stays paper-white in both themes so ink contrast is constant.
    const ink = MitlistColors.textPrimary;
    final invited = members > 1;

    return BoardPressable(
      semanticLabel: invited
          ? '${l10n.hubOnboardingInvite}. ${l10n.hubChecklistDone}'
          : l10n.hubOnboardingInvite,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          TornSlip(
            padding: const EdgeInsets.all(MitlistSpacing.space4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ScrapLabel(l10n.hubOnboardingInvite),
                      const SizedBox(height: MitlistSpacing.space3),
                      InviteSeats(members: members),
                    ],
                  ),
                ),
                const SizedBox(width: MitlistSpacing.space3),
                const Icon(Icons.arrow_forward, size: 18, color: ink),
              ],
            ),
          ),
          _DoneStamp(visible: invited, l10n: l10n),
        ],
      ),
    );
  }
}

/// The DONE stamp lands on a note the moment the real thing happened, angled
/// like a rubber stamp that didn't quite line up.
class _DoneStamp extends StatelessWidget {
  const _DoneStamp({required this.visible, required this.l10n});

  final bool visible;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduce = MediaQuery.of(context).disableAnimations;

    return Positioned(
      right: -4,
      top: MitlistSpacing.space3,
      child: IgnorePointer(
        child: AnimatedScale(
          scale: visible ? 1.0 : 0.0,
          duration: reduce ? Duration.zero : MitlistAnimations.checkToggle,
          curve: MitlistAnimations.easeEnter,
          child: Transform.rotate(
            angle: -0.20,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MitlistSpacing.space2,
                vertical: MitlistSpacing.space0_5,
              ),
              decoration: BoxDecoration(
                color:
                    (dark ? MitlistColors.success950 : MitlistColors.success50)
                        .withValues(alpha: 0.92),
                border: Border.all(
                  color: dark
                      ? MitlistColors.success400
                      : MitlistColors.success700,
                  width: 2,
                ),
              ),
              child: Text(
                l10n.hubChecklistDone.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: dark
                          ? MitlistColors.success300
                          : MitlistColors.success800,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
