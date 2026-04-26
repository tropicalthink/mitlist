import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_card.dart';

class ExpenseDetailSheet extends StatelessWidget {
  const ExpenseDetailSheet({
    super.key,
    required this.description,
    required this.amountLabel,
    required this.payer,
    required this.createdAt,
  });

  final String description;
  final String amountLabel;
  final String payer;
  final DateTime createdAt;

  static Future<void> show(
    BuildContext context, {
    required String description,
    required String amountLabel,
    required String payer,
    required DateTime createdAt,
  }) async {
    return showAppBottomSheet(
      context: context,
      title: 'Expense Details',
      body: ExpenseDetailSheet(
        description: description,
        amountLabel: amountLabel,
        payer: payer,
        createdAt: createdAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Text(
          amountLabel,
          style: MitlistTypography.monoBody(color: MitlistColors.textPrimary),
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppCardPadding.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HistoryRow(label: 'Paid by', value: payer),
              const SizedBox(height: MitlistSpacing.sm),
              _HistoryRow(label: 'Created', value: DateFormat.yMMMd().format(createdAt)),
            ],
          ),
        ),
      ],
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
