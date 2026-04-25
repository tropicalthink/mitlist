import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/chip.dart';

enum _SplitType { equal, percentage, manual }

class ExpenseCreationSheet extends StatefulWidget {
  const ExpenseCreationSheet({super.key});

  static Future<void> show(BuildContext context) async {
    return showAppBottomSheet(
      context: context,
      title: 'Add Expense',
      body: const ExpenseCreationSheet(),
    );
  }

  @override
  State<ExpenseCreationSheet> createState() => _ExpenseCreationSheetState();
}

class _ExpenseCreationSheetState extends State<ExpenseCreationSheet> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String? _selectedPayer;
  _SplitType _splitType = _SplitType.equal;

  final List<String> _payers = const ['You', 'Alex', 'Jordan', 'Sam'];

  bool get _canCreate =>
      _descriptionController.text.trim().isNotEmpty &&
      _amountController.text.trim().isNotEmpty &&
      _selectedPayer != null;

  void _onCreate() {
    if (!_canCreate) return;
    Navigator.of(context).pop();
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
          'Payer'.toUpperCase(),
          style: MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: _payers.map((payer) {
            return AppChip(
              label: payer,
              selected: _selectedPayer == payer,
              onSelected: (_) => setState(() => _selectedPayer = payer),
            );
          }).toList(),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Split'.toUpperCase(),
          style: MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: [
            AppChip(
              label: 'Equal',
              selected: _splitType == _SplitType.equal,
              onSelected: (_) => setState(() => _splitType = _SplitType.equal),
            ),
            AppChip(
              label: 'Percentage',
              selected: _splitType == _SplitType.percentage,
              onSelected: (_) => setState(() => _splitType = _SplitType.percentage),
            ),
            AppChip(
              label: 'Manual',
              selected: _splitType == _SplitType.manual,
              onSelected: (_) => setState(() => _splitType = _SplitType.manual),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            text: 'Add Expense',
            onPressed: _canCreate ? _onCreate : null,
          ),
        ),
      ],
    );
  }
}
