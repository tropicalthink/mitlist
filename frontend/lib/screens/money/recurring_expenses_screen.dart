import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/finance_models.dart';
import '../../providers/finance_provider.dart';
import '../../providers/group_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/active_group_context.dart';
import '../../utils/format_currency.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final groups = await ref.read(cachedGroupsProvider.future);
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (!isValidGroupId(groupId)) {
        setState(() {
          _hasHousehold = false;
          _isLoading = false;
        });
        return;
      }
      final financeService = await ref.read(financeServiceProviderAsync.future);
      final items = await financeService.listRecurringExpenses(groupId!);
      final summary = await financeService.getFinanceSummary(groupId);
      setState(() {
        _items.clear();
        _items.addAll(items);
        _userLabels = {
          for (final e in summary.balances) e.userId: e.displayName,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleActive(RecurringExpense item) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\u2019t update recurring expense.')),
      );
    } finally {
      if (mounted) setState(() => _submittingId = null);
    }
  }

  Future<void> _deleteItem(String id) async {
    setState(() => _submittingId = id);
    try {
      final service = await ref.read(financeServiceProviderAsync.future);
      await service.deleteRecurringExpense(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\u2019t delete recurring expense.')),
      );
    } finally {
      if (mounted) setState(() => _submittingId = null);
    }
  }

  String _formatFrequency(String frequency) {
    return switch (frequency) {
      'daily' => 'Daily',
      'weekly' => 'Weekly',
      'biweekly' => 'Every 2 weeks',
      'monthly' => 'Monthly',
      'quarterly' => 'Quarterly',
      'yearly' => 'Yearly',
      _ => frequency,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MitlistAppBar(title: Text('Recurring')),
      body: _buildBody(),
      floatingActionButton: !_hasHousehold || _isLoading
          ? null
          : AppButton(
              size: AppButtonSize.lg,
              onPressed: () => _openCreateSheet(),
              text: 'Add recurring',
              icon: const AppIcon(name: 'plus'),
              tooltip: 'Add recurring expense',
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        itemCount: 6,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: MitlistSpacing.sm),
          child: AppSkeleton(width: double.infinity, height: 72),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/404.lottie',
          icon: const AppIcon(name: 'alertCircleOutline'),
          title: 'Something went wrong',
          description: _error,
          actions: [
            AppButton(
              variant: AppButtonVariant.outline,
              text: 'Retry',
              onPressed: _load,
            ),
          ],
        ),
      );
    }
    if (!_hasHousehold) {
      return const Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/House.lottie',
          icon: AppIcon(name: 'homeOutline'),
          title: 'No household yet',
          description: 'Join or create a household to manage recurring expenses',
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/wallet.lottie',
          icon: AppIcon(name: 'repeat'),
          title: 'No recurring expenses',
          description: 'Add a recurring expense to track regular payments',
          actions: [
            AppButton(
              text: 'Add expense',
              variant: AppButtonVariant.outline,
              size: AppButtonSize.sm,
              onPressed: _openCreateSheet,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _RecurringCard(
          item: item,
          payerName: _userLabels[item.payerId] ?? item.payerId,
          formatFrequency: _formatFrequency,
          onToggle: () => _toggleActive(item),
          onDelete: () => _deleteItem(item.id),
          isSubmitting: _submittingId == item.id,
        );
      },
    );
  }

  Future<void> _openCreateSheet() async {
    final groups = await ref.read(cachedGroupsProvider.future);
    final groupId = resolveActiveGroupId(
      groups,
      ref.read(currentGroupIdProvider),
    );
    if (!isValidGroupId(groupId)) return;
    if (!mounted) return;

    final result = await showModalBottomSheet<_CreateRecurringResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _RecurringCreationSheet(
        userLabels: _userLabels,
        groupId: groupId!,
      ),
    );
    if (result == null) return;

    setState(() => _submittingId = 'create');
    try {
      final service = await ref.read(financeServiceProviderAsync.future);
      await service.createRecurringExpense(
        CreateRecurringExpenseRequest(
          groupId: result.groupId,
          payerId: result.payerId,
          amount: result.amount,
          description: result.description,
          category: result.category,
          frequency: result.frequency,
          nextDue: result.nextDue,
          isActive: true,
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\u2019t create recurring expense.')),
      );
    } finally {
      if (mounted) setState(() => _submittingId = null);
    }
  }
}

class _RecurringCard extends StatelessWidget {
  final RecurringExpense item;
  final String payerName;
  final String Function(String frequency) formatFrequency;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final bool isSubmitting;

  const _RecurringCard({
    required this.item,
    required this.payerName,
    required this.formatFrequency,
    required this.onToggle,
    required this.onDelete,
    required this.isSubmitting,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isActive = item.isActive;

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
      child: AppCard(
        variant: AppCardVariant.outlined,
        padding: AppCardPadding.md,
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
                    'Next: ${_formatDate(item.nextDue)}',
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
                tooltip: isActive ? 'Pause' : 'Resume',
                onPressed: onToggle,
              ),
              IconButton(
                icon: const AppIcon(name: 'trashOutline'),
                tooltip: 'Delete',
                onPressed: () async {
                  final confirmed = await showAppDialog<bool>(
                    context: context,
                    title: 'Delete recurring expense',
                    body: const Text(
                      'This will stop future expenses from being created.'),
                    actions: [
                      AppButton(
                        text: 'Cancel',
                        variant: AppButtonVariant.outline,
                        onPressed: () =>
                            Navigator.of(context).pop(false),
                      ),
                      const SizedBox(width: MitlistSpacing.sm),
                      AppButton(
                        text: 'Delete',
                        color: AppButtonColor.error,
                        onPressed: () =>
                            Navigator.of(context).pop(true),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return DateFormat('MMM d, y').format(date);
  }
}

class _RecurringCreationSheet extends StatelessWidget {
  final Map<String, String> userLabels;
  final String groupId;

  const _RecurringCreationSheet({required this.userLabels, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: MitlistSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Add recurring expense',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: MitlistSpacing.md),
            _CreateRecurringForm(userLabels: userLabels, groupId: groupId),
          ],
        ),
      ),
    );
  }
}

class _CreateRecurringResult {
  final String groupId;
  final String payerId;
  final int amount;
  final String description;
  final String category;
  final String frequency;
  final DateTime nextDue;

  const _CreateRecurringResult({
    required this.groupId,
    required this.payerId,
    required this.amount,
    required this.description,
    required this.category,
    required this.frequency,
    required this.nextDue,
  });
}

class _CreateRecurringForm extends StatefulWidget {
  final Map<String, String> userLabels;
  final String groupId;
  const _CreateRecurringForm({
    required this.userLabels,
    required this.groupId,
  });

  @override
  State<_CreateRecurringForm> createState() => _CreateRecurringFormState();
}

class _CreateRecurringFormState extends State<_CreateRecurringForm> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _frequency = 'monthly';
  String? _payerId;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.userLabels.isNotEmpty) {
      _payerId = widget.userLabels.keys.first;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
          ),
          const SizedBox(height: MitlistSpacing.sm),
        ],
        AppInput(
          controller: _descriptionController,
          label: 'Description',
        ),
        const SizedBox(height: MitlistSpacing.sm),
        AppInput(
          controller: _amountController,
          label: 'Amount',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: _frequency,
          decoration: const InputDecoration(labelText: 'Frequency'),
          items: const [
            DropdownMenuItem(value: 'daily', child: Text('Daily')),
            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
            DropdownMenuItem(value: 'biweekly', child: Text('Every 2 weeks')),
            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
            DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
            DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
          ],
          onChanged: (v) => setState(() => _frequency = v!),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: _payerId,
          decoration: const InputDecoration(labelText: 'Payer'),
          items: widget.userLabels.isEmpty
              ? const [DropdownMenuItem(value: null, child: Text('Loading members...'))]
              : widget.userLabels.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
          onChanged: widget.userLabels.isEmpty ? null : (v) => setState(() => _payerId = v),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppButton(
              variant: AppButtonVariant.outline,
              color: AppButtonColor.neutral,
              text: 'Cancel',
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            AppButton(
              variant: AppButtonVariant.solid,
              text: 'Save',
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }

  void _submit() {
    final description = _descriptionController.text.trim();
    final amountText = _amountController.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Enter a description.');
      return;
    }
    if (amountText.isEmpty) {
      setState(() => _error = 'Enter an amount.');
      return;
    }
    if (_payerId == null) {
      setState(() => _error = 'Select a payer.');
      return;
    }

    final amount = double.tryParse(amountText.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount greater than zero.');
      return;
    }

    Navigator.of(context).pop(_CreateRecurringResult(
      groupId: widget.groupId,
      payerId: _payerId!,
      amount: (amount * 100).round(),
      description: description,
      category: 'other',
      frequency: _frequency,
      nextDue: DateTime.now().add(const Duration(days: 1)),
    ));
  }
}
