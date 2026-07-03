import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/app_localizations.dart';
import '../../router.dart' show BottomNavScaffold, currentGroupIdProvider;
import '../../utils/shell_tab_load.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../sheets/expense_creation_sheet.dart';
import '../../sheets/expense_detail_sheet.dart';
import '../../sheets/settlement_confirmation_dialog.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/spinner.dart';
import '../../widgets/list_entrance.dart';
import '../../widgets/mitlist_app_bar.dart';
import 'expenses_controller.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final Map<String, NumberFormat> _currencyFormats = {};

String _formatCurrency(double value, {String currency = 'USD'}) {
  final key = currency.trim().isEmpty ? 'USD' : currency.trim().toUpperCase();
  final formatter = _currencyFormats.putIfAbsent(key, () {
    try {
      return NumberFormat.simpleCurrency(name: key);
    } catch (_) {
      return NumberFormat.simpleCurrency(name: 'USD');
    }
  });
  return formatter.format(value);
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  late ExpensesController _controller;

  int _selectedTab = 0; // 0 = Timeline, 1 = Settlements

  late final ConfettiController _confettiController;
  final ScrollController _timelineScrollController = ScrollController();
  bool _hasPlayedConfetti = false;

  bool _tabLoadStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = ExpensesController(ref: ref)
      ..addListener(_onControllerChanged);
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _timelineScrollController.addListener(_onTimelineScroll);
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getInt('expenses_selected_tab');
      if (saved == 0 || saved == 1) setState(() => _selectedTab = saved!);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _activateTabIfNeeded());
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _activateTabIfNeeded() {
    if (_tabLoadStarted || !mounted) return;
    final insideShell =
        context.findAncestorWidgetOfExactType<BottomNavScaffold>() != null;
    if (insideShell && !shouldActivateShellTab(ref, moneyShellTabIndex)) {
      return;
    }
    _tabLoadStarted = true;
    _controller.load(AppLocalizations.of(context)!);
  }

  @override
  void dispose() {
    _timelineScrollController.removeListener(_onTimelineScroll);
    _timelineScrollController.dispose();
    _confettiController.dispose();
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _onTimelineScroll() {
    if (_selectedTab != 0 ||
        !_timelineScrollController.hasClients ||
        _controller.isLoadingMore ||
        !_controller.hasMore) {
      return;
    }

    if (_timelineScrollController.position.extentAfter < 400) {
      _controller.loadMoreExpenses();
    }
  }

  Future<void> _openExpenseDetail(ExpenseDisplay expense) async {
    final groupId = _controller.groupId;
    if (groupId == null) return;
    unawaited(Haptics.light());
    await ExpenseDetailSheet.show(
      context,
      groupId: groupId,
      expenseId: expense.id,
      description: expense.description,
      amountLabel: _formatCurrency(expense.amount, currency: expense.currency),
      convertedLabel: expense.isConverted
          ? _formatCurrency(expense.baseAmount, currency: expense.baseCurrency)
          : null,
      payer: expense.payer,
      createdAt: expense.createdAt,
      onDelete: () => _confirmDeleteExpense(expense),
      currency: expense.currency,
      baseCurrency: expense.baseCurrency,
      userLabels: _controller.userLabels,
    );
  }

  Future<void> _confirmDeleteExpense(ExpenseDisplay expense) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.expenseDeleteTitle,
      body: Text(l10n.expenseDeleteBody),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: l10n.commonDelete,
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop();
    try {
      await _controller.deleteExpense(expense.id, AppLocalizations.of(context)!);
    } catch (e) {
      if (!mounted) return;
      unawaited(Haptics.failure());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
      );
    }
  }

  Color get _balanceColor {
    final balance = _controller.balance;
    if (balance > 0) return Theme.of(context).colorScheme.tertiary;
    if (balance < 0) return Theme.of(context).colorScheme.error;
    return Theme.of(context).colorScheme.onSurface;
  }

  void _onTabChanged(int tab) {
    setState(() => _selectedTab = tab);
    SharedPreferences.getInstance()
        .then((p) => p.setInt('expenses_selected_tab', tab));
  }

  Future<void> _openCreateExpense() async {
    unawaited(Haptics.light());
    final created = await ExpenseCreationSheet.show(context);
    if (created == true && mounted) {
      await _controller.load(AppLocalizations.of(context)!);
    }
  }

  Future<void> _recordSettlement(SettlementSuggestionDisplay suggestion) async {
    final groupId = _controller.groupId;
    if (groupId == null || _controller.isSettling) return;

    final confirmed = await SettlementConfirmationDialog.show(
      context: context,
      amount: _formatCurrency(suggestion.amount, currency: _controller.groupCurrency),
      payer: suggestion.fromLabel,
      payee: suggestion.toLabel,
    );
    if (confirmed != true || !mounted) return;

    unawaited(Haptics.light());
    try {
      await _controller.recordSettlement(suggestion, AppLocalizations.of(context)!);
      if (!mounted) return;
      unawaited(Haptics.success());
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.expenseSettlementRecorded)),
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.expenseSettlementFailed)),
      );
    }
  }

  void _maybePlayConfetti() {
    if (_selectedTab == 1 &&
        _controller.hasHousehold &&
        _controller.suggestions.isEmpty &&
        !_controller.isLoading &&
        _controller.errorMessage == null &&
        !_hasPlayedConfetti) {
      _hasPlayedConfetti = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _confettiController.play();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shellVisitedTabsProvider, (previous, next) {
      _activateTabIfNeeded();
    });
    ref.listen<String?>(currentGroupIdProvider, (previous, next) {
      if (previous != next) {
        _controller.load(AppLocalizations.of(context)!);
      }
    });

    _maybePlayConfetti();

    final l10n = AppLocalizations.of(context)!;

    final canSettle = _controller.hasHousehold &&
        !_controller.isLoading &&
        _controller.errorMessage == null;
    final showSettlementsNudge = canSettle && (_controller.suggestions.isNotEmpty);

    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.expenseAppBarTitle,
        actions: [
          IconButton(
            icon: const AppIcon(name: 'camera'),
            tooltip: l10n.expenseScanReceiptTooltip,
            onPressed: () => context.pushNamed('scanner'),
          ),
          IconButton(
            icon: const AppIcon(name: 'repeat'),
            tooltip: l10n.expenseRecurringTooltip,
            onPressed: () => context.pushNamed('recurringExpenses'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Sticky top section
          Padding(
            padding: const EdgeInsets.all(MitlistSpacing.md),
            child: Column(
              children: [
                _BalanceCard(
                  balance: _controller.balance,
                  currency: _controller.groupCurrency,
                  balanceColor: _balanceColor,
                  isLoading: _controller.isLoading,
                  openBalanceCount: _controller.openBalanceCount,
                  suggestionCount: _controller.suggestions.length,
                  onTap: showSettlementsNudge ? () => _onTabChanged(1) : null,
                ),
                const SizedBox(height: MitlistSpacing.md),
                _ChipBar(
                  selectedTab: _selectedTab,
                  onTabChanged: _onTabChanged,
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: _controller.isLoading
                ? const _LoadingBody()
                : _controller.errorMessage != null
                    ? _ErrorBody(
                        message: _controller.errorMessage,
                        onRetry: () =>
                            _controller.load(AppLocalizations.of(context)!),
                      )
                    : !_controller.hasHousehold
                        ? _NoHouseholdBody(
                            onOpenHouseholds: () =>
                                context.goNamed('groupsList'),
                          )
                        : _selectedTab == 0
                            ? _TimelineBody(
                                groups: _controller.timelineGroups,
                                controller: _timelineScrollController,
                                isLoadingMore: _controller.isLoadingMore,
                                hasPageError: _controller.hasPageError,
                                onRefresh: () =>
                                    _controller.load(AppLocalizations.of(context)!),
                                onAddExpense: _openCreateExpense,
                                onOpenExpense: _openExpenseDetail,
                              )
                            : _SettlementsBody(
                                suggestions: _controller.suggestions,
                                balances: _controller.balances,
                                currency: _controller.groupCurrency,
                                isSettling: _controller.isSettling,
                                confettiController: _confettiController,
                                onRefresh: () =>
                                    _controller.load(AppLocalizations.of(context)!),
                                onRecordSettlement: _recordSettlement,
                              ),
          ),
        ],
      ),
      floatingActionButton: !_controller.hasHousehold
          ? null
          : AppButton(
              size: AppButtonSize.lg,
              onPressed: _openCreateExpense,
              text: l10n.expenseAddExpense,
              icon: const AppIcon(name: 'plus'),
              tooltip: l10n.expenseAddExpense,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Balance card
// ---------------------------------------------------------------------------

class _BalanceCard extends StatelessWidget {
  final double balance;
  final String currency;
  final Color balanceColor;
  final bool isLoading;
  final int openBalanceCount;
  final int suggestionCount;
  final VoidCallback? onTap;

  const _BalanceCard({
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
                _formatCurrency(balance.abs(), currency: currency),
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

// ---------------------------------------------------------------------------
// Chip bar
// ---------------------------------------------------------------------------

class _ChipBar extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  const _ChipBar({
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: MitlistSpacing.sm,
      runSpacing: MitlistSpacing.sm,
      children: [
        AppChip(
          label: l10n.expenseTabTimeline,
          selected: selectedTab == 0,
          onSelected: (_) => onTabChanged(0),
        ),
        AppChip(
          label: l10n.expenseTabSettlements,
          selected: selectedTab == 1,
          onSelected: (_) => onTabChanged(1),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Loading body
// ---------------------------------------------------------------------------

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
      child: Column(
        children: [
          const AppSkeleton(
            width: double.infinity,
            height: MitlistSpacing.space12,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          const AppSkeleton(
            width: double.infinity,
            height: MitlistSpacing.space12,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          const AppSkeleton(
            width: double.infinity,
            height: MitlistSpacing.space12,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          AppSkeleton(
            width: double.infinity,
            height: MitlistSpacing.space12,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error body
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;

  const _ErrorBody({this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Column(
        children: [
          AppAlert(
            type: AppAlertType.error,
            message: message ?? l10n.commonFailedToLoad,
          ),
          const SizedBox(height: MitlistSpacing.md),
          AppButton(
            text: l10n.commonRetry,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _NoHouseholdBody extends StatelessWidget {
  final VoidCallback onOpenHouseholds;

  const _NoHouseholdBody({required this.onOpenHouseholds});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/House.lottie',
          icon: AppIcon(name: 'home', size: 56),
          title: l10n.commonNoHousehold,
          description: l10n.commonCreateJoinHousehold,
          actions: [
            AppButton(
              text: l10n.commonGoToHouseholds,
              onPressed: onOpenHouseholds,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline body
// ---------------------------------------------------------------------------

class _TimelineBody extends StatelessWidget {
  final List<ExpenseGroupDisplay> groups;
  final ScrollController controller;
  final bool isLoadingMore;
  final bool hasPageError;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddExpense;
  final ValueChanged<ExpenseDisplay> onOpenExpense;

  const _TimelineBody({
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

// ---------------------------------------------------------------------------
// Sticky header delegate
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Expense card
// ---------------------------------------------------------------------------

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
          '${expense.description}, ${_formatCurrency(expense.amount, currency: expense.currency)}',
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
                _formatCurrency(expense.amount, currency: expense.currency),
                style: MitlistTypography.monoBody(),
              ),
              if (expense.isConverted) ...[
                const SizedBox(height: MitlistSpacing.space1),
                Text(
                  l10n.expenseConvertedAmount(_formatCurrency(expense.baseAmount, currency: expense.baseCurrency)),
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

// ---------------------------------------------------------------------------
// Settlements body
// ---------------------------------------------------------------------------

class _SettlementsBody extends StatelessWidget {
  final List<SettlementSuggestionDisplay> suggestions;
  final List<BalanceDisplayEntry> balances;
  final String currency;
  final bool isSettling;
  final ConfettiController confettiController;
  final Future<void> Function() onRefresh;
  final ValueChanged<SettlementSuggestionDisplay> onRecordSettlement;

  const _SettlementsBody({
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

// ---------------------------------------------------------------------------
// Suggestion card
// ---------------------------------------------------------------------------

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
                _formatCurrency(suggestion.amount, currency: currency),
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
                helper:
                    suggestion.from == suggestion.to ? l10n.expenseSameAccount : l10n.expenseFrom,
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
              text: isSettling ? l10n.expenseRecording : l10n.expenseRecordSettlement,
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

// ---------------------------------------------------------------------------
// Balances section
// ---------------------------------------------------------------------------

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
          label: _expanded ? l10n.expenseCollapseBalances : l10n.expenseExpandBalances,
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
                                _formatCurrency(b.amount.abs(),
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
