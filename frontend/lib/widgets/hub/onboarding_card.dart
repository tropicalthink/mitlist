import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/app_areas_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../sheets/chore_creation_sheet.dart';
import '../../sheets/invite_household_sheet.dart';
import '../../theme/spacing.dart';
import '../../utils/haptics.dart';
import '../app_button.dart';
import '../app_card.dart';
import '../board/artifact_scraps.dart' show InviteSeats;
import 'hub_create_actions.dart';

/// Home's getting-started checklist (plans/048 stage 5), under Needs you.
///
/// A plain list of the first things a household does, each row launching
/// the real action. "Household created" starts ticked: people finish what
/// they have already started. The first-run intent answer moves its step to
/// the first open position. The header folds the card into a one-line bar
/// (remembered per household); there is no permanent dismiss, and the card
/// retires on its own once every step is done.
///
/// Someone who joined a household that is already in use gets the joiner's
/// version instead (stage 7): joined (ticked), tick something off a list,
/// take or complete a chore, check your balance. Joining a household that is
/// still empty shows the creator's steps, since there is setting up to do.
class HubQuickStart extends ConsumerWidget {
  const HubQuickStart({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final groupsAsync = ref.watch(cachedGroupsProvider);
    final listsAsync = ref.watch(cachedListsByGroupProvider(groupId));
    final choresAsync = ref.watch(cachedCurrentChoresByGroupProvider(groupId));
    final expensesAsync = ref.watch(cachedExpensesByGroupProvider(groupId));
    final prefsAsync = ref.watch(hubQuickStartPrefsProvider(groupId));

    // Don't flash a to-do list at an established household: wait until the
    // local caches have answered before deciding anything is "not done".
    if (!groupsAsync.hasValue ||
        !listsAsync.hasValue ||
        !choresAsync.hasValue ||
        !expensesAsync.hasValue ||
        !prefsAsync.hasValue) {
      return const SizedBox.shrink();
    }

    final group =
        groupsAsync.valueOrNull?.firstWhereOrNull((g) => g.id == groupId);
    final prefs = prefsAsync.value!;
    final areas = ref.watch(visibleAreasProvider);
    final inUse = listsAsync.value!.isNotEmpty ||
        choresAsync.value!.isNotEmpty ||
        expensesAsync.value!.isNotEmpty;
    final allSteps = prefs.joined && inUse
        ? _joinerSteps(context, l10n, prefs, group?.name ?? '')
        : _orderForIntent(
            [
              _Step(
                id: _StepId.household,
                title: l10n.hubChecklistHouseholdCreated,
                subtitle:
                    l10n.hubChecklistHouseholdCreatedSub(group?.name ?? ''),
                done: true,
              ),
              _Step(
                id: _StepId.invite,
                title: l10n.hubChecklistInvite,
                subtitle: l10n.hubChecklistInviteSub,
                done: prefs.invited || (group?.memberCount ?? 1) > 1,
                onTap: () async {
                  await markHubQuickStartInvited(groupId);
                  ref.invalidate(hubQuickStartPrefsProvider(groupId));
                  if (context.mounted) {
                    await InviteHouseholdSheet.show(context, groupId: groupId);
                  }
                },
              ),
              _Step(
                id: _StepId.list,
                area: AppArea.lists,
                title: l10n.hubOnboardingCreateList,
                subtitle: l10n.hubChecklistListSub,
                done: listsAsync.value!.isNotEmpty,
                onTap: () => createListAndOpen(context),
              ),
              _Step(
                id: _StepId.chore,
                area: AppArea.chores,
                title: l10n.hubOnboardingAddChore,
                subtitle: l10n.hubChecklistChoreSub,
                done: choresAsync.value!.isNotEmpty,
                onTap: () => ChoreCreationSheet.show(context),
              ),
              _Step(
                id: _StepId.expense,
                area: AppArea.money,
                title: l10n.hubOnboardingTrackExpense,
                subtitle: l10n.hubChecklistExpenseSub,
                done: expensesAsync.value!.isNotEmpty,
                onTap: () =>
                    addExpenseAndNotify(context, ref, groupId: groupId),
              ),
            ],
            prefs.intent,
          );
    // Only the parts of the app this person uses.
    final steps = [
      for (final step in allSteps)
        if (step.area == null || areas.contains(step.area)) step,
    ];

    final done = steps.where((s) => s.done).length;
    // Retired: the solo invite card takes over while nobody else is in.
    if (done == steps.length) return HubSoloInviteCard(groupId: groupId);

    void setCollapsed(bool collapsed) {
      unawaited(Haptics.light());
      unawaited(setHubQuickStartCollapsed(groupId, collapsed).then(
        (_) => ref.invalidate(hubQuickStartPrefsProvider(groupId)),
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.lg),
      child: prefs.collapsed
          ? _CollapsedBar(
              label: l10n.hubChecklistCollapsedBar(done, steps.length),
              onExpand: () => setCollapsed(false),
            )
          : _Checklist(
              steps: steps,
              done: done,
              onCollapse: () => setCollapsed(true),
            ),
    );
  }

  static List<_Step> _joinerSteps(
    BuildContext context,
    AppLocalizations l10n,
    HubQuickStartPrefs prefs,
    String householdName,
  ) =>
      [
        _Step(
          id: _StepId.joined,
          title: l10n.hubChecklistJoined(householdName),
          subtitle: l10n.hubChecklistJoinedSub,
          done: true,
        ),
        _Step(
          id: _StepId.tick,
          area: AppArea.lists,
          title: l10n.hubChecklistTick,
          subtitle: l10n.hubChecklistTickSub,
          done: prefs.done.contains(HubQuickStartStep.tick),
          onTap: () async => context.goNamed('lists'),
        ),
        _Step(
          id: _StepId.chore,
          area: AppArea.chores,
          title: l10n.hubChecklistDoChore,
          subtitle: l10n.hubChecklistDoChoreSub,
          done: prefs.done.contains(HubQuickStartStep.chore),
          onTap: () async => context.goNamed('chores'),
        ),
        _Step(
          id: _StepId.balance,
          area: AppArea.money,
          title: l10n.hubChecklistBalance,
          subtitle: l10n.hubChecklistBalanceSub,
          done: prefs.done.contains(HubQuickStartStep.balance),
          onTap: () async => context.goNamed('money'),
        ),
      ];

  /// Moves the step the person said they care about first to the first open
  /// position; done steps keep their place.
  static List<_Step> _orderForIntent(
    List<_Step> steps,
    HubQuickStartIntent? intent,
  ) {
    final wanted = switch (intent) {
      HubQuickStartIntent.lists => _StepId.list,
      HubQuickStartIntent.money => _StepId.expense,
      HubQuickStartIntent.chores => _StepId.chore,
      null => null,
    };
    final step = steps.firstWhereOrNull((s) => s.id == wanted);
    if (step == null || step.done) return steps;
    final rest = [...steps]..remove(step);
    final firstOpen = rest.indexWhere((s) => !s.done);
    return rest..insert(firstOpen == -1 ? rest.length : firstOpen, step);
  }
}

enum _StepId { household, invite, list, chore, expense, joined, tick, balance }

class _Step {
  const _Step({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.done,
    this.area,
    this.onTap,
  });

  final _StepId id;

  /// The part of the app the step belongs to; hidden with it. Null: always
  /// shown (the household itself, inviting people).
  final AppArea? area;
  final String title;
  final String subtitle;
  final bool done;
  final Future<void> Function()? onTap;
}

/// The checklist shows one thing to do, not five: the next open step with
/// its button, and the other open steps as quiet buttons under it. New
/// households told us a full list of to-dos on day one was too much.
class _Checklist extends StatelessWidget {
  const _Checklist({
    required this.steps,
    required this.done,
    required this.onCollapse,
  });

  final List<_Step> steps;
  final int done;
  final VoidCallback onCollapse;

  static void _run(_Step step) {
    unawaited(Haptics.light());
    unawaited(step.onTap!());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final open = steps.where((s) => !s.done && s.onTap != null).toList();
    final next = open.firstOrNull;
    final later = open.skip(1).toList();

    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.hubChecklistTitle,
                  style: textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                l10n.hubChecklistProgress(done, steps.length),
                style: textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              IconButton(
                icon: const Icon(Icons.expand_less),
                tooltip: l10n.hubChecklistCollapse,
                onPressed: onCollapse,
              ),
            ],
          ),
          _SegmentedProgress(done: done, total: steps.length),
          if (next != null) ...[
            const SizedBox(height: MitlistSpacing.md),
            Text(
              next.subtitle,
              style: textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: MitlistSpacing.md),
            Semantics(
              label: l10n.hubQuickStartNextSemantic(next.title),
              excludeSemantics: true,
              button: true,
              child: AppButton(
                key: ValueKey('quick-start-next-${next.id.name}'),
                size: AppButtonSize.lg,
                text: next.title,
                onPressed: () => _run(next),
              ),
            ),
          ],
          if (later.isNotEmpty) ...[
            const SizedBox(height: MitlistSpacing.sm),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: MitlistSpacing.xs,
              children: [
                Text(
                  l10n.hubChecklistLater,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                for (final step in later)
                  AppButton(
                    key: ValueKey('quick-start-later-${step.id.name}'),
                    variant: AppButtonVariant.ghost,
                    color: AppButtonColor.neutral,
                    size: AppButtonSize.sm,
                    text: step.title,
                    onPressed: () => _run(step),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One segment per step, filled for each one done.
class _SegmentedProgress extends StatelessWidget {
  const _SegmentedProgress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: MitlistSpacing.xs),
            Expanded(
              child: Container(
                height: MitlistSpacing.space1,
                color: i < done ? scheme.primary : scheme.outlineVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The folded checklist: one tappable line with the progress.
class _CollapsedBar extends StatelessWidget {
  const _CollapsedBar({required this.label, required this.onExpand});

  final String label;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.none,
      child: Semantics(
        button: true,
        expanded: false,
        label: '${l10n.hubChecklistExpand}. $label',
        excludeSemantics: true,
        child: InkWell(
          onTap: onExpand,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(minHeight: MitlistSpacing.space12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.expand_more),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "You're the only one here": shown once the quick start is finished while
/// the household still has one member (the checklist's own invite step asks
/// before that), and gone as soon as someone joins.
class HubSoloInviteCard extends ConsumerWidget {
  const HubSoloInviteCard({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref
        .watch(cachedGroupsProvider)
        .valueOrNull
        ?.firstWhereOrNull((g) => g.id == groupId);
    // Unknown member count: say nothing rather than guess.
    if (group?.memberCount != 1) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.lg),
      child: AppCard(
        variant: AppCardVariant.outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.hubSoloTitle,
              style: textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: MitlistSpacing.sm),
            ExcludeSemantics(
              child: InviteSeats(
                members: 1,
                emptyColor: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            Text(
              l10n.hubSoloBody,
              style:
                  textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: MitlistSpacing.md),
            Wrap(
              spacing: MitlistSpacing.sm,
              runSpacing: MitlistSpacing.sm,
              children: [
                AppButton(
                  text: l10n.hubSoloShare,
                  size: AppButtonSize.sm,
                  onPressed: () {
                    unawaited(Haptics.light());
                    unawaited(
                      InviteHouseholdSheet.shareLink(context, groupId: groupId),
                    );
                  },
                ),
                AppButton(
                  text: l10n.hubSoloShowCode,
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.outline,
                  onPressed: () {
                    unawaited(Haptics.light());
                    unawaited(
                      InviteHouseholdSheet.show(context, groupId: groupId),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
