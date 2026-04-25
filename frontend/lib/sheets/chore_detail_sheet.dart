import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/chip.dart';

class ChoreDetailSheet extends StatelessWidget {
  const ChoreDetailSheet({
    super.key,
    required this.title,
    required this.statusLabel,
    required this.assignee,
    required this.dueDate,
    this.onMarkDone,
  });

  final String title;
  final String statusLabel;
  final String assignee;
  final DateTime dueDate;
  final VoidCallback? onMarkDone;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String statusLabel,
    required String assignee,
    required DateTime dueDate,
    VoidCallback? onMarkDone,
  }) async {
    return showAppBottomSheet(
      context: context,
      title: 'Chore Details',
      body: ChoreDetailSheet(
        title: title,
        statusLabel: statusLabel,
        assignee: assignee,
        dueDate: dueDate,
        onMarkDone: onMarkDone,
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
        AppChip(
          label: statusLabel,
          selected: true,
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          title,
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppCardPadding.md,
          child: Column(
            children: [
              _DetailRow(label: 'Assignee', value: assignee),
              const Divider(),
              _DetailRow(label: 'Due', value: DateFormat.yMMMd().format(dueDate)),
            ],
          ),
        ),
        if (onMarkDone != null) ...[
          const SizedBox(height: MitlistSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              variant: AppButtonVariant.solid,
              color: AppButtonColor.success,
              size: AppButtonSize.lg,
              text: 'Mark Done',
              onPressed: onMarkDone,
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: MitlistTypography.monoBody(color: MitlistColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
