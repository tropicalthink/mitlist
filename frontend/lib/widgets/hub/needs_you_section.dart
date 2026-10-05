import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/auth_models.dart';
import '../../models/chore_models.dart';
import '../../models/finance_models.dart';
import '../../models/pinwall_models.dart';
import '../../providers/chore_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/pinwall_provider.dart';
import '../../screens/lists/list_detail_screen.dart' show ListDetailRouteArgs;
import '../../screens/money/expense_format.dart';
import '../../screens/pinwall/pinwall_board_screen.dart';
import '../../sheets/settlement_confirmation_dialog.dart';
import '../../theme/spacing.dart';
import '../../utils/haptics.dart';
import '../../services/product_events.dart';
import '../../utils/home_summary.dart';
import '../app_button.dart';
import '../app_card.dart';
import '../app_toast.dart';
import '../pinwall/pinwall_stat_rows.dart';
import '../skeleton.dart';

/// At most this many rows; everything else lives on its tab.
@visibleForTesting
const int kNeedsYouMaxRows = 5;

/// Chores take at most this many rows, so a backlog cannot push what the
/// caller owes and today's reminders out of the card.
const int _maxChoreRows = 3;

/// The top of Home: what needs the signed-in member right now
/// (plans/048 stage 4). Up to [kNeedsYouMaxRows] rows, each labelled with its
/// feature and carrying one action, then the three count tiles.
///
/// Built from the household's cached data rather than a request of its own,
/// so it paints offline and follows every local write: ticking a chore off
/// here or on the Chores tab removes its row at once.
class NeedsYouSection extends ConsumerStatefulWidget {
  const NeedsYouSection({super.key, required this.groupId, required this.me});

  final String groupId;
  final User? me;

  @override
  ConsumerState<NeedsYouSection> createState() => _NeedsYouSectionState();
}

class _NeedsYouSectionState extends ConsumerState<NeedsYouSection> {
  /// Rows whose action is running, so a second tap does nothing.
  final Set<String> _busy = {};

  String get _groupId => widget.groupId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chores = ref.watch(cachedCurrentChoresByGroupProvider(_groupId));
    final finance = ref.watch(cachedFinanceSummaryByGroupProvider(_groupId));
    final lists = ref.watch(cachedListsByGroupProvider(_groupId));

    // Chores, money and lists decide the card; wait for their caches.
    final core = [chores, finance, lists];
    if (core.any((a) => a.hasError && !a.hasValue)) {
      return _NeedsYouCard(child: _LoadError(onRetry: _retry));
    }
    if (core.any((a) => !a.hasValue)) return const _NeedsYouSkeleton();

    // The rest only add rows; they are shown once they answer, never waited on.
    final counts =
        ref.watch(listItemCountsProvider(_groupId)).valueOrNull ?? const {};
    final settlements =
        ref.watch(cachedSettlementsByGroupProvider(_groupId)).valueOrNull ??
            const <Settlement>[];
    final meals = ref.watch(todayMealPlansProvider(_groupId)).valueOrNull ??
        const <TodayMeal>[];
    final posts =
        ref.watch(pinwallPostsByGroupProvider(_groupId)).valueOrNull ??
            const <PinwallPost>[];
    final currency = ref
            .watch(cachedGroupsProvider)
            .valueOrNull
            ?.firstWhereOrNull((g) => g.id == _groupId)
            ?.currency ??
        'USD';

    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final userId = widget.me?.id;
    final rows = <_RowData>[];

    final mine = choresOnMe(chores.value!, now);
    for (final c in [...mine.overdue, ...mine.dueToday].take(_maxChoreRows)) {
      final due = c.pendingAssignment!.dueDate!.toLocal();
      final daysLate =
          today.difference(DateTime(due.year, due.month, due.day)).inDays;
      rows.add(_RowData(
        id: 'chore:${c.chore.id}',
        kind: l10n.needsYouKindChore,
        accent: daysLate > 0 ? scheme.error : scheme.secondary,
        title: c.chore.name,
        detail: daysLate > 0
            ? l10n.needsYouOverdueDays(daysLate)
            : l10n.needsYouDueToday,
        action: l10n.commonDone,
        onAction: () => _complete(c),
        onTap: () => context.goNamed('chores'),
      ));
    }

    final debt = largestDebt(finance.value, settlements, userId);
    if (debt != null) {
      rows.add(_RowData(
        id: 'money:${debt.toUserId}',
        kind: l10n.needsYouKindMoney,
        accent: scheme.error,
        title: debt.toDisplayName,
        detail: l10n.hubBalanceYouOwe(
          formatExpenseCurrency(debt.amount / 100, currency: currency),
        ),
        action: l10n.needsYouSettle,
        onAction: () => _settle(debt, currency),
        onTap: () => context.goNamed('money'),
      ));
    }

    final reminder = remindersLaterToday(posts, now).firstOrNull;
    if (reminder != null) {
      void openBoard() {
        _trackAction('reminder_open');
        PinwallBoardScreen.show(
          context,
          groupId: _groupId,
          me: widget.me,
          posts: posts,
        );
      }

      rows.add(_RowData(
        id: 'reminder:${reminder.id}',
        kind: l10n.needsYouKindReminder,
        accent: scheme.primary,
        title: reminder.content.split('\n').first,
        detail: l10n.needsYouReminderAt(
          DateFormat.jm(Localizations.localeOf(context).toString())
              .format(reminder.remindAt!.toLocal()),
        ),
        action: l10n.needsYouOpen,
        onAction: openBoard,
        onTap: openBoard,
      ));
    }

    // Everything above is on the caller; what follows is the house's.
    final onYou = rows.length;
    final items = openListItems(lists.value!, counts);
    final hasData = chores.value!.isNotEmpty ||
        myBalance(finance.value, userId).hasExpenses ||
        items.total > 0;

    // Someone who joined a household in use has nothing on them yet; show
    // what the house is working on instead of an empty card (plans/048
    // stage 7). Joining an empty household reads "Not set up yet", as it
    // does for its creator.
    final joined =
        ref.watch(hubQuickStartPrefsProvider(_groupId)).valueOrNull?.joined ??
            false;
    final freshJoiner = onYou == 0 && hasData && joined;
    if (freshJoiner) {
      final houseChores = [
        for (final c in chores.value!)
          if (!c.assignedToMe &&
              c.pendingAssignment?.status != 'completed' &&
              c.pendingAssignment?.dueDate != null &&
              c.pendingAssignment!.dueDate!.isBefore(
                today.add(const Duration(days: 1)),
              ))
            c,
      ]..sort((a, b) => a.pendingAssignment!.dueDate!
          .compareTo(b.pendingAssignment!.dueDate!));
      for (final c in houseChores.take(2)) {
        final due = c.pendingAssignment!.dueDate!.toLocal();
        final daysLate =
            today.difference(DateTime(due.year, due.month, due.day)).inDays;
        rows.add(_RowData(
          id: 'house-chore:${c.chore.id}',
          kind: l10n.needsYouKindChore,
          accent: scheme.onSurfaceVariant,
          title: c.chore.name,
          detail:
              '${daysLate > 0 ? l10n.needsYouOverdueDays(daysLate) : l10n.needsYouDueToday}'
              ' · ${l10n.needsYouNotYourTurn}',
          onTap: () => context.goNamed('chores'),
        ));
      }
    }

    final busiest = items.busiest;
    if (busiest != null) {
      void openList() {
        _trackAction('list_open');
        context.pushNamed(
          'listDetail',
          pathParameters: {'listId': busiest.id},
          extra: ListDetailRouteArgs(listName: busiest.name),
        );
      }

      rows.add(_RowData(
        id: 'list:${busiest.id}',
        kind: l10n.needsYouKindList,
        accent: scheme.primary,
        title: busiest.name,
        detail: l10n.hubStatsItemsLeft(items.busiestOpen),
        action: l10n.needsYouOpen,
        onAction: openList,
        onTap: openList,
      ));
    }

    final tonight = _tonightsMeal(meals);
    if (tonight != null) {
      void openMealPlan() {
        _trackAction('meal_open');
        context.pushNamed('mealPlan');
      }

      rows.add(_RowData(
        id: 'meal:${tonight.plan.id}',
        kind: l10n.navKitchen,
        accent: scheme.tertiary,
        title: tonight.recipe?.title ?? l10n.tonightRecipe,
        detail: l10n.tonightHeader,
        action: l10n.needsYouOpen,
        onAction: openMealPlan,
        onTap: openMealPlan,
      ));
    }

    return _NeedsYouCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (freshJoiner)
            _ZeroState(
              key: const ValueKey('needs-you-nothing-yet'),
              icon: Icons.waving_hand_outlined,
              title: l10n.needsYouNothingYet,
              description: l10n.needsYouNothingYetDesc,
            )
          else if (onYou == 0)
            hasData
                ? _ZeroState(
                    key: const ValueKey('needs-you-caught-up'),
                    icon: Icons.check_circle_outline,
                    title: l10n.needsYouAllCaughtUp,
                    description: l10n.needsYouAllCaughtUpDesc,
                  )
                : _ZeroState(
                    key: const ValueKey('needs-you-not-set-up'),
                    icon: Icons.flag_outlined,
                    title: l10n.needsYouNotSetUp,
                    description: l10n.needsYouNotSetUpDesc,
                  ),
          for (final (i, row) in rows.take(kNeedsYouMaxRows).indexed) ...[
            if (i > 0 || onYou == 0)
              Divider(height: 1, color: scheme.outlineVariant),
            _NeedsYouRow(
              key: ValueKey('needs-you-${row.id}'),
              data: row,
              busy: _busy.contains(row.id),
            ),
          ],
          Divider(height: MitlistSpacing.md, color: scheme.outlineVariant),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PinwallChoresStatRow(
                  groupId: _groupId,
                  style: PinwallStatRowStyle.tile,
                  ink: scheme.onSurface,
                  muted: scheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: PinwallFinanceStatRow(
                  groupId: _groupId,
                  currentUserId: userId,
                  style: PinwallStatRowStyle.tile,
                  ink: scheme.onSurface,
                  muted: scheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: PinwallListsStatRow(
                  groupId: _groupId,
                  style: PinwallStatRowStyle.tile,
                  ink: scheme.onSurface,
                  muted: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Product events (plans/048 stage 8): which Needs you action was used.
  void _trackAction(String type) => ProductEvents.instance.track(
        ProductEventName.homeNeedsYouAction,
        groupId: _groupId,
        props: {'type': type},
      );

  void _retry() {
    ref.invalidate(cachedCurrentChoresByGroupProvider(_groupId));
    ref.invalidate(cachedFinanceSummaryByGroupProvider(_groupId));
    ref.invalidate(cachedListsByGroupProvider(_groupId));
  }

  /// Dinner first, then breakfast or lunch: the same pick the old "Tonight"
  /// line made.
  TodayMeal? _tonightsMeal(List<TodayMeal> meals) {
    for (final slot in const ['dinner', 'breakfast', 'lunch']) {
      final meal = meals.firstWhereOrNull((m) => m.plan.slot == slot);
      if (meal != null) return meal;
    }
    return meals.firstOrNull;
  }

  /// The Chores tab's write path: an optimistic local completion queued for
  /// the outbox, so it works offline and the row leaves at once.
  Future<void> _complete(CurrentChore chore) async {
    final id = 'chore:${chore.chore.id}';
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    final l10n = AppLocalizations.of(context)!;
    try {
      unawaited(Haptics.success());
      final repo = await ref.read(choreRepositoryProvider.future);
      await repo.completeOfflineFirst(chore.chore.id, groupId: _groupId);
      _trackAction('chore_done');
      unawaited(markHubQuickStartStep(_groupId, HubQuickStartStep.chore).then(
        (_) => ref.invalidate(hubQuickStartPrefsProvider(_groupId)),
      ));
      if (!mounted) return;
      AppToast.undo(
        context,
        message: l10n.choreDoneSnackbar(chore.chore.name),
        onUndo: () async {
          try {
            await repo.undoOfflineFirst(chore.chore.id, groupId: _groupId);
          } catch (_) {
            if (mounted) AppToast.error(context, l10n.choreFailedUndo);
          }
        },
      );
    } catch (_) {
      if (!mounted) return;
      unawaited(Haptics.failure());
      AppToast.error(context, l10n.choreFailedComplete);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  /// The Money tab's settle flow: confirm, then queue the settlement offline
  /// first. It waits for the other person's confirmation, and the row leaves
  /// because that pair now has a pending settlement.
  Future<void> _settle(ReimbursementSuggestion debt, String currency) async {
    final me = widget.me;
    final id = 'money:${debt.toUserId}';
    if (me == null || _busy.contains(id)) return;
    final l10n = AppLocalizations.of(context)!;
    unawaited(Haptics.light());
    final confirmed = await SettlementConfirmationDialog.show(
      context: context,
      amount: formatExpenseCurrency(debt.amount / 100, currency: currency),
      payer: l10n.activityYou,
      payee: debt.toDisplayName,
      payerIsMe: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy.add(id));
    try {
      final repo = await ref.read(financeRepositoryProvider.future);
      await repo.recordSettlementOfflineFirst(
        groupId: _groupId,
        req: CreateSettlementRequest(
          fromUserId: debt.fromUserId,
          toUserId: debt.toUserId,
          amount: debt.amount,
        ),
        createdBy: me.id,
      );
      _trackAction('money_settle');
      if (!mounted) return;
      unawaited(Haptics.success());
      AppToast.success(context, l10n.expenseSettlementRecorded);
    } catch (_) {
      if (mounted) AppToast.error(context, l10n.expenseSettlementFailed);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }
}

class _RowData {
  const _RowData({
    required this.id,
    required this.kind,
    required this.accent,
    required this.title,
    required this.detail,
    this.action,
    this.onAction,
    required this.onTap,
  });

  final String id;
  final String kind;
  final Color accent;
  final String title;
  final String detail;

  /// Null for a row shown for information only (a housemate's chore).
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback onTap;
}

class _NeedsYouCard extends StatelessWidget {
  const _NeedsYouCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.needsYouTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: MitlistSpacing.xs),
          child,
        ],
      ),
    );
  }
}

/// One thing that needs the caller: the feature it belongs to, what it is,
/// and the single action that deals with it. Tapping the row itself opens
/// the feature.
class _NeedsYouRow extends StatelessWidget {
  const _NeedsYouRow({super.key, required this.data, required this.busy});

  final _RowData data;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        unawaited(Haptics.light());
        data.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.kind.toUpperCase(),
                    style: textTheme.labelSmall?.copyWith(
                      color: data.accent,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    data.title,
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    data.detail,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (data.action != null) ...[
              const SizedBox(width: MitlistSpacing.sm),
              AppButton(
                text: data.action,
                size: AppButtonSize.sm,
                variant: AppButtonVariant.outline,
                isLoading: busy,
                onPressed: busy ? null : data.onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "All caught up" (the household is in use, nothing is on the caller) or
/// "Not set up yet" (nothing recorded at all): two different messages, so a
/// new household is not congratulated for having nothing in it.
class _ZeroState extends StatelessWidget {
  const _ZeroState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: scheme.tertiary),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  description,
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.needsYouLoadError,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        AppButton(
          text: l10n.commonRetry,
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.sm,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _NeedsYouSkeleton extends StatelessWidget {
  const _NeedsYouSkeleton();

  @override
  Widget build(BuildContext context) {
    return const _NeedsYouCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: MitlistSpacing.sm),
          AppSkeleton(width: 220, height: 14),
          SizedBox(height: MitlistSpacing.sm),
          AppSkeleton(width: 160, height: 14),
          SizedBox(height: MitlistSpacing.md),
          Row(
            children: [
              Expanded(child: AppSkeleton(width: 60, height: 40)),
              SizedBox(width: MitlistSpacing.sm),
              Expanded(child: AppSkeleton(width: 60, height: 40)),
              SizedBox(width: MitlistSpacing.sm),
              Expanded(child: AppSkeleton(width: 60, height: 40)),
            ],
          ),
        ],
      ),
    );
  }
}
