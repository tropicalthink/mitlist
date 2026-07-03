import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../../l10n/app_localizations.dart';
import '../../models/finance_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/group_provider.dart';
import '../../repositories/finance_repository.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../utils/active_group_context.dart';

// ---------------------------------------------------------------------------
// Display models
// ---------------------------------------------------------------------------

/// An expense mapped for display: amounts in major units, currency
/// conversion info, and the resolved payer label.
class ExpenseDisplay {
  final String id;
  final String description;
  final double amount;
  final double baseAmount;
  final double fxRate;
  final String baseCurrency;
  final String payer;
  final String currency;
  final String category;
  final DateTime date;
  final DateTime createdAt;

  const ExpenseDisplay({
    required this.id,
    required this.description,
    required this.amount,
    required this.baseAmount,
    required this.fxRate,
    required this.baseCurrency,
    required this.payer,
    required this.currency,
    required this.category,
    required this.date,
    required this.createdAt,
  });

  /// True when this expense was recorded in a currency other than the
  /// household base currency and therefore carries a conversion.
  bool get isConverted => fxRate != 1.0 || currency != baseCurrency;
}

class ExpenseGroupDisplay {
  final String label;
  final List<ExpenseDisplay> expenses;
  final DateTime date;

  const ExpenseGroupDisplay(
      {required this.label, required this.expenses, required this.date});
}

class SettlementSuggestionDisplay {
  final String from;
  final String to;
  final String fromLabel;
  final String toLabel;
  final double amount;

  const SettlementSuggestionDisplay({
    required this.from,
    required this.to,
    required this.fromLabel,
    required this.toLabel,
    required this.amount,
  });
}

class BalanceDisplayEntry {
  final String userId;
  final String name;
  final double amount;

  const BalanceDisplayEntry({
    required this.userId,
    required this.name,
    required this.amount,
  });
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Owns all data + side-effect state for [ExpensesScreen]: the timeline
/// expenses, settlement suggestions, balances, and every mutation (settle,
/// delete). The screen keeps only BuildContext-bound concerns (tab
/// selection/persistence, dialogs, snackbars, confetti, scroll) and listens
/// to this controller for rebuilds.
///
/// Mutation methods are intentionally UI-agnostic: they perform the write and
/// **throw** on failure so the screen can show the operation-specific
/// message, mirroring `ListDetailController`.
///
/// Localized labels (date-bucket headers, the "you" label) need an
/// [AppLocalizations] instance, which this BuildContext-free controller
/// cannot look up itself. [load] takes it as a parameter and caches the most
/// recent instance for background provider listeners that fire without a
/// fresh one; those listeners therefore use the last-loaded locale rather
/// than re-resolving it live, a minor divergence from the pre-refactor
/// screen (which always read `AppLocalizations.of(context)` at
/// callback-fire time).
class ExpensesController extends ChangeNotifier {
  ExpensesController({required this.ref});

  final WidgetRef ref;
  static const int pageLimit = 50;

  final Logger _logger = Logger();

  bool _disposed = false;

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  bool _hasPageError = false;
  bool _hasHousehold = false;
  bool _isSettling = false;

  double _balance = 0;
  int _openBalanceCount = 0;
  String? _groupId;
  String _groupCurrency = 'USD';
  Map<String, String> _userLabels = {};
  Map<String, String> _memberNames = {};
  final List<ExpenseDisplay> _timelineExpenses = [];
  List<ExpenseGroupDisplay> _timelineGroups = [];
  List<SettlementSuggestionDisplay> _suggestions = [];
  List<BalanceDisplayEntry> _balances = [];

  bool _listenersSetUp = false;
  String? _currentUserId;
  AppLocalizations? _l10n;

  // ---- Reactive getters -----------------------------------------------------

  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  bool get hasPageError => _hasPageError;
  bool get hasHousehold => _hasHousehold;
  bool get isSettling => _isSettling;
  double get balance => _balance;
  int get openBalanceCount => _openBalanceCount;
  String? get groupId => _groupId;
  String get groupCurrency => _groupCurrency;
  Map<String, String> get userLabels => _userLabels;
  List<ExpenseGroupDisplay> get timelineGroups => _timelineGroups;
  List<SettlementSuggestionDisplay> get suggestions => _suggestions;
  List<BalanceDisplayEntry> get balances => _balances;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  // ---- Load & live data -----------------------------------------------------

  Future<void> load(AppLocalizations l10n) async {
    _l10n = l10n;
    _isLoading = true;
    _isRefreshing = false;
    _errorMessage = null;
    _hasPageError = false;
    _hasMore = true;
    _isLoadingMore = false;
    _notify();

    try {
      await ref.read(currentGroupIdProvider.notifier).ensureLoaded();
      final authService = await ref.read(authServiceProviderAsync.future);
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final groups = await ref.read(cachedGroupsProvider.future);
      final groupId =
          resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
      final validGroupId = isValidGroupId(groupId) ? groupId : null;
      final me = validGroupId == null ? null : await authService.getMe();

      if (_disposed) return;

      if (validGroupId != null) {
        final youLabel = l10n.activityYou;
        // Load member names and group currency in parallel.
        await Future.wait([
          groupService.listMembers(validGroupId).then((members) {
            _memberNames = {
              for (final m in members)
                m.userId: m.userId == me?.id ? youLabel : m.displayName,
            };
          }).catchError((_) {}),
          groupService.getGroup(validGroupId).then((group) {
            _groupCurrency = group.currency;
          }).catchError((_) {}),
        ]);
      }

      if (_disposed) return;

      final repo = await ref.read(financeRepositoryProvider.future);
      final expenses = validGroupId == null
          ? <Expense>[]
          : await repo.getExpensesByGroupOnce(validGroupId);
      final summary = validGroupId == null
          ? null
          : await repo.watchSummaryByGroup(validGroupId).first;

      if (_disposed) return;

      _groupId = validGroupId;
      _currentUserId = me?.id;
      _applyFinanceSummary(summary, me?.id, l10n);
      _timelineExpenses
        ..clear()
        ..addAll(expenses.map(_mapExpense));
      _rebuildTimelineGroups(l10n);

      _hasHousehold = validGroupId != null;
      _hasMore = expenses.length == pageLimit;
      // Keep skeleton until remote refresh when cache is empty; cached rows
      // render immediately when present.
      _isLoading = validGroupId != null && expenses.isEmpty;
      _isRefreshing = validGroupId != null;
      _notify();

      // Background refresh; keep cached UI if this fails.
      if (validGroupId != null) {
        unawaited(_refreshExpensesPage(repo, validGroupId));
        if (!_listenersSetUp) {
          _listenersSetUp = true;
          ref.listenManual(cachedExpensesByGroupProvider(validGroupId),
              (prev, next) {
            next.whenData((data) {
              if (_disposed) return;
              // refreshGroup clears local rows before upserting; ignore the
              // transient empty emission so the empty state does not flash.
              if (data.isEmpty && _isRefreshing) return;
              _applyTimelineExpenses(data);
            });
          });
          ref.listenManual(cachedFinanceSummaryByGroupProvider(validGroupId),
              (prev, next) {
            next.whenData((s) {
              if (_disposed) return;
              final currentL10n = _l10n;
              if (currentL10n == null) return;
              _applyFinanceSummary(s, _currentUserId, currentL10n);
              _notify();
            });
          });
        }
      } else {
        if (_disposed) return;
        _isLoading = false;
        _notify();
      }
    } catch (e) {
      if (_disposed) return;
      _errorMessage = l10n.expenseLoadError;
      _isLoading = false;
      _notify();
    }
  }

  Future<void> _refreshExpensesPage(
      FinanceRepository repo, String groupId) async {
    try {
      final fetchedCount = await repo.refreshGroup(
        groupId,
        limit: pageLimit,
        offset: 0,
      );
      if (_disposed) return;
      _isRefreshing = false;
      _isLoading = false;
      _hasMore = fetchedCount == pageLimit;
      _notify();
    } catch (e) {
      _logger.w('Background expenses refresh failed', error: e);
      if (_disposed) return;
      _isRefreshing = false;
      _isLoading = false;
      _notify();
    }
  }

  void _applyTimelineExpenses(List<Expense> expenses) {
    _timelineExpenses
      ..clear()
      ..addAll(expenses.map(_mapExpense));
    final l10n = _l10n;
    if (l10n != null) _rebuildTimelineGroups(l10n);
    _isLoading = false;
    _isRefreshing = false;
    _notify();
  }

  void _applyFinanceSummary(
    FinanceSummary? summary,
    String? currentUserId,
    AppLocalizations l10n,
  ) {
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
        .map((suggestion) => SettlementSuggestionDisplay(
              from: suggestion.fromUserId,
              to: suggestion.toUserId,
              fromLabel: suggestion.fromUserId == currentUserId
                  ? l10n.activityYou
                  : suggestion.fromDisplayName,
              toLabel: suggestion.toUserId == currentUserId
                  ? l10n.activityYou
                  : suggestion.toDisplayName,
              amount: suggestion.amount / 100.0,
            ))
        .toList();
    _balances = summary.balances
        .map((balance) => BalanceDisplayEntry(
              userId: balance.userId,
              name:
                  balance.userId == currentUserId ? l10n.activityYou : balance.displayName,
              amount: balance.total / 100.0,
            ))
        .toList();

    _userLabels = {
      // Member names are the base layer; summary display names take precedence.
      ..._memberNames,
      for (final b in summary.balances)
        b.userId: b.userId == currentUserId ? l10n.activityYou : b.displayName,
    };
  }

  Future<void> loadMoreExpenses() async {
    final groupId = _groupId;
    if (_isLoading || _isLoadingMore || !_hasMore || groupId == null) {
      return;
    }

    _isLoadingMore = true;
    _hasPageError = false;
    _notify();

    try {
      final repo = await ref.read(financeRepositoryProvider.future);
      final fetchedCount = await repo.refreshGroup(
        groupId,
        limit: pageLimit,
        offset: _timelineExpenses.length,
      );

      if (_disposed) return;

      final allCached = await repo.getExpensesByGroupOnce(groupId);
      _timelineExpenses
        ..clear()
        ..addAll(allCached.map(_mapExpense));
      final l10n = _l10n;
      if (l10n != null) _rebuildTimelineGroups(l10n);
      _hasMore = fetchedCount == pageLimit;
      _isLoadingMore = false;
      _hasPageError = false;
      _notify();
    } catch (e) {
      if (_disposed) return;
      _hasPageError = true;
      _isLoadingMore = false;
      _notify();
    }
  }

  ExpenseDisplay _mapExpense(Expense exp) {
    return ExpenseDisplay(
      id: exp.id,
      description: exp.description,
      amount: exp.amount / 100.0,
      baseAmount: exp.baseAmount / 100.0,
      fxRate: exp.fxRate,
      baseCurrency: _groupCurrency,
      payer: _userLabels[exp.payerId] ?? exp.payerId,
      currency: exp.currency,
      category: exp.category,
      date: exp.date,
      createdAt: exp.createdAt,
    );
  }

  void _rebuildTimelineGroups(AppLocalizations l10n) {
    final now = DateTime.now();

    final timelineMap = <String, List<ExpenseDisplay>>{};
    for (final exp in _timelineExpenses) {
      final label = _dateLabel(exp.date, now, l10n);
      timelineMap.putIfAbsent(label, () => []);
      timelineMap[label]!.add(exp);
    }

    _timelineGroups = timelineMap.entries
        .map((e) => ExpenseGroupDisplay(
              label: e.key,
              expenses: e.value,
              date: e.value.first.date,
            ))
        .toList();
    _timelineGroups.sort((a, b) {
      final order = [l10n.expenseToday, l10n.expenseYesterday];
      final ai = order.indexOf(a.label);
      final bi = order.indexOf(b.label);
      if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
      if (ai >= 0) return -1;
      if (bi >= 0) return 1;
      return b.date.compareTo(a.date);
    });
  }

  String _dateLabel(DateTime date, DateTime now, AppLocalizations l10n) {
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return l10n.expenseToday;
    if (d == today.subtract(const Duration(days: 1))) return l10n.expenseYesterday;
    return DateFormat('MMMM d').format(date);
  }

  // ---- Mutations (throw on failure) -----------------------------------------

  Future<void> recordSettlement(
    SettlementSuggestionDisplay suggestion,
    AppLocalizations l10n,
  ) async {
    final groupId = _groupId;
    if (groupId == null || _isSettling) return;

    _isSettling = true;
    _notify();
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
      await load(l10n);
    } finally {
      if (!_disposed) {
        _isSettling = false;
        _notify();
      }
    }
  }

  Future<void> deleteExpense(String expenseId, AppLocalizations l10n) async {
    final service = await ref.read(financeServiceProviderAsync.future);
    await service.deleteExpense(expenseId);
    await load(l10n);
  }
}
