import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_card.dart';
import '../widgets/chip.dart';

class RecipeDetailSheet extends StatelessWidget {
  const RecipeDetailSheet({
    super.key,
    required this.title,
    required this.description,
    required this.visibilityLabel,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.servings,
    required this.updatedAt,
  });

  final String title;
  final String description;
  final String visibilityLabel;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final DateTime updatedAt;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String description,
    required String visibilityLabel,
    required int prepTimeMinutes,
    required int cookTimeMinutes,
    required int servings,
    required DateTime updatedAt,
  }) async {
    return showAppBottomSheet(
      context: context,
      title: 'Recipe Details',
      body: RecipeDetailSheet(
        title: title,
        description: description,
        visibilityLabel: visibilityLabel,
        prepTimeMinutes: prepTimeMinutes,
        cookTimeMinutes: cookTimeMinutes,
        servings: servings,
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
          label: visibilityLabel,
          selected: true,
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: MitlistSpacing.md),
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppCardPadding.md,
          child: Column(
            children: [
              _RecipeDetailRow(
                label: 'Prep',
                value: _formatMinutes(prepTimeMinutes),
              ),
              const Divider(),
              _RecipeDetailRow(
                label: 'Cook',
                value: _formatMinutes(cookTimeMinutes),
              ),
              const Divider(),
              _RecipeDetailRow(
                label: 'Servings',
                value: servings.toString(),
              ),
              const Divider(),
              _RecipeDetailRow(
                label: 'Updated',
                value: DateFormat.yMMMd().format(updatedAt),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatMinutes(int minutes) {
    if (minutes <= 0) {
      return 'Not set';
    }
    return '$minutes min';
  }
}

class _RecipeDetailRow extends StatelessWidget {
  const _RecipeDetailRow({required this.label, required this.value});

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
