import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/chore_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../sheets/create_list_sheet.dart';
import '../../sheets/invite_household_sheet.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../utils/haptics.dart';
import '../../widgets/board/cork_board.dart';

/// The landing beat of the first run: four small notes pinned at the top of
/// the hub, one per pillar. They aren't a tour — each one is stamped DONE by
/// the real thing happening (a flatmate joins, a list exists, a chore exists,
/// an expense exists), and the whole strip retires itself once the household
/// is actually going.
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

    final items = <_ChecklistItem>[
      _ChecklistItem(
        label: l10n.hubOnboardingInvite,
        icon: Icons.person_add_outlined,
        done: (memberCount ?? 0) > 1,
        noteColor: MitlistColors.notePeach,
        noteColorDark: MitlistColors.notePeachDark,
        onTap: () {
          Haptics.light();
          InviteHouseholdSheet.show(context, groupId: groupId);
        },
      ),
      _ChecklistItem(
        label: l10n.hubOnboardingCreateList,
        icon: Icons.checklist_outlined,
        done: lists.isNotEmpty,
        noteColor: MitlistColors.noteYellow,
        noteColorDark: MitlistColors.noteYellowDark,
        onTap: () {
          Haptics.light();
          CreateListSheet.show(context);
        },
      ),
      _ChecklistItem(
        label: l10n.hubOnboardingAddChore,
        icon: Icons.assignment_turned_in_outlined,
        done: chores.isNotEmpty,
        noteColor: MitlistColors.noteMint,
        noteColorDark: MitlistColors.noteMintDark,
        onTap: () {
          Haptics.light();
          context.goNamed('chores');
        },
      ),
      _ChecklistItem(
        label: l10n.hubOnboardingTrackExpense,
        icon: Icons.receipt_long_outlined,
        done: expenses.isNotEmpty,
        noteColor: MitlistColors.noteSky,
        noteColorDark: MitlistColors.noteSkyDark,
        onTap: () {
          Haptics.light();
          context.goNamed('money');
        },
      ),
    ];

    final doneCount = items.where((i) => i.done).length;

    // The household is going; the checklist's work is over.
    if (doneCount == items.length) return const SizedBox.shrink();

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
              l10n.hubChecklistProgress(doneCount, items.length),
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
                },
                tooltip: l10n.hubOnboardingDismiss,
              ),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = MitlistSpacing.space3;
            final noteW = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: MitlistSpacing.space4,
              children: [
                for (var i = 0; i < items.length; i++)
                  SizedBox(
                    width: noteW,
                    child: Transform.rotate(
                      angle: (i.isEven ? -1 : 1) * (0.014 + 0.006 * (i % 3)),
                      child: _ChecklistNote(item: items[i], l10n: l10n),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ChecklistItem {
  const _ChecklistItem({
    required this.label,
    required this.icon,
    required this.done,
    required this.noteColor,
    required this.noteColorDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool done;
  final Color noteColor;
  final Color noteColorDark;
  final VoidCallback onTap;
}

class _ChecklistNote extends StatelessWidget {
  const _ChecklistNote({required this.item, required this.l10n});

  final _ChecklistItem item;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? MitlistColors.neutral50 : MitlistColors.textPrimary;
    final reduce = MediaQuery.of(context).disableAnimations;

    return BoardPressable(
      semanticLabel:
          item.done ? '${item.label}. ${l10n.hubChecklistDone}' : item.label,
      onTap: item.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          StickyNoteSurface(
            color: dark ? item.noteColorDark : item.noteColor,
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.space3,
              MitlistSpacing.space4,
              MitlistSpacing.space3,
              MitlistSpacing.space3,
            ),
            child: AnimatedOpacity(
              opacity: item.done ? 0.55 : 1.0,
              duration: reduce ? Duration.zero : MitlistAnimations.medium,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 24, color: ink),
                  const SizedBox(height: MitlistSpacing.sm),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
          // The DONE stamp lands on the note the moment the real thing
          // happened, angled like a rubber stamp that didn't quite line up.
          Positioned(
            right: -4,
            top: MitlistSpacing.space3,
            child: IgnorePointer(
              child: AnimatedScale(
                scale: item.done ? 1.0 : 0.0,
                duration:
                    reduce ? Duration.zero : MitlistAnimations.checkToggle,
                curve: MitlistAnimations.easeEnter,
                child: Transform.rotate(
                  angle: -0.20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MitlistSpacing.space2,
                      vertical: MitlistSpacing.space0_5,
                    ),
                    decoration: BoxDecoration(
                      color: (dark
                              ? MitlistColors.success950
                              : MitlistColors.success50)
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
          ),
        ],
      ),
    );
  }
}
