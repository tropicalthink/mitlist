import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/empty_state.dart';
import '../expense_format.dart';
import '../expenses_controller.dart';

/// The Settlements tab: suggested payments to close open balances, plus the
/// full per-member balance breakdown.
class ExpenseSettlementsBody extends StatelessWidget {
  final List<SettlementSuggestionDisplay> suggestions;
  final List<BalanceDisplayEntry> balances;
  final String currency;
  final bool isSettling;
  final ConfettiController confettiController;
  final Future<void> Function() onRefresh;
  final ValueChanged<SettlementSuggestionDisplay> onRecordSettlement;

  const ExpenseSettlementsBody({
    super.key,
    required this.suggestions,
    required this.balances,
    required this.currency,
    required this.isSettling,
    required this.confettiController,
    required this.onRefresh,
    required this.onRecordSettlement,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.expenseSuggestedPaymentsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: MitlistSpacing.xs),
            Text(
              l10n.expenseSuggestedPaymentsDesc,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: MitlistSpacing.md),
            if (suggestions.isNotEmpty)
              ...suggestions.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
                  child: _SuggestionCard(
                    suggestion: s,
                    currency: currency,
                    isSettling: isSettling,
                    onRecord: () => onRecordSettlement(s),
                  ),
                ),
              )
            else
              Stack(
                alignment: Alignment.center,
                children: [
                  AppEmptyState(
                    lottieAsset: 'assets/animations/lottie/Checkmark.lottie',
                    icon: const AppIcon(name: 'checkCircle', size: 56),
                    title: l10n.expenseAllSettled,
                    description: l10n.expenseNoOneOwesRight,
                  ),
                  ConfettiWidget(
                    confettiController: confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    numberOfParticles: 20,
                    maxBlastForce: 20,
                    minBlastForce: 10,
                    gravity: 0.3,
                  ),
                ],
              ),
            const SizedBox(height: MitlistSpacing.md),
            _BalancesSection(balances: balances, currency: currency),
            const SizedBox(height: MitlistSpacing.space12),
          ],
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final SettlementSuggestionDisplay suggestion;
  final String currency;
  final bool isSettling;
  final VoidCallback onRecord;

  const _SuggestionCard({
    required this.suggestion,
    required this.currency,
    required this.isSettling,
    required this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      variant: AppCardVariant.elevated,
      animated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Spacer(),
              Text(
                formatExpenseCurrency(suggestion.amount, currency: currency),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MitlistTypography.monoBody(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: MitlistSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final from = _SettlementParty(
                label: suggestion.fromLabel,
                helper: suggestion.from == suggestion.to
                    ? l10n.expenseSameAccount
                    : l10n.expenseFrom,
                tone: Theme.of(context).colorScheme.error,
              );
              final to = _SettlementParty(
                label: suggestion.toLabel,
                helper: l10n.expenseTo,
                tone: Theme.of(context).colorScheme.tertiary,
              );

              if (compact) {
                return Column(
                  children: [
                    from,
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: MitlistSpacing.sm),
                      child: AppIcon(name: 'arrowDown', size: 20),
                    ),
                    to,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: from),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: MitlistSpacing.sm),
                    child: AppIcon(name: 'arrowRight', size: 20),
                  ),
                  Expanded(child: to),
                ],
              );
            },
          ),
          const SizedBox(height: MitlistSpacing.md),
          Text(
            l10n.expenseRecordHelper,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: MitlistSpacing.md),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              variant: AppButtonVariant.solid,
              color: AppButtonColor.success,
              text: isSettling
                  ? l10n.expenseRecording
                  : l10n.expenseRecordSettlement,
              isLoading: isSettling,
              onPressed: isSettling ? null : onRecord,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettlementParty extends StatelessWidget {
  final String label;
  final String helper;
  final Color tone;

  const _SettlementParty({
    required this.label,
    required this.helper,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: MitlistSpacing.space14),
      padding: const EdgeInsets.all(MitlistSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            helper,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tone,
                ),
          ),
          const SizedBox(height: MitlistSpacing.xs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _BalancesSection extends StatelessWidget {
  final List<BalanceDisplayEntry> balances;
  final String currency;

  const _BalancesSection({required this.balances, required this.currency});

  Color _balanceColor(BuildContext context, double amount) {
    if (amount > 0) return Theme.of(context).colorScheme.tertiary;
    if (amount < 0) return Theme.of(context).colorScheme.error;
    return Theme.of(context).colorScheme.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    final sortedBalances = [...balances]
      ..sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.none,
      child: _BalancesExpandableBody(
        sortedBalances: sortedBalances,
        openCount: balances.where((b) => b.amount != 0).length,
        balanceColor: _balanceColor,
        currency: currency,
      ),
    );
  }
}

class _BalancesExpandableBody extends StatefulWidget {
  final List<BalanceDisplayEntry> sortedBalances;
  final int openCount;
  final Color Function(BuildContext, double) balanceColor;
  final String currency;

  const _BalancesExpandableBody({
    required this.sortedBalances,
    required this.openCount,
    required this.balanceColor,
    required this.currency,
  });

  @override
  State<_BalancesExpandableBody> createState() =>
      _BalancesExpandableBodyState();
}

class _BalancesExpandableBodyState extends State<_BalancesExpandableBody> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Column(
      children: [
        Semantics(
          button: true,
          label: _expanded
              ? l10n.expenseCollapseBalances
              : l10n.expenseExpandBalances,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MitlistSpacing.md,
                vertical: MitlistSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.expenseBalances,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  Text(
                    l10n.expenseBalancesOpen(widget.openCount),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: MitlistSpacing.sm),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: AppIcon(name: 'chevronDown', size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.md,
              MitlistSpacing.sm,
              MitlistSpacing.md,
              MitlistSpacing.sm,
            ),
            child: widget.sortedBalances.isEmpty
                ? Text(
                    l10n.expenseNoBalances,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : Column(
                    children: [
                      for (final b in widget.sortedBalances)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: MitlistSpacing.sm),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                    Text(
                                      b.amount > 0
                                          ? l10n.expenseIsOwed
                                          : b.amount < 0
                                              ? l10n.expenseOwes
                                              : l10n.expenseSettled,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: MitlistSpacing.md),
                              Text(
                                formatExpenseCurrency(b.amount.abs(),
                                    currency: widget.currency),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MitlistTypography.monoBody(
                                  color: widget.balanceColor(context, b.amount),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 180),
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeOutCubic,
          sizeCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }
}
