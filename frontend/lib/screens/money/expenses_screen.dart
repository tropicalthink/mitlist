import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/group_provider.dart';
import '../../models/finance_models.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../utils/shell_tab_load.dart';
import '../../utils/active_group_context.dart';
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

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class _Expense {
  final String id;
  final String description;
  final double amount;
  final String payer;
  final String currency;
  final String category;
  final DateTime date;
  final DateTime createdAt;

  const _Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.payer,
    required this.currency,
    required this.category,
    required this.date,
    required this.createdAt,
  });
}

class _ExpenseGroup {
  final String label;
  final List<_Expense> expenses;
  final DateTime date;

  const _ExpenseGroup({required this.label, required this.expenses, required this.date});
}

class _SettlementSuggestion {
  final String from;
  final String to;
  final String fromLabel;
  final String toLabel;
  final double amount;

  const _SettlementSuggestion({
    required this.from,
    required this.to,
    required this.fromLabel,
    required this.toLabel,
    required this.amount,
  });
}

class _BalanceEntry {
  final String userId;
  final String name;
  final double amount;

  const _BalanceEntry({
    required this.userId,
    required this.name,
    required this.amount,
  });
}

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
  static const int _pageLimit = 50;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  bool _hasPageError = false;
  bool _hasHousehold = false;
  bool _isSettling = false;
  int _selectedTab = 0; // 0 = Timeline, 1 = Settlements
  final Logger _logger = Logger();

  late final ConfettiController _confettiController;
  final ScrollController _timelineScrollController = ScrollController();
  bool _hasPlayedConfetti = false;
  bool _listenersSetUp = false;

  double _balance = 0;
  int _openBalanceCount = 0;
  String? _groupId;
  String _groupCurrency = 'USD';
  Map<String, String> _userLabels = {};
  Map<String, String> _memberNames = {};
  final List<_Expense> _timelineExpenses = [];
  List<_ExpenseGroup> _timelineGroups = [];
  List<_SettlementSuggestion> _suggestions = [];
  List<_BalanceEntry> _balances = [];

  bool _tabLoadStarted = false;

  @override
  void initState() {
    super.initState();
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

  void _activateTabIfNeeded() {
    if (_tabLoadStarted || !mounted) return;
    if (!shouldActivateShellTab(ref, moneyShellTabIndex)) return;
    _tabLoadStarted = true;
    _loadData();
  }

  @override
  void dispose() {
    _timelineScrollController.removeListener(_onTimelineScroll);
    _timelineScrollController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _onTimelineScroll() {
    if (_selectedTab != 0 ||
        !_timelineScrollController.hasClients ||
        _isLoadingMore ||
        !_hasMore) {
      return;
    }

    if (_timelineScrollController.position.extentAfter < 400) {
      _loadMoreExpenses();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasPageError = false;
      _hasMore = true;
      _isLoadingMore = false;
    });

    try {
      await ref.read(currentGroupIdProvider.notifier).ensureLoaded();
      final authService = await ref.read(authServiceProviderAsync.future);
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final groups = await ref.read(cachedGroupsProvider.future);
      final groupId =
          resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
      final validGroupId = isValidGroupId(groupId) ? groupId : null;
      final me = validGroupId == null ? null : await authService.getMe();

      if (validGroupId != null) {
        // Load member names and group currency in parallel.
        await Future.wait([
          groupService.listMembers(validGroupId).then((members) {
            _memberNames = {
              for (final m in members)
                m.userId: m.userId == me?.id ? 'You' : m.displayName,
            };
          }).catchError((_) {}),
          groupService.getGroup(validGroupId).then((group) {
            _groupCurrency = group.currency;
          }).catchError((_) {}),
        ]);
      }

      final repo = await ref.read(financeRepositoryProvider.future);
      final expenses = validGroupId == null
          ? <Expense>[]
          : await repo.getExpensesByGroupOnce(validGroupId);
      final summary = validGroupId == null ? null : await repo.watchSummaryByGroup(validGroupId).first;

      if (!mounted) return;

      _groupId = validGroupId;
      _applyFinanceSummary(summary, me?.id);
      _timelineExpenses
        ..clear()
        ..addAll(expenses.map(_mapExpense));
      _rebuildTimelineGroups();

      setState(() {
        _hasHousehold = validGroupId != null;
        _hasMore = expenses.length == _pageLimit;
        _isLoading = false;
      });

      // Background refresh; keep cached UI if this fails.
      if (validGroupId != null) {
        unawaited(repo.refreshGroup(validGroupId, limit: _pageLimit, offset: 0).catchError((e) {
          _logger.w('Background expenses refresh failed', error: e);
          return 0;
        }));
        if (!_listenersSetUp) {
          _listenersSetUp = true;
          ref.listenManual(cachedExpensesByGroupProvider(validGroupId), (prev, next) {
            next.whenData((data) {
              if (!mounted) return;
              _timelineExpenses
                ..clear()
                ..addAll(data.map(_mapExpense));
              _rebuildTimelineGroups();
              setState(() => _isLoading = false);
            });
          });
          ref.listenManual(cachedFinanceSummaryByGroupProvider(validGroupId), (prev, next) {
            next.whenData((s) {
              if (!mounted) return;
              _applyFinanceSummary(s, me?.id);
              setState(() {});
            });
          });
        }
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Couldn\u2019t load expenses. Check your connection.';
        _isLoading = false;
      });
    }
  }

  void _applyFinanceSummary(FinanceSummary? summary, String? currentUserId) {
    if (summary == null) {
      _balance = 0;
      _openBalanceCount = 0;
      _suggestions = [];
      _balances = [];
      _userLabels = {..._memberNames};
      return;
    }

    final currentUserBalance = summary.balances
        .where((balance) => balance.userId == currentUserId)
        .toList();
    _balance =
        currentUserBalance.isEmpty ? 0 : currentUserBalance.first.total / 100.0;
    _openBalanceCount =
        summary.balances.where((balance) => balance.total != 0).length;
    _suggestions = summary.reimbursements
        .map((suggestion) => _SettlementSuggestion(
              from: suggestion.fromUserId,
              to: suggestion.toUserId,
              fromLabel: suggestion.fromUserId == currentUserId
                  ? 'You'
                  : suggestion.fromDisplayName,
              toLabel: suggestion.toUserId == currentUserId
                  ? 'You'
                  : suggestion.toDisplayName,
              amount: suggestion.amount / 100.0,
            ))
        .toList();
    _balances = summary.balances
        .map((balance) => _BalanceEntry(
              userId: balance.userId,
              name:
                  balance.userId == currentUserId ? 'You' : balance.displayName,
              amount: balance.total / 100.0,
            ))
        .toList();

    _userLabels = {
      // Member names are the base layer; summary display names take precedence.
      ..._memberNames,
      for (final b in summary.balances)
        b.userId: b.userId == currentUserId ? 'You' : b.displayName,
    };
  }

  Future<void> _loadMoreExpenses() async {
    final groupId = _groupId;
    if (_isLoading || _isLoadingMore || !_hasMore || groupId == null) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _hasPageError = false;
    });

    try {
      final repo = await ref.read(financeRepositoryProvider.future);
      final fetchedCount = await repo.refreshGroup(
        groupId,
        limit: _pageLimit,
        offset: _timelineExpenses.length,
      );

      if (!mounted) return;

      final allCached = await repo.getExpensesByGroupOnce(groupId);
      _timelineExpenses
        ..clear()
        ..addAll(allCached.map(_mapExpense));
      _rebuildTimelineGroups();
      setState(() {
        _hasMore = fetchedCount == _pageLimit;
        _isLoadingMore = false;
        _hasPageError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasPageError = true;
        _isLoadingMore = false;
      });
    }
  }

  _Expense _mapExpense(Expense exp) {
    return _Expense(
      id: exp.id,
      description: exp.description,
      amount: exp.amount / 100.0,
      payer: _userLabels[exp.payerId] ?? exp.payerId,
      currency: exp.currency,
      category: exp.category,
      date: exp.date,
      createdAt: exp.createdAt,
    );
  }

  Future<void> _openExpenseDetail(_Expense expense) async {
    final groupId = _groupId;
    if (groupId == null) return;
    unawaited(Haptics.light());
    await ExpenseDetailSheet.show(
      context,
      groupId: groupId,
      expenseId: expense.id,
      description: expense.description,
      amountLabel: _formatCurrency(expense.amount, currency: expense.currency),
      payer: expense.payer,
      createdAt: expense.createdAt,
      onDelete: () => _confirmDeleteExpense(expense),
      currency: expense.currency,
      userLabels: _userLabels,
    );
  }

  Future<void> _confirmDeleteExpense(_Expense expense) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: 'Delete expense',
      body: const Text('This will permanently delete this expense and all associated receipts. This cannot be undone.'),
      actions: [
        AppButton(
          text: 'Cancel',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: 'Delete',
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    Navigator.of(context).pop();
    try {
      final service = await ref.read(financeServiceProviderAsync.future);
      await service.deleteExpense(expense.id);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      unawaited(Haptics.failure());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }

  void _rebuildTimelineGroups() {
    final now = DateTime.now();

    final timelineMap = <String, List<_Expense>>{};
    for (final exp in _timelineExpenses) {
      final label = _dateLabel(exp.date, now);
      timelineMap.putIfAbsent(label, () => []);
      timelineMap[label]!.add(exp);
    }

    _timelineGroups = timelineMap.entries
        .map((e) => _ExpenseGroup(
              label: e.key,
              expenses: e.value,
              date: e.value.first.date,
            ))
        .toList();
    _timelineGroups.sort((a, b) {
      final order = ['Today', 'Yesterday'];
      final ai = order.indexOf(a.label);
      final bi = order.indexOf(b.label);
      if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
      if (ai >= 0) return -1;
      if (bi >= 0) return 1;
      return b.date.compareTo(a.date);
    });
  }

  String _dateLabel(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMMM d').format(date);
  }

  Color get _balanceColor {
    if (_balance > 0) return Theme.of(context).colorScheme.tertiary;
    if (_balance < 0) return Theme.of(context).colorScheme.error;
    return Theme.of(context).colorScheme.onSurface;
  }

  void _onTabChanged(int tab) {
    setState(() => _selectedTab = tab);
    SharedPreferences.getInstance().then((p) => p.setInt('expenses_selected_tab', tab));
  }

  Future<void> _openCreateExpense() async {
    unawaited(Haptics.light());
    final created = await ExpenseCreationSheet.show(context);
    if (created == true) {
      await _loadData();
    }
  }

  Future<void> _recordSettlement(_SettlementSuggestion suggestion) async {
    final groupId = _groupId;
    if (groupId == null || _isSettling) return;

    final confirmed = await SettlementConfirmationDialog.show(
      context: context,
      amount: _formatCurrency(suggestion.amount, currency: _groupCurrency),
      payer: suggestion.fromLabel,
      payee: suggestion.toLabel,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSettling = true);
    unawaited(Haptics.light());
    try {
      final financeService = await ref.read(financeServiceProviderAsync.future);
      await financeService.createGroupSettlement(
        groupId,
        CreateSettlementRequest(
          fromUserId: suggestion.from,
          toUserId: suggestion.to,
          amount: (suggestion.amount * 100).round(),
        ),
      );
      await _loadData();
      if (!mounted) return;
      unawaited(Haptics.success());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settlement recorded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\u2019t record settlement.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSettling = false);
      }
    }
  }

  void _maybePlayConfetti() {
    if (_selectedTab == 1 &&
        _hasHousehold &&
        _suggestions.isEmpty &&
        !_isLoading &&
        _errorMessage == null &&
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
        _loadData();
      }
    });

    _maybePlayConfetti();

    final canSettle = _hasHousehold && !_isLoading && _errorMessage == null;
    final showSettlementsNudge = canSettle && (_suggestions.isNotEmpty);

    return Scaffold(
      appBar: MitlistAppBar.titleText(
        'Money',
        actions: [
          IconButton(
            icon: const AppIcon(name: 'camera'),
            tooltip: 'Scan receipt',
            onPressed: () => context.pushNamed('scanner'),
          ),
          IconButton(
            icon: const AppIcon(name: 'repeat'),
            tooltip: 'Recurring',
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
                  balance: _balance,
                  currency: _groupCurrency,
                  balanceColor: _balanceColor,
                  isLoading: _isLoading,
                  openBalanceCount: _openBalanceCount,
                  suggestionCount: _suggestions.length,
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
            child: _isLoading
                ? const _LoadingBody()
                : _errorMessage != null
                    ? _ErrorBody(message: _errorMessage, onRetry: _loadData)
                    : !_hasHousehold
                        ? _NoHouseholdBody(
                            onOpenHouseholds: () => context.goNamed('groupsList'),
                          )
                        : _selectedTab == 0
                            ? _TimelineBody(
                                groups: _timelineGroups,
                                controller: _timelineScrollController,
                                isLoadingMore: _isLoadingMore,
                                hasPageError: _hasPageError,
                                onRefresh: _loadData,
                                onAddExpense: _openCreateExpense,
                                onOpenExpense: _openExpenseDetail,
                              )
                            : _SettlementsBody(
                                suggestions: _suggestions,
                                balances: _balances,
                                currency: _groupCurrency,
                                isSettling: _isSettling,
                                confettiController: _confettiController,
                                onRefresh: _loadData,
                                onRecordSettlement: _recordSettlement,
                              ),
          ),
        ],
      ),
      floatingActionButton: !_hasHousehold
          ? null
          : AppButton(
              size: AppButtonSize.lg,
              onPressed: _openCreateExpense,
              text: 'Add expense',
              icon: const AppIcon(name: 'plus'),
              tooltip: 'Add expense',
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

  String get _headline {
    if (balance > 0) return 'You are owed';
    if (balance < 0) return 'You owe';
    return 'All square';
  }

  String get _description {
    if (suggestionCount > 0) {
      return '$suggestionCount suggested payment${suggestionCount == 1 ? '' : 's'} to settle up';
    }
    if (openBalanceCount > 0) {
      return '$openBalanceCount open balance${openBalanceCount == 1 ? '' : 's'} in the household';
    }
    return 'No one needs to pay anyone right now';
  }

  @override
  Widget build(BuildContext context) {
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
                  Text(_headline,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: MitlistSpacing.xs),
                  Text(
                    _description,
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
    return Wrap(
      spacing: MitlistSpacing.sm,
      runSpacing: MitlistSpacing.sm,
      children: [
        AppChip(
          label: 'Timeline',
          selected: selectedTab == 0,
          onSelected: (_) => onTabChanged(0),
        ),
        AppChip(
          label: 'Settlements',
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Column(
        children: [
          AppAlert(
            type: AppAlertType.error,
            message: message ?? 'Failed to load expenses. Please try again.',
          ),
          const SizedBox(height: MitlistSpacing.md),
          AppButton(
            text: 'Retry',
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/House.lottie',
          icon: AppIcon(name: 'home', size: 56),
          title: 'No household yet',
          description: 'Create or join a household before tracking expenses.',
          actions: [
            AppButton(
              text: 'Go to households',
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
  final List<_ExpenseGroup> groups;
  final ScrollController controller;
  final bool isLoadingMore;
  final bool hasPageError;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddExpense;
  final ValueChanged<_Expense> onOpenExpense;

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
                    title: 'No expenses yet',
                    description: 'Track shared costs with your household.',
                    actions: [
                      AppButton(
                        text: 'Add first expense',
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
                        group.label.toUpperCase(),
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
                        message: 'Failed to load more expenses.',
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
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 2),
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
  final _Expense expense;
  final VoidCallback onTap;

  const _ExpenseCard({required this.expense, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.outlined,
      interactive: true,
      onTap: onTap,
      semanticLabel: '${expense.description}, ${_formatCurrency(expense.amount, currency: expense.currency)}',
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
                  expense.category.toUpperCase(),
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
                  'Paid by ${expense.payer}',
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
  final List<_SettlementSuggestion> suggestions;
  final List<_BalanceEntry> balances;
  final String currency;
  final bool isSettling;
  final ConfettiController confettiController;
  final Future<void> Function() onRefresh;
  final ValueChanged<_SettlementSuggestion> onRecordSettlement;

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
              'Suggested payments',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: MitlistSpacing.xs),
            Text(
              'Calculated from every expense, split, and recorded settlement in this household.',
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
                    title: 'All settled up!',
                    description: 'No one owes anyone right now.',
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
  final _SettlementSuggestion suggestion;
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
                    suggestion.from == suggestion.to ? 'Same account' : 'From',
                tone: Theme.of(context).colorScheme.error,
              );
              final to = _SettlementParty(
                label: suggestion.toLabel,
                helper: 'To',
                tone: Theme.of(context).colorScheme.tertiary,
              );

              if (compact) {
                return Column(
                  children: [
                    from,
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: MitlistSpacing.sm),
                    child: AppIcon(name: 'arrowRight', size: 20),
                  ),
                  Expanded(child: to),
                ],
              );
            },
          ),
          const SizedBox(height: MitlistSpacing.md),
          Text(
            'Record this settlement after the payment is made.',
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
              text: isSettling ? 'Recording...' : 'Record settlement',
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
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            helper.toUpperCase(),
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
  final List<_BalanceEntry> balances;
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
  final List<_BalanceEntry> sortedBalances;
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
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    return Column(
      children: [
        Semantics(
          button: true,
          label: _expanded ? 'Collapse balances' : 'Expand balances',
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
                    'Balances',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Text(
                  '${widget.openCount} open',
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
                    'No balances yet. Add an expense with splits to start the ledger.',
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
                                          ? 'is owed'
                                          : b.amount < 0
                                              ? 'owes'
                                              : 'settled',
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
                                _formatCurrency(b.amount.abs(), currency: widget.currency),
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
