import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/recipe_models.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';
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
    this.author = '',
    this.ratingValue = 0,
    this.ratingCount = 0,
    this.sourceUrl = '',
    this.videoUrl = '',
    this.nutritionJson = '',
    this.equipmentJson = '',
    this.imageUrl,
    this.tags = const [],
    this.ingredients = const [],
    this.steps = const [],
    this.onDelete,
  });

  final String title;
  final String description;
  final String visibilityLabel;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final DateTime updatedAt;
  final String author;
  final double ratingValue;
  final int ratingCount;
  final String sourceUrl;
  final String videoUrl;
  final String nutritionJson;
  final String equipmentJson;
  final String? imageUrl;
  final List<String> tags;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final VoidCallback? onDelete;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String description,
    required String visibilityLabel,
    required int prepTimeMinutes,
    required int cookTimeMinutes,
    required int servings,
    required DateTime updatedAt,
    String author = '',
    double ratingValue = 0,
    int ratingCount = 0,
    String sourceUrl = '',
    String videoUrl = '',
    String nutritionJson = '',
    String equipmentJson = '',
    String? imageUrl,
    List<String> tags = const [],
    List<RecipeIngredient> ingredients = const [],
    List<RecipeStep> steps = const [],
    VoidCallback? onDelete,
  }) async {
    return showAppBottomSheet(
      context: context,
      title: 'Recipe details',
      body: RecipeDetailSheet(
        title: title,
        description: description,
        visibilityLabel: visibilityLabel,
        prepTimeMinutes: prepTimeMinutes,
        cookTimeMinutes: cookTimeMinutes,
        servings: servings,
        updatedAt: updatedAt,
        author: author,
        ratingValue: ratingValue,
        ratingCount: ratingCount,
        sourceUrl: sourceUrl,
        videoUrl: videoUrl,
        nutritionJson: nutritionJson,
        equipmentJson: equipmentJson,
        imageUrl: imageUrl,
        tags: tags,
        ingredients: ingredients,
        steps: steps,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nutritionMap = _parseNutrition(nutritionJson);
    final equipmentList = _parseEquipment(equipmentJson);

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
        if (author.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.xs),
          Text(
            'By $author',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
        if (ratingValue > 0) ...[
          const SizedBox(height: MitlistSpacing.xs),
          Row(
            children: [
              AppIcon(name: 'star', size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: MitlistSpacing.xs),
              Text(
                '${ratingValue.toStringAsFixed(1)}${ratingCount > 0 ? ' ($ratingCount)' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
        if (imageUrl != null && imageUrl!.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Image.network(
              imageUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                height: 160,
                child: const Center(child: AppIcon(name: 'restaurant', size: 48)),
              ),
            ),
          ),
        ],
        if (tags.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          Wrap(
            spacing: MitlistSpacing.sm,
            runSpacing: MitlistSpacing.sm,
            children: tags
                .map((tag) => AppChip(
                      label: tag,
                      selected: false,
                    ))
                .toList(),
          ),
        ],
        if (description.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          Text(
            description,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
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
              Divider(color: Theme.of(context).colorScheme.outlineVariant),
              _RecipeDetailRow(
                label: 'Cook',
                value: _formatMinutes(cookTimeMinutes),
              ),
              Divider(color: Theme.of(context).colorScheme.outlineVariant),
              _RecipeDetailRow(
                label: 'Servings',
                value: servings.toString(),
              ),
              Divider(color: Theme.of(context).colorScheme.outlineVariant),
              _RecipeDetailRow(
                label: 'Updated',
                value: DateFormat.yMMMd().format(updatedAt),
              ),
            ],
          ),
        ),
        if (nutritionMap.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          Text(
            'Nutrition',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: MitlistSpacing.xs),
          Wrap(
            spacing: MitlistSpacing.sm,
            runSpacing: MitlistSpacing.sm,
            children: nutritionMap.entries.map((e) {
              return AppChip(label: '${e.key}: ${e.value}', selected: false);
            }).toList(),
          ),
        ],
        if (equipmentList.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          Text(
            'Equipment',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: MitlistSpacing.xs),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: equipmentList
                .map((e) => AppChip(label: e, selected: false))
                .toList(),
          ),
        ],
        if (ingredients.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          Text(
            'Ingredients',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: MitlistSpacing.xs),
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.md,
            child: Semantics(
              label: '${ingredients.length} ingredient${ingredients.length == 1 ? '' : 's'}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: ingredients.map((ing) {
                  final label = ing.rawText.isNotEmpty
                      ? ing.rawText
                      : ing.name.isNotEmpty
                          ? ing.name
                          : ing.rawText;
                  final qty = ing.quantity > 0
                      ? _formatQuantity(ing.quantity)
                      : '';
                  final unit = ing.unit.isNotEmpty ? ing.unit : '';
                  final detail = [qty, unit].where((s) => s.isNotEmpty).join(' ');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: MitlistSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\u2022 ',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (detail.isNotEmpty)
                                Text(
                                  detail,
                                  style: MitlistTypography.monoBody(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
        if (steps.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          Text(
            'Steps',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: MitlistSpacing.xs),
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.md,
            child: Semantics(
              label: '${steps.length} step${steps.length == 1 ? '' : 's'}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: steps.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final step = entry.value;
                  final desc = step.description.isNotEmpty
                      ? step.description
                      : (step.name.isNotEmpty ? step.name : '');
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: idx < steps.length - 1 ? MitlistSpacing.sm : 0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${idx + 1}.',
                            style: MitlistTypography.monoBody(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            desc,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
        if (videoUrl.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          Semantics(
            label: 'Watch recipe video',
            button: true,
            child: InkWell(
            onTap: () => _launchUrl(videoUrl),
            child: Row(
              children: [
                AppIcon(name: 'playCircleOutline', size: 16, color: Theme.of(context).colorScheme.primary),
                SizedBox(width: MitlistSpacing.xs),
                Expanded(
                  child: Text(
                    'Watch video',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ),
        ],
        if (sourceUrl.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          Semantics(
            label: 'View original recipe in browser',
            button: true,
            child: InkWell(
            onTap: () => _launchUrl(sourceUrl),
            child: Row(
              children: [
                AppIcon(name: 'openInNew', size: 16, color: Theme.of(context).colorScheme.primary),
                SizedBox(width: MitlistSpacing.xs),
                Expanded(
                  child: Text(
                    'View original recipe',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          ),
        ],
        if (onDelete != null) ...[
          const SizedBox(height: MitlistSpacing.lg),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: MitlistSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              variant: AppButtonVariant.ghost,
              color: AppButtonColor.error,
              size: AppButtonSize.lg,
              text: 'Delete recipe',
              onPressed: onDelete,
            ),
          ),
        ],
      ],
    );
  }

  static String _formatQuantity(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    final s = qty.toStringAsFixed(2);
    if (s.endsWith('0')) return s.substring(0, s.length - 1);
    return s;
  }

  static String _formatMinutes(int minutes) {
    if (minutes <= 0) {
      return 'Not set';
    }
    return '$minutes min';
  }

  static Map<String, String> _parseNutrition(String jsonStr) {
    if (jsonStr.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {
      // Failed to parse nutrition JSON; return empty map.
    }
    return {};
  }

  static List<String> _parseEquipment(String jsonStr) {
    if (jsonStr.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {
      // Failed to parse equipment JSON; return empty list.
    }
    return [];
  }
}

Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
            style: MitlistTypography.monoBody(color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
