import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_card.dart';
import '../widgets/chip.dart';

class LivingThingDetailSheet extends StatelessWidget {
  const LivingThingDetailSheet({
    super.key,
    required this.name,
    required this.typeLabel,
    required this.location,
    required this.createdAt,
  });

  final String name;
  final String typeLabel;
  final String? location;
  final DateTime createdAt;

  static Future<void> show(
    BuildContext context, {
    required String name,
    required String typeLabel,
    required String? location,
    required DateTime createdAt,
  }) async {
    return showAppBottomSheet(
      context: context,
      title: 'Pet or Plant',
      body: LivingThingDetailSheet(
        name: name,
        typeLabel: typeLabel,
        location: location,
        createdAt: createdAt,
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
          label: typeLabel,
          selected: true,
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppCardPadding.md,
          child: Column(
            children: [
              _LivingThingDetailRow(
                label: 'Location',
                value: location ?? 'Not set',
              ),
              const Divider(),
              _LivingThingDetailRow(
                label: 'Added',
                value: DateFormat.yMMMd().format(createdAt),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LivingThingDetailRow extends StatelessWidget {
  const _LivingThingDetailRow({required this.label, required this.value});

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
