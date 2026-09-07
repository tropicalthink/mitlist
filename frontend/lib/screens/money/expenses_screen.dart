import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/mitlist_app_bar.dart';
import 'expense_format.dart';
import 'expenses_controller.dart';
import 'widgets/expense_balance_card.dart';
import 'widgets/expense_chip_bar.dart';
import 'widgets/expense_settlements_body.dart';
import 'widgets/expense_states.dart';
import 'widgets/expense_timeline_body.dart';

import '../../widgets/app_toast.dart';
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
      amountLabel:
          formatExpenseCurrency(expense.amount, currency: expense.currency),
      convertedLabel: expense.isConverted
          ? formatExpenseCurrency(expense.baseAmount,
              currency: expense.baseCurrency)
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
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: l10n.commonDelete,
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop();
    try {
      await _controller.deleteExpense(
          expense.id, AppLocalizations.of(context)!);
    } catch (e) {
      if (!mounted) return;
      unawaited(Haptics.failure());
      AppToast.error(
          context, friendlyErrorMessage(e, AppLocalizations.of(context)!));
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
      amount: formatExpenseCurrency(suggestion.amount,
          currency: _controller.groupCurrency),
      payer: suggestion.fromLabel,
      payee: suggestion.toLabel,
    );
    if (confirmed != true || !mounted) return;

    unawaited(Haptics.light());
    try {
      await _controller.recordSettlement(
          suggestion, AppLocalizations.of(context)!);
      if (!mounted) return;
      unawaited(Haptics.success());
      final l10n = AppLocalizations.of(context)!;
      AppToast.success(context, l10n.expenseSettlementRecorded);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      AppToast.error(context, l10n.expenseSettlementFailed);
    }
  }

  Future<void> _respondToSettlement(
      SettlementDisplay settlement, bool approve) async {
    if (_controller.isRespondingToSettlement) return;
    unawaited(Haptics.light());
    try {
      await _controller.respondToSettlement(
          settlement.id, approve, AppLocalizations.of(context)!);
      if (!mounted) return;
      if (approve) unawaited(Haptics.success());
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      AppToast.error(context, l10n.expenseSettlementResponseFailed);
    }
  }

  Future<void> _cancelSettlement(SettlementDisplay settlement) async {
    unawaited(Haptics.light());
    try {
      await _controller.cancelSettlement(
          settlement.id, AppLocalizations.of(context)!);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      AppToast.error(context, l10n.expenseSettlementCancelFailed);
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
    final showSettlementsNudge =
        canSettle && (_controller.suggestions.isNotEmpty);

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
                ExpenseBalanceCard(
                  balance: _controller.balance,
                  currency: _controller.groupCurrency,
                  balanceColor: _balanceColor,
                  isLoading: _controller.isLoading,
                  openBalanceCount: _controller.openBalanceCount,
                  suggestionCount: _controller.suggestions.length,
                  onTap: showSettlementsNudge ? () => _onTabChanged(1) : null,
                ),
                const SizedBox(height: MitlistSpacing.md),
                ExpenseChipBar(
                  selectedTab: _selectedTab,
                  onTabChanged: _onTabChanged,
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: _controller.isLoading
                ? const ExpenseLoadingBody()
                : _controller.errorMessage != null
                    ? ExpenseErrorBody(
                        message: _controller.errorMessage,
                        onRetry: () =>
                            _controller.load(AppLocalizations.of(context)!),
                      )
                    : !_controller.hasHousehold
                        ? ExpenseNoHouseholdBody(
                            onOpenHouseholds: () =>
                                context.goNamed('groupsList'),
                          )
                        : _selectedTab == 0
                            ? ExpenseTimelineBody(
                                groups: _controller.timelineGroups,
                                controller: _timelineScrollController,
                                isLoadingMore: _controller.isLoadingMore,
                                hasPageError: _controller.hasPageError,
                                onRefresh: () => _controller
                                    .load(AppLocalizations.of(context)!),
                                onAddExpense: _openCreateExpense,
                                onOpenExpense: _openExpenseDetail,
                              )
                            : ExpenseSettlementsBody(
                                suggestions: _controller.suggestions,
                                needsMyResponse:
                                    _controller.settlementsNeedingMyResponse,
                                awaitingOthers:
                                    _controller.settlementsAwaitingOthers,
                                recentSettlements:
                                    _controller.recentSettlements,
                                balances: _controller.balances,
                                currency: _controller.groupCurrency,
                                isSettling: _controller.isSettling,
                                isResponding:
                                    _controller.isRespondingToSettlement,
                                confettiController: _confettiController,
                                onRefresh: () => _controller
                                    .load(AppLocalizations.of(context)!),
                                onRecordSettlement: _recordSettlement,
                                onRespondSettlement: _respondToSettlement,
                                onCancelSettlement: _cancelSettlement,
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
