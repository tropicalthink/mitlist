import 'package:flutter/material.dart';
import '../theme/spacing.dart';
import '../l10n/app_localizations.dart';
import '../utils/format_currency.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon.dart';

class CostSummarySheet extends StatelessWidget {
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
    final l10n = AppLocalizations.of(context)!;
    return showAppBottomSheet(
      context: context,
      title: l10n.sheetCostSummaryTitle,
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
    return formatCurrency(cents.clamp(0, 999999999), currencyCode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            message: l10n.costSummaryNoPrices,
          ),
        ] else ...[
          _CostRow(
            label: l10n.sheetCostSummaryTotal,
            value: _formatCents(totalCents),
            isTotal: true,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          _CostRow(
            label: l10n.costSummaryEqualShare,
            value: equalShareCents > 0
                ? _formatCents(equalShareCents)
                : l10n.costSummaryNotAvailable,
            isTotal: false,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          _CostRow(
            label: l10n.costSummaryItemsWithPrices,
            value: itemCount > 0 ? '$itemCount' : l10n.costSummaryNone,
            isTotal: false,
          ),
          const SizedBox(height: MitlistSpacing.md),
          if (onGenerateExpense != null)
            SizedBox(
              width: double.infinity,
              child: AppButton(
                variant: AppButtonVariant.solid,
                color: AppButtonColor.primary,
                text: l10n.costSummaryGenerateExpense,
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
        AppIcon(
            name: iconName,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
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
