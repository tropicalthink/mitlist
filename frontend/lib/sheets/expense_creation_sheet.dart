import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/finance_models.dart';
import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/group_provider.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

class ExpenseCreationSheet extends ConsumerStatefulWidget {
  const ExpenseCreationSheet({super.key});

  static Future<bool?> show(BuildContext context) async {
    return showAppBottomSheet<bool>(
      context: context,
      title: 'Add Expense',
      body: const ExpenseCreationSheet(),
    );
  }

  @override
  ConsumerState<ExpenseCreationSheet> createState() => _ExpenseCreationSheetState();
}

class _ExpenseCreationSheetState extends ConsumerState<ExpenseCreationSheet> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isSaving = false;

  bool get _canCreate =>
      _descriptionController.text.trim().isNotEmpty &&
      _amountController.text.trim().isNotEmpty &&
      !_isSaving;

  Future<void> _onCreate() async {
    if (!_canCreate) return;

    final amount = _parseAmountToCents(_amountController.text);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final financeService = await ref.read(financeServiceProviderAsync.future);
      final groups = await groupService.listGroups(limit: 1);

      if (!mounted) return;
      if (groups.isEmpty) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create or join a household first.')),
        );
        return;
      }

      final me = await authService.getMe();
      await financeService.createExpense(
        CreateExpenseRequest(
          groupId: groups.first.id,
          payerId: me.id,
          amount: amount,
          description: _descriptionController.text.trim(),
          date: DateTime.now().toUtc(),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense added')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add expense: $e')),
      );
    }
  }

  int? _parseAmountToCents(String value) {
    final normalized = value.replaceAll(',', '.').trim();
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return (parsed * 100).round();
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput(
          label: 'Description',
          hint: 'e.g. Dinner at Luigi\'s',
          controller: _descriptionController,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: 'Amount',
          hint: '0.00',
          controller: _amountController,
          textInputAction: TextInputAction.done,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'New expenses are recorded under your account and dated today.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: MitlistColors.textSecondary,
              ),
        ),
        const SizedBox(height: MitlistSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            text: _isSaving ? 'Adding...' : 'Add Expense',
            isLoading: _isSaving,
            onPressed: _canCreate ? _onCreate : null,
          ),
        ),
      ],
    );
  }
}
