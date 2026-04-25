import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../providers/group_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class _Expense {
  final String description;
  final double amount;
  final String payer;
  final String status;
  final DateTime date;

  const _Expense({
    required this.description,
    required this.amount,
    required this.payer,
    required this.status,
    required this.date,
  });
}

class _ExpenseGroup {
  final String label;
  final List<_Expense> expenses;

  const _ExpenseGroup({required this.label, required this.expenses});
}

class _SettlementSuggestion {
  final String from;
  final String to;
  final double amount;

  const _SettlementSuggestion({
    required this.from,
    required this.to,
    required this.amount,
  });
}

class _BalanceEntry {
  final String name;
  final double amount;

  const _BalanceEntry({required this.name, required this.amount});
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _currencyFormat = NumberFormat.currency(symbol: '\$');

String _formatCurrency(double value) => _currencyFormat.format(value);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  int _selectedTab = 0; // 0 = Timeline, 1 = Settlements

  late final ConfettiController _confettiController;
  bool _hasPlayedConfetti = false;

  double _balance = 0;
  List<_ExpenseGroup> _timelineGroups = [];
  List<_SettlementSuggestion> _suggestions = [];
  List<_BalanceEntry> _balances = [];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _loadData();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final financeService = await ref.read(financeServiceProviderAsync.future);
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupService.listGroups();
      final groupId = groups.isNotEmpty ? groups.first.id : '';
      final expenses = await financeService.listExpenses(groupId);

      if (!mounted) return;

      final now = DateTime.now();
      _balance = 0;
      double balance = 0;
      final timelineMap = <String, List<_Expense>>{};

      for (final exp in expenses) {
        balance += exp.amount;
        final label = _dateLabel(exp.date, now);
        timelineMap.putIfAbsent(label, () => []);
        timelineMap[label]!.add(_Expense(
          description: exp.description,
          amount: exp.amount / 100.0,
          payer: exp.payerId,
          status: 'Pending',
          date: exp.date,
        ));
      }

      _balance = balance / 100.0;
      _timelineGroups = timelineMap.entries
          .map((e) => _ExpenseGroup(label: e.key, expenses: e.value))
          .toList();
      _timelineGroups.sort((a, b) {
        final order = ['Today', 'Yesterday'];
        final ai = order.indexOf(a.label);
        final bi = order.indexOf(b.label);
        if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
        if (ai >= 0) return -1;
        if (bi >= 0) return 1;
        return b.label.compareTo(a.label);
      });
      _suggestions = [];
      _balances = [];

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  String _dateLabel(DateTime date, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMMM d').format(date);
  }



  Color get _balanceColor {
    if (_balance > 0) return MitlistColors.success700;
    if (_balance < 0) return MitlistColors.error700;
    return MitlistColors.neutral900;
  }

  void _onTabChanged(int tab) {
    setState(() => _selectedTab = tab);
  }

  void _maybePlayConfetti() {
    if (_selectedTab == 1 &&
        _suggestions.isEmpty &&
        !_isLoading &&
        !_hasError &&
        !_hasPlayedConfetti) {
      _hasPlayedConfetti = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _confettiController.play();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _maybePlayConfetti();

    return Scaffold(
      appBar: AppBar(title: const Text('Money')),
      body: Column(
        children: [
          // Sticky top section
          Padding(
            padding: const EdgeInsets.all(MitlistSpacing.md),
            child: Column(
              children: [
                _BalanceCard(
                  balance: _balance,
                  balanceColor: _balanceColor,
                  isLoading: _isLoading,
                  onSettleUp: _balance < 0 ? () {} : null,
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
                : _hasError
                    ? _ErrorBody(onRetry: _loadData)
                    : _selectedTab == 0
                        ? _TimelineBody(
                            groups: _timelineGroups,
                            onRefresh: _loadData,
                          )
                        : _SettlementsBody(
                            suggestions: _suggestions,
                            balances: _balances,
                            confettiController: _confettiController,
                            onRefresh: _loadData,
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text('Add expense'),
        icon: const AppIcon(name: 'plus'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Balance card
// ---------------------------------------------------------------------------

class _BalanceCard extends StatelessWidget {
  final double balance;
  final Color balanceColor;
  final bool isLoading;
  final VoidCallback? onSettleUp;

  const _BalanceCard({
    required this.balance,
    required this.balanceColor,
    required this.isLoading,
    this.onSettleUp,
  });

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

    final displayMedium = Theme.of(context).textTheme.displayMedium;
    final balanceStyle = displayMedium?.copyWith(
      fontFamily: MitlistTypography.monoBody().fontFamily,
      color: balanceColor,
    );

    return AppCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR BALANCE',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: MitlistSpacing.sm),
                Text(
                  _formatCurrency(balance),
                  style: balanceStyle,
                ),
              ],
            ),
          ),
          if (onSettleUp != null)
            AppButton(
              text: 'Settle up',
              size: AppButtonSize.sm,
              onPressed: onSettleUp,
            ),
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
    return Row(
      children: [
        AppChip(
          label: 'Timeline',
          selected: selectedTab == 0,
          onSelected: (_) => onTabChanged(0),
        ),
        const SizedBox(width: MitlistSpacing.sm),
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
          const AppSkeleton(
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
  final VoidCallback onRetry;

  const _ErrorBody({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Column(
        children: [
          const AppAlert(
            type: AppAlertType.error,
            message: 'Failed to load expenses. Please try again.',
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

// ---------------------------------------------------------------------------
// Timeline body
// ---------------------------------------------------------------------------

class _TimelineBody extends StatelessWidget {
  final List<_ExpenseGroup> groups;
  final Future<void> Function() onRefresh;

  const _TimelineBody({
    required this.groups,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return RefreshIndicator(
        color: MitlistColors.primary500,
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
                    icon: const AppIcon(name: 'receiptPercent', size: 56),
                    title: 'No expenses yet',
                    description: 'Track shared costs with your household.',
                    actions: [
                      AppButton(
                        text: 'Add first expense',
                        onPressed: () {},
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
      color: MitlistColors.primary500,
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          for (final group in groups) ...[
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyDateHeaderDelegate(
                height: MitlistSpacing.space10,
                child: Container(
                  color: MitlistColors.surfaceSoft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: MitlistSpacing.md,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    group.label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium,
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
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: MitlistSpacing.sm,
                      ),
                      child: _ExpenseCard(expense: expense),
                    );
                  },
                  childCount: group.expenses.length,
                ),
              ),
            ),
          ],
          const SliverPadding(
            padding: EdgeInsets.only(bottom: MitlistSpacing.space12),
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
  bool shouldRebuild(covariant _StickyDateHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

// ---------------------------------------------------------------------------
// Expense card
// ---------------------------------------------------------------------------

class _ExpenseCard extends StatelessWidget {
  final _Expense expense;

  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.outlined,
      interactive: true,
      onTap: () {},
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: MitlistSpacing.space1),
                Text(
                  'Paid by ${expense.payer}',
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
                _formatCurrency(expense.amount),
                style: MitlistTypography.monoBody(),
              ),
              const SizedBox(height: MitlistSpacing.space1),
              AppChip(
                label: expense.status,
                selected: expense.status.toLowerCase() == 'settled',
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
  final ConfettiController confettiController;
  final Future<void> Function() onRefresh;

  const _SettlementsBody({
    required this.suggestions,
    required this.balances,
    required this.confettiController,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: MitlistColors.primary500,
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (suggestions.isNotEmpty)
              ...suggestions.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
                  child: _SuggestionCard(suggestion: s),
                ),
              )
            else
              Stack(
                alignment: Alignment.center,
                children: [
                  AppEmptyState(
                    icon: const AppIcon(name: 'checkCircle', size: 56),
                    title: 'All settled up!',
                    description: 'The household tab is clear.',
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
            _BalancesSection(balances: balances),
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

  const _SuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.elevated,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${suggestion.from} → ${suggestion.to}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: MitlistSpacing.space1),
                Text(
                  _formatCurrency(suggestion.amount),
                  style: MitlistTypography.monoBody(),
                ),
              ],
            ),
          ),
          AppButton(
            text: 'Pay',
            size: AppButtonSize.sm,
            onPressed: () {},
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

  const _BalancesSection({required this.balances});

  Color _balanceColor(double amount) {
    if (amount > 0) return MitlistColors.success700;
    if (amount < 0) return MitlistColors.error700;
    return MitlistColors.neutral900;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.none,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          iconColor: MitlistColors.textPrimary,
          collapsedIconColor: MitlistColors.textPrimary,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
          ),
          childrenPadding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
          ),
          title: Text(
            'BALANCES',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          children: [
            const Divider(
              height: 1,
              color: MitlistColors.borderSecondary,
            ),
            const SizedBox(height: MitlistSpacing.sm),
            ...balances.map((b) {
              return Padding(
                padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      b.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      _formatCurrency(b.amount),
                      style: MitlistTypography.monoBody(
                        color: _balanceColor(b.amount),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: MitlistSpacing.sm),
          ],
        ),
      ),
    );
  }
}
