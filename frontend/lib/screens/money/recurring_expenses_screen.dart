import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/finance_models.dart';
import '../../providers/finance_provider.dart';
import '../../providers/group_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../sheets/expense_creation_sheet.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/active_group_context.dart';
import '../../utils/format_currency.dart';
import '../../utils/friendly_error.dart';
import '../../utils/latest_request_guard.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';

class RecurringExpensesScreen extends ConsumerStatefulWidget {
  const RecurringExpensesScreen({super.key});

  @override
  ConsumerState<RecurringExpensesScreen> createState() =>
      _RecurringExpensesScreenState();
}

class _RecurringExpensesScreenState
    extends ConsumerState<RecurringExpensesScreen> {
  bool _isLoading = true;
  String? _error;
  bool _hasHousehold = true;
  final List<RecurringExpense> _items = [];
  Map<String, String> _userLabels = {};
  String? _submittingId;
  final LatestRequestGuard _loadGuard = LatestRequestGuard();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _loadGuard.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = _loadGuard.begin();
    final hadContent = _items.isNotEmpty;
    setState(() {
      _isLoading = !hadContent;
      _error = null;
    });
    try {
      final groups = await ref.read(cachedGroupsProvider.future);
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (!isValidGroupId(groupId)) {
        if (!mounted || !_loadGuard.isCurrent(request)) return;
        setState(() {
          _items.clear();
          _hasHousehold = false;
          _isLoading = false;
        });
        return;
      }
      final financeService = await ref.read(financeServiceProviderAsync.future);
      final items = await financeService.listRecurringExpenses(groupId!);
      final summary = await financeService.getFinanceSummary(groupId);
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      setState(() {
        _items.clear();
        _items.addAll(items);
        _userLabels = {
          for (final e in summary.balances) e.userId: e.displayName,
        };
        _hasHousehold = true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      final message = friendlyErrorMessage(e, AppLocalizations.of(context)!);
      if (hadContent) {
        setState(() => _isLoading = false);
        AppToast.error(context, message);
        return;
      }
      setState(() {
        _error = message;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleActive(RecurringExpense item) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _submittingId = item.id);
    try {
      final service = await ref.read(financeServiceProviderAsync.future);
      await service.updateRecurringExpense(
        item.id,
        UpdateRecurringExpenseRequest(isActive: !item.isActive),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, l10n.recurringCouldNotUpdate);
    } finally {
      if (mounted) setState(() => _submittingId = null);
    }
  }

  Future<void> _deleteItem(String id) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _submittingId = id);
    try {
      final service = await ref.read(financeServiceProviderAsync.future);
      await service.deleteRecurringExpense(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, l10n.recurringCouldNotDelete);
    } finally {
      if (mounted) setState(() => _submittingId = null);
    }
  }

  String _formatFrequency(String frequency) {
    final l10n = AppLocalizations.of(context)!;
    return switch (frequency) {
      'daily' => l10n.recurringFrequencyDaily,
      'weekly' => l10n.recurringFrequencyWeekly,
      'biweekly' => l10n.recurringFrequencyBiweekly,
      'monthly' => l10n.recurringFrequencyMonthly,
      'quarterly' => l10n.recurringFrequencyQuarterly,
      'yearly' => l10n.recurringFrequencyYearly,
      _ => frequency,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: MitlistAppBar(title: Text(l10n.recurringAppBarTitle)),
      body: _buildBody(),
      floatingActionButton: !_hasHousehold || _isLoading
          ? null
          : AppButton(
              size: AppButtonSize.lg,
              onPressed: () => _openSheet(),
              text: l10n.recurringAddRecurring,
              icon: const AppIcon(name: 'plus'),
              tooltip: l10n.recurringAddRecurringTooltip,
            ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: _load,
      child: _buildBodyContent(),
    );
  }

  Widget _wrapForRefresh(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildBodyContent() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(MitlistSpacing.md),
        itemCount: 6,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: MitlistSpacing.sm),
          child: AppSkeleton(width: double.infinity, height: 72),
        ),
      );
    }
    if (_error != null) {
      return _wrapForRefresh(
        Center(
          child: AppEmptyState(
            lottieAsset: 'assets/animations/lottie/404.lottie',
            icon: const AppIcon(name: 'alertCircleOutline'),
            title: l10n.commonSomethingWentWrong,
            description: _error,
            actions: [
              AppButton(
                variant: AppButtonVariant.outline,
                text: l10n.commonRetry,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }
    if (!_hasHousehold) {
      return _wrapForRefresh(
        Center(
          child: AppEmptyState(
            lottieAsset: 'assets/animations/lottie/House.lottie',
            icon: const AppIcon(name: 'homeOutline'),
            title: l10n.commonNoHousehold,
            description: l10n.recurringNoHouseholdDesc,
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return _wrapForRefresh(
        Center(
          child: AppEmptyState(
            lottieAsset: 'assets/animations/lottie/wallet.lottie',
            icon: const AppIcon(name: 'repeat'),
            title: l10n.recurringNoRecurringTitle,
            description: l10n.recurringNoRecurringDesc,
            actions: [
              AppButton(
                text: l10n.recurringAddExpense,
                variant: AppButtonVariant.outline,
                size: AppButtonSize.sm,
                onPressed: () => _openSheet(),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MitlistSpacing.md),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _RecurringCard(
          item: item,
          payerName: _userLabels[item.payerId] ?? item.payerId,
          formatFrequency: _formatFrequency,
          onEdit: () => _openSheet(existing: item),
          onToggle: () => _toggleActive(item),
          onDelete: () => _deleteItem(item.id),
          isSubmitting: _submittingId == item.id,
        );
      },
    );
  }

  /// Both create and edit route through the one expense editor, so a recurring
  /// rule gets the same payer, split, category and currency handling as a
  /// one-off expense instead of a parallel, thinner form.
  Future<void> _openSheet({RecurringExpense? existing}) async {
    final saved = await ExpenseCreationSheet.showRecurring(
      context,
      existing: existing,
    );
    if (saved == true && mounted) await _load();
  }
}

class _RecurringCard extends StatelessWidget {
  final RecurringExpense item;
  final String payerName;
  final String Function(String frequency) formatFrequency;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final bool isSubmitting;

  const _RecurringCard({
    required this.item,
    required this.payerName,
    required this.formatFrequency,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.isSubmitting,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final isActive = item.isActive;

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
      child: AppCard(
        variant: AppCardVariant.outlined,
        padding: AppCardPadding.md,
        interactive: !isSubmitting,
        onTap: isSubmitting ? null : onEdit,
        semanticLabel: l10n.recurringEditTooltip,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.description,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: isActive ? null : TextDecoration.lineThrough,
                      color: isActive
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: MitlistSpacing.space1),
                  Text(
                    '${formatCurrency(item.amount, item.currency)} · ${formatFrequency(item.frequency)} · $payerName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MitlistTypography.labelXSmall(),
                  ),
                  const SizedBox(height: MitlistSpacing.space1),
                  Text(
                    l10n.recurringNextDate(_formatDate(item.nextDue, l10n)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MitlistTypography.labelXSmall(),
                  ),
                ],
              ),
            ),
            if (isSubmitting)
              SizedBox(
                width: MitlistSpacing.space5,
                height: MitlistSpacing.space5,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              IconButton(
                icon: AppIcon(
                  name: isActive ? 'pauseCircleOutline' : 'playCircleOutline',
                ),
                tooltip: isActive
                    ? l10n.recurringPauseTooltip
                    : l10n.recurringResumeTooltip,
                onPressed: onToggle,
              ),
              IconButton(
                icon: const AppIcon(name: 'trashOutline'),
                tooltip: l10n.recurringDeleteTooltip,
                onPressed: () async {
                  final confirmed = await showAppDialog<bool>(
                    context: context,
                    title: l10n.recurringDeleteTitle,
                    body: Text(l10n.recurringDeleteBody),
                    actions: [
                      AppButton(
                        text: l10n.commonCancel,
                        variant: AppButtonVariant.outline,
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true)
                                .pop(false),
                      ),
                      const SizedBox(width: MitlistSpacing.sm),
                      AppButton(
                        text: l10n.commonDelete,
                        color: AppButtonColor.error,
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true)
                                .pop(true),
                      ),
                    ],
                  );
                  if (confirmed == true) onDelete();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date, AppLocalizations l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return l10n.expenseToday;
    if (diff == 1) return l10n.recurringTomorrow;
    if (diff == -1) return l10n.expenseYesterday;
    return DateFormat('MMM d, y').format(date);
  }
}
