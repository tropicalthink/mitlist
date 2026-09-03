import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/animated_check_toggle.dart';
import '../../widgets/animated_strikethrough.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/board/artifact_scraps.dart';
import '../../widgets/board/cork_board.dart';
import '../../widgets/chip.dart';
import '../money/expense_format.dart';
import 'tour_screen.dart';
import 'tour_state.dart';

/// Sample money is in dollars regardless of locale; the real household picks
/// its own currency when it is created.
String _money(int cents) => formatExpenseCurrency(cents / 100, currency: 'USD');

// ---------------------------------------------------------------------------
// Page 1 — why
// ---------------------------------------------------------------------------

/// The sample household as a pinwall: name, seats, a note, and the three
/// facts the next pages will each open up.
class TourWhyPage extends ConsumerWidget {
  const TourWhyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(tourSandboxProvider);
    final textTheme = Theme.of(context).textTheme;
    final toBuy = state.items.where((i) => !i.checked).length;
    final overdue = state.chores.where((c) => c.overdue).toList();

    return TourPageSheet(
      eyebrow: l10n.tourWhyEyebrow,
      headline: l10n.tourWhyHeadline,
      body: l10n.tourWhyBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  state.householdName,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              InviteSeats(members: state.members.length, seats: 3),
            ],
          ),
          const SizedBox(height: MitlistSpacing.space4),
          Transform.rotate(
            angle: -0.02,
            child: StickyNoteSurface(
              padding: const EdgeInsets.fromLTRB(
                MitlistSpacing.md,
                MitlistSpacing.space5,
                MitlistSpacing.md,
                MitlistSpacing.md,
              ),
              child: Text(
                l10n.tourWhyNote,
                style: textTheme.titleSmall?.copyWith(
                  color: stickyNoteInk(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: MitlistSpacing.space5),
          TourStatRow(
            icon: 'shoppingCart',
            text: '${state.listName} · ${l10n.tourWhyToBuy(toBuy)}',
          ),
          const SizedBox(height: MitlistSpacing.space2),
          TourStatRow(
            icon: 'banknotes',
            text: _overallLine(l10n, state.netBalanceCents),
          ),
          if (overdue.isNotEmpty) ...[
            const SizedBox(height: MitlistSpacing.space2),
            TourStatRow(
              icon: 'clipboardDocumentList',
              text: l10n.tourWhyOverdue(overdue.first.title),
              emphasis: true,
            ),
          ],
        ],
      ),
    );
  }
}

String _overallLine(AppLocalizations l10n, int netCents) {
  if (netCents > 0) return l10n.tourMoneyOverallOwed(_money(netCents));
  if (netCents < 0) return l10n.tourMoneyOverallOwe(_money(-netCents));
  return l10n.tourMoneyOverallSquare;
}

/// One fact about the household with an icon in front of it.
class TourStatRow extends StatelessWidget {
  const TourStatRow({
    super.key,
    required this.icon,
    required this.text,
    this.emphasis = false,
  });

  final String icon;
  final String text;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = emphasis ? colorScheme.error : colorScheme.onSurface;
    return Row(
      children: [
        AppIcon(name: icon, size: 18, color: color),
        const SizedBox(width: MitlistSpacing.space2),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2 — lists
// ---------------------------------------------------------------------------

class TourListsPage extends ConsumerStatefulWidget {
  const TourListsPage({super.key});

  @override
  ConsumerState<TourListsPage> createState() => _TourListsPageState();
}

class _TourListsPageState extends ConsumerState<TourListsPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    ref.read(tourSandboxProvider.notifier).addItem(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(tourSandboxProvider);
    final sandbox = ref.read(tourSandboxProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return TourPageSheet(
      eyebrow: l10n.tourListsEyebrow,
      headline: l10n.tourListsHeadline,
      body: l10n.tourListsBody,
      child: AppCard(
        variant: AppCardVariant.outlined,
        padding: AppCardPadding.sm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MitlistSpacing.sm,
                MitlistSpacing.xs,
                MitlistSpacing.sm,
                MitlistSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.listName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TourSampleTag(l10n.tourSampleTag),
                ],
              ),
            ),
            for (final item in state.items)
              _TourItemRow(
                key: ValueKey('tour-item-${item.id}'),
                item: item,
                onToggle: () => sandbox.toggleItem(item.id),
              ),
            const SizedBox(height: MitlistSpacing.sm),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: MitlistSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: AppInput(
                      hint: l10n.tourListsAddHint,
                      controller: _controller,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: MitlistSpacing.sm),
                  AppButton(
                    icon: const AppIcon(name: 'plus', size: 20),
                    variant: AppButtonVariant.solid,
                    color: AppButtonColor.primary,
                    size: AppButtonSize.md,
                    semanticLabel: l10n.tourListsAddHint,
                    onPressed: _add,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TourItemRow extends StatelessWidget {
  const _TourItemRow({super.key, required this.item, required this.onToggle});

  final TourListItem item;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant, width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: MitlistSpacing.sm,
          vertical: MitlistSpacing.sm,
        ),
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            AnimatedCheckToggle(
              value: item.checked,
              onChanged: (_) => onToggle(),
              semanticLabelOn: l10n.listItemMarkUnchecked(item.name),
              semanticLabelOff: l10n.listItemMarkChecked(item.name),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedStrikethrough(
                    text: item.name,
                    struck: item.checked,
                    style: textTheme.bodyLarge?.copyWith(height: 1.25),
                  ),
                  if (item.addedBy != null)
                    Text(
                      l10n.tourListsAddedBy(item.addedBy!),
                      style: MitlistTypography.labelXSmall(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small tag that says a card is sample content, so nobody wonders
/// whether Sam is real.
class TourSampleTag extends StatelessWidget {
  const TourSampleTag(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.space2,
        vertical: MitlistSpacing.space0_5,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant, width: 2),
      ),
      child: Text(
        text.toUpperCase(),
        style:
            MitlistTypography.labelXSmall(color: colorScheme.onSurfaceVariant)
                .copyWith(letterSpacing: 1.0),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 3 — money
// ---------------------------------------------------------------------------

class TourMoneyPage extends ConsumerWidget {
  const TourMoneyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(tourSandboxProvider);
    final sandbox = ref.read(tourSandboxProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final shares = state.pizzaSharesOwed;
    final net = state.netBalanceCents;

    return TourPageSheet(
      eyebrow: l10n.tourMoneyEyebrow,
      headline: l10n.tourMoneyHeadline,
      body: l10n.tourMoneyBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.md,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ExpenseHeader(
                  title: l10n.tourMoneyPizza,
                  amount: _money(state.pizzaCents),
                  paidBy: l10n.tourMoneyPaidByYou,
                ),
                const SizedBox(height: MitlistSpacing.space3),
                Text(
                  l10n.tourMoneySplitBetween,
                  style: MitlistTypography.labelXSmall(
                    color: colorScheme.onSurfaceVariant,
                  ).copyWith(letterSpacing: 0.8),
                ),
                const SizedBox(height: MitlistSpacing.space2),
                Wrap(
                  spacing: MitlistSpacing.space2,
                  runSpacing: MitlistSpacing.space2,
                  children: [
                    for (final member in state.members)
                      AppChip(
                        key: ValueKey('tour-split-${member.id}'),
                        label: member.name,
                        selected: state.pizzaSplit.contains(member.id),
                        // The payer is always in; the chip is a statement.
                        onSelected: member.id == state.me.id
                            ? null
                            : (_) => sandbox.togglePizzaShare(member.id),
                      ),
                  ],
                ),
                const SizedBox(height: MitlistSpacing.space3),
                if (shares.isEmpty)
                  Text(
                    l10n.tourMoneyJustYou,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (final entry in shares.entries)
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: MitlistSpacing.space1),
                      child: Text(
                        l10n.tourMoneyOwesYou(
                          state.member(entry.key).name,
                          _money(entry.value),
                        ),
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: MitlistSpacing.space3),
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.md,
            child: _ExpenseHeader(
              title: l10n.tourMoneyRepair,
              amount: _money(state.repairCents),
              paidBy: l10n.tourMoneyPaidBy(state.member(tourInesId).name),
            ),
          ),
          const SizedBox(height: MitlistSpacing.space4),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MitlistSpacing.space3,
              vertical: MitlistSpacing.space3,
            ),
            decoration: BoxDecoration(
              color: net >= 0 ? colorScheme.primary : colorScheme.error,
              border: Border.all(color: colorScheme.outline, width: 2),
            ),
            child: Text(
              _overallLine(l10n, net),
              key: const ValueKey('tour-overall'),
              style: textTheme.titleSmall?.copyWith(
                color: net >= 0 ? colorScheme.onPrimary : colorScheme.onError,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseHeader extends StatelessWidget {
  const _ExpenseHeader({
    required this.title,
    required this.amount,
    required this.paidBy,
  });

  final String title;
  final String amount;
  final String paidBy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                paidBy,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        Text(
          amount,
          style: MitlistTypography.monoBody(color: colorScheme.onSurface)
              .copyWith(fontSize: 18),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Page 4 — chores
// ---------------------------------------------------------------------------

class TourChoresPage extends ConsumerWidget {
  const TourChoresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(tourSandboxProvider);
    final sandbox = ref.read(tourSandboxProvider.notifier);

    return TourPageSheet(
      eyebrow: l10n.tourChoresEyebrow,
      headline: l10n.tourChoresHeadline,
      body: l10n.tourChoresBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final chore in state.chores) ...[
            _TourChoreRow(
              key: ValueKey('tour-chore-${chore.id}'),
              chore: chore,
              assignee: state.member(chore.assigneeId),
              isMine: chore.assigneeId == state.me.id,
              next: sandbox.nextInRotation(chore),
              onToggle: () => sandbox.toggleChore(chore.id),
            ),
            const SizedBox(height: MitlistSpacing.space2),
          ],
        ],
      ),
    );
  }
}

class _TourChoreRow extends StatelessWidget {
  const _TourChoreRow({
    super.key,
    required this.chore,
    required this.assignee,
    required this.isMine,
    required this.next,
    required this.onToggle,
  });

  final TourChore chore;
  final TourMember assignee;
  final bool isMine;
  final TourMember next;
  final VoidCallback onToggle;

  String _dueLabel(AppLocalizations l10n) {
    if (chore.dueInDays < 0) return l10n.tourChoresOverdue;
    if (chore.dueInDays == 0) return l10n.tourChoresDueToday;
    return l10n.tourChoresDueIn(chore.dueInDays);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final done = chore.done;
    final overdue = chore.overdue;
    final turnColor =
        isMine ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.sm,
      child: InkWell(
        onTap: onToggle,
        child: Row(
          children: [
            AnimatedCheckToggle(
              value: done,
              onChanged: (_) => onToggle(),
              semanticLabelOn: l10n.choreMarkNotDone(chore.title),
              semanticLabelOff: l10n.choreMarkDone(chore.title),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedStrikethrough(
                      text: chore.title,
                      struck: done,
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: MitlistSpacing.space1),
                    Wrap(
                      spacing: MitlistSpacing.sm,
                      runSpacing: MitlistSpacing.space1,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Meta(
                          icon: 'arrowPath',
                          label: l10n.tourChoresWeekly,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        if (!done)
                          _Meta(
                            dot: true,
                            label: isMine
                                ? l10n.tourChoresYourTurn
                                : l10n.tourChoresTurnOf(assignee.name),
                            color: turnColor,
                            emphasized: isMine,
                          ),
                      ],
                    ),
                    if (done)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: MitlistSpacing.space1),
                        child: Text(
                          l10n.tourChoresNext(next.name, chore.everyDays),
                          style: MitlistTypography.labelXSmall(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: MitlistSpacing.space6,
                  height: MitlistSpacing.space6,
                  decoration: BoxDecoration(
                    color: isMine
                        ? colorScheme.primary
                        : colorScheme.primaryContainer,
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    assignee.initials,
                    style: MitlistTypography.labelXSmall(
                      color: isMine
                          ? colorScheme.onPrimary
                          : colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: MitlistSpacing.space1),
                Text(
                  _dueLabel(l10n),
                  style: MitlistTypography.labelXSmall(
                    color: done
                        ? colorScheme.onSurfaceVariant
                        : overdue
                            ? colorScheme.error
                            : null,
                  ).copyWith(
                    fontWeight: overdue && !done ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    this.icon,
    this.dot = false,
    required this.label,
    required this.color,
    this.emphasized = false,
  });

  final String? icon;
  final bool dot;
  final String label;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot)
          Container(width: 6, height: 6, color: color)
        else if (icon != null)
          AppIcon(name: icon!, size: 12, color: color),
        const SizedBox(width: MitlistSpacing.space1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MitlistTypography.labelXSmall(color: color).copyWith(
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Page 5 — recipes
// ---------------------------------------------------------------------------

class TourRecipesPage extends ConsumerWidget {
  const TourRecipesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(tourSandboxProvider);
    final sandbox = ref.read(tourSandboxProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = stickyNoteInk(context);
    final toBuy = state.items.where((i) => !i.checked).length;

    void addIngredients() {
      sandbox.addRecipeIngredients();
      AppToast.success(
        context,
        l10n.tourRecipesAddedToast(
          tourRecipeIngredients.length,
          state.listName,
        ),
      );
    }

    return TourPageSheet(
      eyebrow: l10n.tourRecipesEyebrow,
      headline: l10n.tourRecipesHeadline,
      body: l10n.tourRecipesBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StickyNoteSurface(
            color: dark ? MitlistColors.noteSkyDark : MitlistColors.noteSky,
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.md,
              MitlistSpacing.space6,
              MitlistSpacing.md,
              MitlistSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tourRecipesTitle,
                  style: textTheme.titleLarge?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  l10n.tourRecipesServings,
                  style: textTheme.bodySmall?.copyWith(
                    color: ink.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: MitlistSpacing.space3),
                for (final ingredient in tourRecipeIngredients)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: MitlistSpacing.space1),
                    child: Row(
                      children: [
                        Container(width: 6, height: 6, color: ink),
                        const SizedBox(width: MitlistSpacing.space2),
                        Text(
                          ingredient,
                          style: textTheme.bodyMedium?.copyWith(color: ink),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: MitlistSpacing.space3),
                Row(
                  children: [
                    AppIcon(name: 'calendarDays', size: 16, color: ink),
                    const SizedBox(width: MitlistSpacing.space2),
                    Text(
                      l10n.tourRecipesPlanned,
                      style: textTheme.bodySmall?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: MitlistSpacing.space4),
                SizedBox(
                  width: double.infinity,
                  child: state.ingredientsAdded
                      ? AppButton(
                          key: const ValueKey('tour-ingredients-added'),
                          text: l10n.tourRecipesAddedButton,
                          icon: const AppIcon(name: 'check', size: 18),
                          variant: AppButtonVariant.outline,
                          color: AppButtonColor.neutral,
                          size: AppButtonSize.md,
                          onPressed: null,
                        )
                      : AppButton(
                          key: const ValueKey('tour-add-ingredients'),
                          text: l10n.tourRecipesAddIngredients,
                          icon: const AppIcon(name: 'plus', size: 18),
                          variant: AppButtonVariant.solid,
                          color: AppButtonColor.primary,
                          size: AppButtonSize.md,
                          onPressed: addIngredients,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MitlistSpacing.space4),
          TourStatRow(
            icon: 'shoppingCart',
            text: '${state.listName} · ${l10n.tourWhyToBuy(toBuy)}',
          ),
        ],
      ),
    );
  }
}
