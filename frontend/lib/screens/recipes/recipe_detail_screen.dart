import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/recipe_models.dart';
import '../../providers/recipe_provider.dart';
import '../../sheets/recipe_add_to_list_sheet.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/haptics.dart';
import '../../utils/safe_launch.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_divider.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  ConsumerState<RecipeDetailScreen> createState() =>
      _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  Recipe? _recipe;
  List<RecipeIngredient> _ingredients = const [];
  List<RecipeStep> _steps = const [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final service = await ref.read(recipeServiceProviderAsync.future);
      final recipe = await service.getRecipe(widget.recipeId);
      List<RecipeIngredient> ingredients = const [];
      List<RecipeStep> steps = const [];
      try {
        ingredients = await service.getRecipeIngredients(widget.recipeId);
      } catch (_) {}
      try {
        steps = await service.getRecipeSteps(widget.recipeId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _recipe = recipe;
        _ingredients = ingredients;
        _steps = steps;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _confirmDelete() async {
    if (_isDeleting) return;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: 'Delete recipe',
      body: const Text(
          'This will permanently delete this recipe. This cannot be undone.'),
      actions: [
        AppButton(
          text: 'Cancel',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: 'Delete',
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isDeleting = true);
    try {
      final service = await ref.read(recipeServiceProviderAsync.future);
      await service.deleteRecipe(widget.recipeId);
      if (!mounted) return;
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete recipe')),
      );
    }
  }

  void _startCook() {
    final recipe = _recipe;
    if (recipe == null) return;
    context.pushNamed(
      'recipeCook',
      pathParameters: {'recipeId': widget.recipeId},
      extra: <String, Object?>{
        'recipe': recipe,
        'ingredients': _ingredients,
        'steps': _steps,
      },
    );
  }

  Future<void> _addToList() async {
    final recipe = _recipe;
    if (recipe == null) return;
    unawaited(Haptics.light());
    await RecipeAddToListSheet.show(
      context,
      recipeId: recipe.id,
      recipeTitle: recipe.title,
      defaultServings: recipe.servings,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MitlistAppBar(
        title: const Text(
          'Recipe',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        showStandardActions: false,
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_recipe != null)
            IconButton(
              icon: const AppIcon(name: 'trash'),
              tooltip: 'Delete recipe',
              onPressed: _isDeleting ? null : _confirmDelete,
            ),
        ],
      ),
      body: _buildBody(context),
      bottomNavigationBar: _recipe == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  MitlistSpacing.md,
                  MitlistSpacing.sm,
                  MitlistSpacing.md,
                  MitlistSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'Add to list',
                        size: AppButtonSize.lg,
                        variant: AppButtonVariant.outline,
                        onPressed: _addToList,
                      ),
                    ),
                    if (_steps.isNotEmpty) ...[
                      const SizedBox(width: MitlistSpacing.sm),
                      Expanded(
                        child: AppButton(
                          text: 'Cook',
                          size: AppButtonSize.lg,
                          onPressed: _startCook,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return _buildLoading();
    }
    if (_hasError || _recipe == null) {
      return Center(
        child: AppEmptyState(
          icon: const AppIcon(name: 'restaurant', size: 48),
          title: 'Could not load recipe',
          description: 'Check your connection and try again.',
          isError: true,
          actions: [
            AppButton(
              text: 'Retry',
              variant: AppButtonVariant.outline,
              onPressed: _load,
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: _buildContent(context, _recipe!),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      children: const [
        AppSkeleton(width: 80, height: 28),
        SizedBox(height: MitlistSpacing.md),
        AppSkeleton(width: double.infinity, height: 32),
        SizedBox(height: MitlistSpacing.md),
        AppSkeleton(width: double.infinity, height: 200),
        SizedBox(height: MitlistSpacing.md),
        AppSkeleton(width: double.infinity, height: 160),
        SizedBox(height: MitlistSpacing.md),
        AppSkeleton(width: double.infinity, height: 240),
      ],
    );
  }

  Widget _buildContent(BuildContext context, Recipe recipe) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nutritionMap = _parseNutrition(recipe.nutritionJson);
    final equipmentList = _parseEquipment(recipe.equipmentJson);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppChip(
          label: recipe.isPublic ? 'Shared' : 'Private',
          selected: true,
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          recipe.title,
          style: theme.textTheme.headlineSmall,
        ),
        if (recipe.author.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.xs),
          Text(
            'By ${recipe.author}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (recipe.ratingValue > 0) ...[
          const SizedBox(height: MitlistSpacing.xs),
          Row(
            children: [
              AppIcon(name: 'star', size: 16, color: colorScheme.primary),
              const SizedBox(width: MitlistSpacing.xs),
              Text(
                '${recipe.ratingValue.toStringAsFixed(1)}'
                '${recipe.ratingCount > 0 ? ' (${recipe.ratingCount})' : ''}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
        if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.zero,
            child: Image.network(
              recipe.imageUrl!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              cacheWidth: (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context) *
                      1.5)
                  .round(),
              errorBuilder: (_, __, ___) => Container(
                color: colorScheme.surfaceContainerLow,
                height: 220,
                child: const Center(child: AppIcon(name: 'restaurant', size: 48)),
              ),
            ),
          ),
        ],
        if (recipe.tags.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          Wrap(
            spacing: MitlistSpacing.sm,
            runSpacing: MitlistSpacing.sm,
            children: recipe.tags
                .map((tag) => AppChip(label: tag, selected: false))
                .toList(),
          ),
        ],
        if (recipe.description.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          Text(
            recipe.description,
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: MitlistSpacing.md),
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppCardPadding.md,
          child: Column(
            children: [
              _DetailRow(label: 'Prep', value: _formatMinutes(recipe.prepTime)),
              const AppDivider(),
              _DetailRow(label: 'Cook', value: _formatMinutes(recipe.cookTime)),
              const AppDivider(),
              _DetailRow(label: 'Servings', value: recipe.servings.toString()),
              const AppDivider(),
              _DetailRow(
                label: 'Updated',
                value: DateFormat.yMMMd().format(recipe.updatedAt),
              ),
            ],
          ),
        ),
        if (nutritionMap.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          Text('Nutrition', style: theme.textTheme.titleSmall),
          const SizedBox(height: MitlistSpacing.xs),
          Wrap(
            spacing: MitlistSpacing.sm,
            runSpacing: MitlistSpacing.sm,
            children: nutritionMap.entries
                .map((e) => AppChip(label: '${e.key}: ${e.value}', selected: false))
                .toList(),
          ),
        ],
        if (equipmentList.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          Text('Equipment', style: theme.textTheme.titleSmall),
          const SizedBox(height: MitlistSpacing.xs),
          Wrap(
            spacing: MitlistSpacing.sm,
            runSpacing: MitlistSpacing.sm,
            children: equipmentList
                .map((e) => AppChip(label: e, selected: false))
                .toList(),
          ),
        ],
        if (_ingredients.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          Text('Ingredients', style: theme.textTheme.titleSmall),
          const SizedBox(height: MitlistSpacing.xs),
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.md,
            child: Semantics(
              label:
                  '${_ingredients.length} ingredient${_ingredients.length == 1 ? '' : 's'}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _ingredients.map((ing) {
                  final label =
                      ing.rawText.isNotEmpty ? ing.rawText : ing.name;
                  final qty =
                      ing.quantity > 0 ? _formatQuantity(ing.quantity) : '';
                  final unit = ing.unit.isNotEmpty ? ing.unit : '';
                  final detail =
                      [qty, unit].where((s) => s.isNotEmpty).join(' ');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: MitlistSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: theme.textTheme.bodyMedium),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: theme.textTheme.bodyMedium),
                              if (detail.isNotEmpty)
                                Text(
                                  detail,
                                  style: MitlistTypography.monoBody(
                                    color: colorScheme.onSurfaceVariant,
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
        if (_steps.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          Text('Steps', style: theme.textTheme.titleSmall),
          const SizedBox(height: MitlistSpacing.xs),
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.md,
            child: Semantics(
              label: '${_steps.length} step${_steps.length == 1 ? '' : 's'}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _steps.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final step = entry.value;
                  final desc = step.description.isNotEmpty
                      ? step.description
                      : step.name;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom:
                          idx < _steps.length - 1 ? MitlistSpacing.sm : 0,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${idx + 1}.',
                            style: MitlistTypography.monoBody(
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(desc,
                              style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
        if (recipe.videoUrl.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          _LinkRow(
            icon: 'playCircleOutline',
            label: 'Watch video',
            semanticLabel: 'Watch recipe video',
            onTap: () => safeLaunchUrl(recipe.videoUrl),
          ),
        ],
        if (recipe.sourceUrl.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          _LinkRow(
            icon: 'openInNew',
            label: 'View original recipe',
            semanticLabel: 'View original recipe in browser',
            onTap: () => safeLaunchUrl(recipe.sourceUrl),
          ),
        ],
        const SizedBox(height: MitlistSpacing.lg),
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
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: MitlistTypography.monoBody(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.xs),
          child: Row(
            children: [
              AppIcon(name: icon, size: 16, color: colorScheme.primary),
              const SizedBox(width: MitlistSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
