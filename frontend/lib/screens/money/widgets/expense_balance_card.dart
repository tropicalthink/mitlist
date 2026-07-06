import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/skeleton.dart';
import '../expense_format.dart';

/// The sticky top balance summary: "you owe" / "you are owed" headline, the
/// amount, and a tap-through to the settlements tab when suggestions exist.
class ExpenseBalanceCard extends StatelessWidget {
  final double balance;
  final String currency;
  final Color balanceColor;
  final bool isLoading;
  final int openBalanceCount;
  final int suggestionCount;
  final VoidCallback? onTap;

  const ExpenseBalanceCard({
    super.key,
    required this.balance,
    required this.currency,
    required this.balanceColor,
    required this.isLoading,
    required this.openBalanceCount,
    required this.suggestionCount,
    this.onTap,
  });

  String _headline(AppLocalizations l10n) {
    if (balance > 0) return l10n.expenseYouAreOwed;
    if (balance < 0) return l10n.expenseYouOwe;
    return l10n.expenseAllSquare;
  }

  String _description(AppLocalizations l10n) {
    if (suggestionCount > 0) {
      return l10n.expenseSuggestedPayments(suggestionCount);
    }
    if (openBalanceCount > 0) {
      return l10n.expenseOpenBalances(openBalanceCount);
    }
    return l10n.expenseNoOneOwes;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (isLoading) {
      return AppCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeleton(
                  width: MitlistSpacing.space14 * 2,
                  height: MitlistSpacing.space3,
                ),
                const SizedBox(height: MitlistSpacing.sm),
                const AppSkeleton(
                  width: MitlistSpacing.space16 * 2,
                  height: MitlistSpacing.space8,
                ),
              ],
            ),
            const AppSkeleton(
              width: MitlistSpacing.space14 * 2,
              height: MitlistSpacing.space6,
            ),
          ],
        ),
      );
    }

    final balanceStyle = Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontFamily: MitlistTypography.monoBody().fontFamily,
          color: balanceColor,
        );

    return AppCard(
      variant: AppCardVariant.soft,
      interactive: onTap != null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 340;
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_headline(l10n),
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: MitlistSpacing.xs),
                  Text(
                    _description(l10n),
                    maxLines: compact ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
              final amount = Text(
                formatExpenseCurrency(balance.abs(), currency: currency),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: compact ? TextAlign.start : TextAlign.end,
                style: balanceStyle,
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    details,
                    const SizedBox(height: MitlistSpacing.sm),
                    amount,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: MitlistSpacing.md),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: amount,
                    ),
                  ),
                ],
              );
            },
          ),
          // Settle-up action lives in the Settlements tab for now.
        ],
      ),
    );
  }
}
