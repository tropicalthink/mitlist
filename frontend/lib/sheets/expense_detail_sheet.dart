import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/chip.dart';

class ExpenseDetailSheet extends StatelessWidget {
  const ExpenseDetailSheet({super.key});

  static Future<void> show(BuildContext context) async {
    return showAppBottomSheet(
      context: context,
      title: 'Expense Details',
      body: const ExpenseDetailSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const AppChip(
              label: 'Unsettled',
              selected: true,
            ),
            const SizedBox(width: MitlistSpacing.sm),
            AppChip(
              label: 'Shared',
              selected: false,
              onSelected: (_) {},
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Dinner at Luigi\'s',
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Text(
          '€48.00',
          style: MitlistTypography.monoBody(color: MitlistColors.textPrimary),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Splits'.toUpperCase(),
          style: MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppCardPadding.md,
          child: Column(
            children: [
              _SplitRow(name: 'You', amount: '€16.00', isPayer: true),
              const Divider(),
              _SplitRow(name: 'Alex', amount: '€16.00'),
              const Divider(),
              _SplitRow(name: 'Jordan', amount: '€16.00'),
            ],
          ),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'History'.toUpperCase(),
          style: MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppCardPadding.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HistoryRow(label: 'Created', value: '24 Apr 2026'),
              const SizedBox(height: MitlistSpacing.sm),
              _HistoryRow(label: 'Last edited', value: '24 Apr 2026'),
            ],
          ),
        ),
        const SizedBox(height: MitlistSpacing.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.outline,
                color: AppButtonColor.primary,
                size: AppButtonSize.lg,
                text: 'Edit',
                onPressed: () {},
              ),
            ),
            const SizedBox(width: MitlistSpacing.md),
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.soft,
                color: AppButtonColor.error,
                size: AppButtonSize.lg,
                text: 'Delete',
                onPressed: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({required this.name, required this.amount, this.isPayer = false});

  final String name;
  final String amount;
  final bool isPayer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (isPayer)
            Padding(
              padding: const EdgeInsets.only(right: MitlistSpacing.sm),
              child: Text(
                'Payer'.toUpperCase(),
                style: MitlistTypography.labelXSmall(color: MitlistColors.primary600),
              ),
            ),
          Text(
            amount,
            style: MitlistTypography.monoBody(color: MitlistColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Text(
          value,
          style: MitlistTypography.monoBody(color: MitlistColors.textSecondary),
        ),
      ],
    );
  }
}
