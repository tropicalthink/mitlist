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
    this.trackedCount,
    this.lastTrackedAt,
    this.lastDoneByLabel,
    this.averageFrequencyHours,
    this.onMarkDone,
    this.onSkip,
    this.onRescheduleTomorrow,
    this.onUndo,
  });

  final String title;
  final String statusLabel;
  final String assignee;
  final DateTime dueDate;
  final int? trackedCount;
  final DateTime? lastTrackedAt;
  final String? lastDoneByLabel;
  final double? averageFrequencyHours;
  final VoidCallback? onMarkDone;
  final VoidCallback? onSkip;
  final VoidCallback? onRescheduleTomorrow;
  final VoidCallback? onUndo;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String statusLabel,
    required String assignee,
    required DateTime dueDate,
    int? trackedCount,
    DateTime? lastTrackedAt,
    String? lastDoneByLabel,
    double? averageFrequencyHours,
    VoidCallback? onMarkDone,
    VoidCallback? onSkip,
    VoidCallback? onRescheduleTomorrow,
    VoidCallback? onUndo,
  }) async {
    return showAppBottomSheet(
      context: context,
      title: 'Chore Details',
      body: ChoreDetailSheet(
        title: title,
        statusLabel: statusLabel,
        assignee: assignee,
        dueDate: dueDate,
        trackedCount: trackedCount,
        lastTrackedAt: lastTrackedAt,
        lastDoneByLabel: lastDoneByLabel,
        averageFrequencyHours: averageFrequencyHours,
        onMarkDone: onMarkDone,
        onSkip: onSkip,
        onRescheduleTomorrow: onRescheduleTomorrow,
        onUndo: onUndo,
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
              _DetailRow(
                label: 'Due',
                value: DateFormat.yMMMd().format(dueDate),
              ),
              if (trackedCount != null) ...[
                const Divider(),
                _DetailRow(label: 'Tracked', value: trackedCount.toString()),
              ],
              if (lastTrackedAt != null) ...[
                const Divider(),
                _DetailRow(
                  label: 'Last done',
                  value: DateFormat.yMMMd().format(lastTrackedAt!),
                ),
              ],
              if (lastDoneByLabel != null && lastDoneByLabel!.isNotEmpty) ...[
                const Divider(),
                _DetailRow(label: 'Last by', value: lastDoneByLabel!),
              ],
              if (averageFrequencyHours != null) ...[
                const Divider(),
                _DetailRow(
                  label: 'Average',
                  value: _formatAverageFrequency(averageFrequencyHours!),
                ),
              ],
            ],
          ),
        ),
        if (onMarkDone != null ||
            onSkip != null ||
            onRescheduleTomorrow != null ||
            onUndo != null) ...[
          const SizedBox(height: MitlistSpacing.lg),
          if (onMarkDone != null)
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
          if (onSkip != null) ...[
            const SizedBox(height: MitlistSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                variant: AppButtonVariant.outline,
                color: AppButtonColor.neutral,
                size: AppButtonSize.lg,
                text: 'Skip',
                onPressed: onSkip,
              ),
            ),
          ],
          if (onRescheduleTomorrow != null) ...[
            const SizedBox(height: MitlistSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                variant: AppButtonVariant.outline,
                color: AppButtonColor.primary,
                size: AppButtonSize.lg,
                text: 'Move to Tomorrow',
                onPressed: onRescheduleTomorrow,
              ),
            ),
          ],
          if (onUndo != null) ...[
            const SizedBox(height: MitlistSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                variant: AppButtonVariant.ghost,
                color: AppButtonColor.neutral,
                size: AppButtonSize.lg,
                text: 'Undo Last Execution',
                onPressed: onUndo,
              ),
            ),
          ],
        ],
      ],
    );
  }

  String _formatAverageFrequency(double hours) {
    if (hours < 24) {
      return '${hours.round()} h';
    }
    final days = hours / 24;
    if (days < 14) {
      return '${days.toStringAsFixed(days >= 10 ? 0 : 1)} d';
    }
    final weeks = days / 7;
    return '${weeks.toStringAsFixed(weeks >= 10 ? 0 : 1)} wk';
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
