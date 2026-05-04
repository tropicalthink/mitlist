import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';

class CostSummarySheet extends ConsumerStatefulWidget {
  const CostSummarySheet({
    super.key,
    required this.listName,
    required this.totalCents,
    required this.equalShareCents,
    required this.itemCount,
    required this.onGenerateExpense,
  });

  final String listName;
  final int totalCents;
  final int equalShareCents;
  final int itemCount;
  final VoidCallback? onGenerateExpense;

  static Future<void> show(
    BuildContext context, {
    required String listName,
    required int totalCents,
    required int equalShareCents,
    required int itemCount,
    required VoidCallback? onGenerateExpense,
  }) async {
    return showAppBottomSheet(
      context: context,
      title: 'Cost Summary',
      body: CostSummarySheet(
        listName: listName,
        totalCents: totalCents,
        equalShareCents: equalShareCents,
        itemCount: itemCount,
        onGenerateExpense: onGenerateExpense,
      ),
    );
  }

  @override
  ConsumerState<CostSummarySheet> createState() => _CostSummarySheetState();
}

class _CostSummarySheetState extends ConsumerState<CostSummarySheet> {
  bool _isSaving = false;

  String _formatCents(int cents) {
    return '\$${(cents / 100).toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final hasPrices = widget.totalCents > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.listName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: MitlistSpacing.md),
        if (!hasPrices) ...[
          _InfoRow(
            icon: Icons.info_outline,
            message:
                'No items have prices yet. Open the item options (⋯) and choose Set price to see the cost summary.',
          ),
        ] else ...[
          _CostRow(
            label: 'Total cost',
            value: _formatCents(widget.totalCents),
            isTotal: true,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          _CostRow(
            label: 'Equal share per person',
            value: _formatCents(widget.equalShareCents),
            isTotal: false,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          _CostRow(
            label: 'Items with prices',
            value: '${widget.itemCount}',
            isTotal: false,
          ),
          const SizedBox(height: MitlistSpacing.md),
          if (widget.onGenerateExpense != null)
            SizedBox(
              width: double.infinity,
              child: AppButton(
                variant: AppButtonVariant.solid,
                color: AppButtonColor.primary,
                text: 'Generate Expense',
                onPressed: _isSaving
                    ? null
                    : () async {
                        if (_isSaving) return;
                        _isSaving = true;
                        try {
                          widget.onGenerateExpense!();
                        } finally {
                          _isSaving = false;
                        }
                      },
              ),
            ),
        ],
      ],
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({
    required this.label,
    required this.value,
    required this.isTotal,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isTotal
                ? Theme.of(context).textTheme.titleSmall
                : Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: isTotal
              ? Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: MitlistColors.primary500,
                    fontWeight: FontWeight.bold,
                  )
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: MitlistColors.neutral500),
        const SizedBox(width: MitlistSpacing.sm),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MitlistColors.neutral500,
                ),
          ),
        ),
      ],
    );
  }
}
