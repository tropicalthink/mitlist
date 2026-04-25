import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_card.dart';
import '../widgets/chip.dart';

class VaultItemDetailSheet extends StatelessWidget {
  const VaultItemDetailSheet({
    super.key,
    required this.title,
    required this.category,
    required this.content,
    required this.expiryDate,
    required this.updatedAt,
  });

  final String title;
  final String category;
  final String content;
  final DateTime? expiryDate;
  final DateTime updatedAt;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String category,
    required String content,
    required DateTime? expiryDate,
    required DateTime updatedAt,
  }) async {
    return showAppBottomSheet(
      context: context,
      title: 'Vault Item',
      body: VaultItemDetailSheet(
        title: title,
        category: category,
        content: content,
        expiryDate: expiryDate,
        updatedAt: updatedAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppChip(
          label: category,
          selected: true,
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (content.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.md,
            child: SelectableText(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
        const SizedBox(height: MitlistSpacing.md),
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppCardPadding.md,
          child: Column(
            children: [
              _VaultDetailRow(
                label: 'Reminder',
                value: expiryDate == null
                    ? 'Not set'
                    : DateFormat.yMMMd().format(expiryDate!),
              ),
              const Divider(),
              _VaultDetailRow(
                label: 'Updated',
                value: DateFormat.yMMMd().format(updatedAt),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VaultDetailRow extends StatelessWidget {
  const _VaultDetailRow({required this.label, required this.value});

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
