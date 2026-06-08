import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/spacing.dart';
import '../utils/format_currency.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon.dart';

class CostSummarySheet extends ConsumerWidget {
  const CostSummarySheet({
    super.key,
    required this.listName,
    required this.totalCents,
    required this.equalShareCents,
    required this.itemCount,
    required this.onGenerateExpense,
    this.currencyCode = 'USD',
  });

  final String listName;
  final int totalCents;
  final int equalShareCents;
  final int itemCount;
  final VoidCallback? onGenerateExpense;
  final String currencyCode;

  static Future<void> show(
    BuildContext context, {
    required String listName,
    required int totalCents,
    required int equalShareCents,
    required int itemCount,
    required VoidCallback? onGenerateExpense,
    String currencyCode = 'USD',
  }) async {
    return showAppBottomSheet(
      context: context,
      title: 'Cost summary',
      body: CostSummarySheet(
        listName: listName,
        totalCents: totalCents,
        equalShareCents: equalShareCents,
        itemCount: itemCount,
        onGenerateExpense: onGenerateExpense,
        currencyCode: currencyCode,
      ),
    );
  }

  String _formatCents(int cents) {
    return formatCurrency(cents, currencyCode);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPrices = totalCents > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          listName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: MitlistSpacing.md),
        if (!hasPrices) ...[
          _InfoRow(
            iconName: 'infoOutline',
            message:
                'No items have prices yet. Open the item options (⋯) and choose Set price to see the cost summary.',
          ),
        ] else ...[
          _CostRow(
            label: 'Total cost',
            value: _formatCents(totalCents),
            isTotal: true,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          _CostRow(
            label: 'Equal share per person',
            value: _formatCents(equalShareCents),
            isTotal: false,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          _CostRow(
            label: 'Items with prices',
            value: '$itemCount',
            isTotal: false,
          ),
          const SizedBox(height: MitlistSpacing.md),
          if (onGenerateExpense != null)
            SizedBox(
              width: double.infinity,
              child: AppButton(
                variant: AppButtonVariant.solid,
                color: AppButtonColor.primary,
                text: 'Generate expense',
                onPressed: onGenerateExpense,
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
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.iconName, required this.message});

  final String iconName;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(name: iconName, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: MitlistSpacing.sm),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
