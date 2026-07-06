import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/spacing.dart';
import '../../../theme/typography.dart';
import '../../../widgets/alert.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_icon.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/list_entrance.dart';
import '../../../widgets/spinner.dart';
import '../expense_format.dart';
import '../expenses_controller.dart';

/// The Timeline tab: day-bucketed sticky-header list of expenses, with
/// pull-to-refresh and infinite scroll (via [controller]).
class ExpenseTimelineBody extends StatelessWidget {
  final List<ExpenseGroupDisplay> groups;
  final ScrollController controller;
  final bool isLoadingMore;
  final bool hasPageError;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddExpense;
  final ValueChanged<ExpenseDisplay> onOpenExpense;

  const ExpenseTimelineBody({
    super.key,
    required this.groups,
    required this.controller,
    required this.isLoadingMore,
    required this.hasPageError,
    required this.onRefresh,
    required this.onAddExpense,
    required this.onOpenExpense,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (groups.isEmpty) {
      return RefreshIndicator(
        color: Theme.of(context).colorScheme.primary,
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(MitlistSpacing.md),
                  child: AppEmptyState(
                    lottieAsset: 'assets/animations/lottie/wallet.lottie',
                    icon: AppIcon(name: 'receiptPercent', size: 56),
                    title: l10n.expenseNoExpensesTitle,
                    description: l10n.expenseNoExpensesDesc,
                    actions: [
                      AppButton(
                        text: l10n.expenseAddFirstExpense,
                        onPressed: onAddExpense,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: controller,
        slivers: [
          for (final group in groups) ...[
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyDateHeaderDelegate(
                height: MitlistSpacing.space10,
                child: Container(
                  color: Theme.of(context).colorScheme.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: MitlistSpacing.md,
                  ),
                  alignment: Alignment.centerLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        group.label,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: MitlistSpacing.md,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final expense = group.expenses[index];
                    return ListEntrance(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: MitlistSpacing.sm,
                        ),
                        child: _ExpenseCard(
                          expense: expense,
                          onTap: () => onOpenExpense(expense),
                        ),
                      ),
                    );
                  },
                  childCount: group.expenses.length,
                ),
              ),
            ),
          ],
          if (isLoadingMore || hasPageError)
            SliverPadding(
              padding: const EdgeInsets.all(MitlistSpacing.md),
              sliver: SliverToBoxAdapter(
                child: hasPageError
                    ? AppAlert(
                        type: AppAlertType.error,
                        message: l10n.expenseLoadMoreError,
                      )
                    : Center(
                        child: AppSpinner(
                          size: AppSpinnerSize.sm,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: MitlistSpacing.space12),
          ),
        ],
      ),
    );
  }
}

class _StickyDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyDateHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyDateHeaderDelegate oldDelegate) => true;
}

class _PayerBadge extends StatelessWidget {
  final String label;
  const _PayerBadge({required this.label});

  String get _initials {
    final parts = label.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters =
        parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MitlistSpacing.space10,
      height: MitlistSpacing.space10,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final ExpenseDisplay expense;
  final VoidCallback onTap;

  const _ExpenseCard({required this.expense, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      variant: AppCardVariant.outlined,
      interactive: true,
      onTap: onTap,
      semanticLabel:
          '${expense.description}, ${formatExpenseCurrency(expense.amount, currency: expense.currency)}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PayerBadge(label: expense.payer),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: MitlistSpacing.space1),
                Text(
                  expense.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: MitlistSpacing.space1),
                Text(
                  l10n.expensePaidBy(expense.payer),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: MitlistSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatExpenseCurrency(expense.amount, currency: expense.currency),
                style: MitlistTypography.monoBody(),
              ),
              if (expense.isConverted) ...[
                const SizedBox(height: MitlistSpacing.space1),
                Text(
                  l10n.expenseConvertedAmount(formatExpenseCurrency(
                      expense.baseAmount,
                      currency: expense.baseCurrency)),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
