import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/chip.dart';

class ChoreDetailSheet extends StatelessWidget {
  const ChoreDetailSheet({super.key});

  static Future<void> show(BuildContext context) async {
    return showAppBottomSheet(
      context: context,
      title: 'Chore Details',
      body: const ChoreDetailSheet(),
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
              label: 'Pending',
              selected: true,
            ),
            const SizedBox(width: MitlistSpacing.sm),
            AppChip(
              label: 'Weekly',
              selected: false,
              onSelected: (_) {},
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Vacuum living room',
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppCardPadding.md,
          child: Column(
            children: [
              _DetailRow(label: 'Assignee', value: 'Alex'),
              const Divider(),
              _DetailRow(label: 'Due', value: '26 Apr 2026'),
              const Divider(),
              _DetailRow(label: 'Recurrence', value: 'Weekly'),
            ],
          ),
        ),
        const SizedBox(height: MitlistSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.success,
            size: AppButtonSize.lg,
            text: 'Mark Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppButton(
                variant: AppButtonVariant.outline,
                color: AppButtonColor.primary,
                size: AppButtonSize.lg,
                text: 'Reassign',
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
