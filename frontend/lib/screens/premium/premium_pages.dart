import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/billing_models.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/animated_check_toggle.dart';
import '../../widgets/animated_strikethrough.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/board/board_page_sheet.dart';
import '../../widgets/chip.dart';
import '../money/expense_format.dart';
import 'premium_sandbox.dart';

/// Sample money is in dollars regardless of locale, matching the feature tour:
/// the household's real currency belongs to its real expenses.
String _money(int cents) => formatExpenseCurrency(cents / 100, currency: 'USD');

// ---------------------------------------------------------------------------
// Page 1 — the seat that is missing
// ---------------------------------------------------------------------------

/// The only page drawn from the real household: how many places are used, and
/// the one that is not there yet. Everything after this is a sample.
class PremiumSeatsPage extends StatelessWidget {
  const PremiumSeatsPage({super.key, required this.entitlement});

  final HouseholdEntitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return BoardPageSheet(
      eyebrow: l10n.premiumSeatsEyebrow,
      headline: l10n.premiumSeatsHeadline,
      body: l10n.premiumSeatsBody(entitlement.freeLimit),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SeatStrip(taken: entitlement.memberCount),
          const SizedBox(height: MitlistSpacing.space4),
          Row(
            children: [
              AppIcon(
                name: 'userGroup',
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: MitlistSpacing.space2),
              Expanded(
                child: Text(
                  l10n.billingMemberUsage(
                    entitlement.memberCount,
                    entitlement.freeLimit,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The household as squares: the places that are taken, then the dashed one
/// that is not. Deliberately anonymous — this page is about the count, and
/// naming the person who cannot join yet would be a cheap shot.
class _SeatStrip extends StatelessWidget {
  const _SeatStrip({required this.taken});

  final int taken;

  /// Beyond this the strip stops drawing individual seats and says "+n", so a
  /// large household cannot push the open seat off the page.
  static const int _maxDrawn = 8;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final drawn = taken > _maxDrawn ? _maxDrawn : taken;
    final overflow = taken - drawn;

    return Wrap(
      spacing: MitlistSpacing.space2,
      runSpacing: MitlistSpacing.space2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < drawn; i++)
          Container(
            key: ValueKey('premium-seat-$i'),
            width: MitlistSpacing.space11,
            height: MitlistSpacing.space11,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              border: Border.all(color: scheme.outline, width: 2),
            ),
            alignment: Alignment.center,
            child: AppIcon(
              name: 'userCircle',
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
          ),
        if (overflow > 0)
          SizedBox(
            height: MitlistSpacing.space11,
            child: Center(
              child: Text(
                '+$overflow',
                style: MitlistTypography.monoBody(color: scheme.onSurface),
              ),
            ),
          ),
        // The open place: same size, drawn as an outline waiting to be filled.
        Semantics(
          label: l10n.premiumSeatsOpenPlace,
          child: DottedOutlineBox(
            size: MitlistSpacing.space11,
            child: AppIcon(name: 'userPlus', size: 20, color: scheme.primary),
          ),
        ),
      ],
    );
  }
}

/// A square drawn with a dashed border — the visual opposite of a filled seat.
class DottedOutlineBox extends StatelessWidget {
  const DottedOutlineBox({super.key, required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _DashedBorderPainter(color: scheme.primary),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    void run(Offset from, Offset to) {
      final total = (to - from).distance;
      if (total <= 0) return;
      final step = (to - from) / total;
      var travelled = 0.0;
      while (travelled < total) {
        final end = travelled + _dash;
        canvas.drawLine(
          from + step * travelled,
          from + step * (end > total ? total : end),
          paint,
        );
        travelled = end + _gap;
      }
    }

    final topLeft = Offset.zero;
    final topRight = Offset(size.width, 0);
    final bottomRight = Offset(size.width, size.height);
    final bottomLeft = Offset(0, size.height);
    run(topLeft, topRight);
    run(topRight, bottomRight);
    run(bottomRight, bottomLeft);
    run(bottomLeft, topLeft);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// Page 2 — lists
// ---------------------------------------------------------------------------

class PremiumListsPage extends ConsumerWidget {
  const PremiumListsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(premiumSandboxProvider);
    final sandbox = ref.read(premiumSandboxProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return BoardPageSheet(
      eyebrow: l10n.premiumListsEyebrow,
      headline: l10n.premiumListsHeadline,
      body: l10n.premiumListsBody,
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
                  PremiumSampleTag(l10n.tourSampleTag),
                ],
              ),
            ),
            for (final item in state.items)
              _PremiumItemRow(
                key: ValueKey('premium-item-${item.id}'),
                item: item,
                addedBy: item.addedById == null
                    ? null
                    : state.member(item.addedById!),
                onToggle: () => sandbox.toggleItem(item.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _PremiumItemRow extends StatelessWidget {
  const _PremiumItemRow({
    super.key,
    required this.item,
    required this.addedBy,
    required this.onToggle,
  });

  final PremiumListItem item;
  final PremiumMember? addedBy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final byNewcomer = addedBy?.isNewcomer ?? false;

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
                  if (addedBy != null)
                    Text(
                      l10n.tourListsAddedBy(addedBy!.name),
                      style: MitlistTypography.labelXSmall(
                        // The newcomer's contribution is the one the page is
                        // arguing for, so it is the one that is coloured in.
                        color: byNewcomer
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ).copyWith(
                        fontWeight: byNewcomer ? FontWeight.w700 : null,
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

/// The small tag that says a card is sample content, so nobody wonders whether
/// Mara is real.
class PremiumSampleTag extends StatelessWidget {
  const PremiumSampleTag(this.text, {super.key});

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

/// The arithmetic page. Chips add and remove people from a split and the
/// per-head figure moves underneath, so the value of one more person is a
/// number the reader worked out rather than a promise they were given.
class PremiumMoneyPage extends ConsumerWidget {
  const PremiumMoneyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(premiumSandboxProvider);
    final sandbox = ref.read(premiumSandboxProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return BoardPageSheet(
      eyebrow: l10n.premiumMoneyEyebrow,
      headline: l10n.premiumMoneyHeadline,
      body: l10n.premiumMoneyBody,
      child: AppCard(
        variant: AppCardVariant.outlined,
        padding: AppCardPadding.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.premiumMoneyExpense,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        l10n.tourMoneyPaidByYou,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MitlistSpacing.sm),
                Text(
                  _money(state.expenseCents),
                  style:
                      MitlistTypography.monoBody(color: colorScheme.onSurface)
                          .copyWith(fontSize: 18),
                ),
              ],
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
                    key: ValueKey('premium-split-${member.id}'),
                    label: member.name,
                    selected: state.expenseSplit.contains(member.id),
                    // The payer is always in; their chip is a statement.
                    onSelected: member.id == state.me.id
                        ? null
                        : (_) => sandbox.toggleShare(member.id),
                  ),
              ],
            ),
            const SizedBox(height: MitlistSpacing.space4),
            Container(
              key: const ValueKey('premium-share-line'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: MitlistSpacing.space3,
                vertical: MitlistSpacing.space3,
              ),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                border: Border.all(color: colorScheme.outline, width: 2),
              ),
              child: Text(
                l10n.premiumMoneySplitLine(
                  state.splitWays,
                  _money(state.shareEachCents),
                ),
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 4 — chores
// ---------------------------------------------------------------------------

/// The other half of the arithmetic: a rota over more people is a rota that
/// reaches you less often. Ticking a chore off hands it on, so the reader can
/// watch their own name recede.
class PremiumChoresPage extends ConsumerWidget {
  const PremiumChoresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(premiumSandboxProvider);
    final sandbox = ref.read(premiumSandboxProvider.notifier);

    return BoardPageSheet(
      eyebrow: l10n.premiumChoresEyebrow,
      headline: l10n.premiumChoresHeadline,
      body: l10n.premiumChoresBody(state.rotaSize),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final chore in state.chores) ...[
            _PremiumChoreRow(
              key: ValueKey('premium-chore-${chore.id}'),
              chore: chore,
              assignee: state.member(chore.assigneeId),
              isMine: chore.assigneeId == state.me.id,
              rotaSize: state.rotaSize,
              onToggle: () => sandbox.completeChore(chore.id),
            ),
            const SizedBox(height: MitlistSpacing.space2),
          ],
        ],
      ),
    );
  }
}

class _PremiumChoreRow extends StatelessWidget {
  const _PremiumChoreRow({
    super.key,
    required this.chore,
    required this.assignee,
    required this.isMine,
    required this.rotaSize,
    required this.onToggle,
  });

  final PremiumChore chore;
  final PremiumMember assignee;
  final bool isMine;
  final int rotaSize;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
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
              value: chore.done,
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
                      struck: chore.done,
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: MitlistSpacing.space1),
                    Text(
                      isMine
                          ? l10n.tourChoresYourTurn
                          : l10n.tourChoresTurnOf(assignee.name),
                      style: MitlistTypography.labelXSmall(color: turnColor)
                          .copyWith(
                        fontWeight: isMine ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    if (chore.done)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: MitlistSpacing.space1),
                        child: Text(
                          l10n.premiumChoresTurnEvery(rotaSize),
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
            Container(
              width: MitlistSpacing.space6,
              height: MitlistSpacing.space6,
              decoration: BoxDecoration(
                color:
                    isMine ? colorScheme.primary : colorScheme.primaryContainer,
                border: Border.all(color: colorScheme.outlineVariant, width: 2),
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
          ],
        ),
      ),
    );
  }
}
