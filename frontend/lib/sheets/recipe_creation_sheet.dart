import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe_models.dart';
import '../providers/recipe_provider.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

class RecipeCreationSheet extends ConsumerStatefulWidget {
  const RecipeCreationSheet({super.key});

  static Future<bool?> show(BuildContext context) async {
    return showAppBottomSheet<bool>(
      context: context,
      title: 'New Recipe',
      body: const RecipeCreationSheet(),
    );
  }

  @override
  ConsumerState<RecipeCreationSheet> createState() => _RecipeCreationSheetState();
}

class _RecipeCreationSheetState extends ConsumerState<RecipeCreationSheet> {
  final TextEditingController _titleController = TextEditingController();
  final List<TextEditingController> _ingredientControllers = [
    TextEditingController(),
  ];
  final List<TextEditingController> _stepControllers = [
    TextEditingController(),
  ];
  bool _isSaving = false;

  bool get _canCreate => _titleController.text.trim().isNotEmpty && !_isSaving;

  void _addIngredient() {
    setState(() => _ingredientControllers.add(TextEditingController()));
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredientControllers[index].dispose();
      _ingredientControllers.removeAt(index);
    });
  }

  void _addStep() {
    setState(() => _stepControllers.add(TextEditingController()));
  }

  void _removeStep(int index) {
    setState(() {
      _stepControllers[index].dispose();
      _stepControllers.removeAt(index);
    });
  }

  Future<void> _onCreate() async {
    if (!_canCreate) return;

    setState(() => _isSaving = true);

    try {
      final recipeService = await ref.read(recipeServiceProviderAsync.future);
      await recipeService.createRecipe(
        CreateRecipeRequest(
          title: _titleController.text.trim(),
          description: _buildDescription(),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe created')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create recipe: $e')),
      );
    }
  }

  String _buildDescription() {
    final ingredients = _ingredientControllers
        .map((c) => c.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final steps = _stepControllers
        .map((c) => c.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final sections = <String>[];
    if (ingredients.isNotEmpty) {
      sections.add(
        'Ingredients:\n${ingredients.map((item) => '- $item').join('\n')}',
      );
    }
    if (steps.isNotEmpty) {
      sections.add(
        'Steps:\n${steps.asMap().entries.map((entry) => '${entry.key + 1}. ${entry.value}').join('\n')}',
      );
    }
    return sections.join('\n\n');
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _ingredientControllers) {
      c.dispose();
    }
    for (final c in _stepControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput(
          label: 'Recipe Title',
          hint: 'e.g. Sunday Pancakes',
          controller: _titleController,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Ingredients'.toUpperCase(),
          style: MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        ..._ingredientControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: AppInput(
                    hint: 'Ingredient ${index + 1}',
                    controller: controller,
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: MitlistSpacing.sm),
                AppButton(
                  variant: AppButtonVariant.ghost,
                  color: AppButtonColor.error,
                  size: AppButtonSize.sm,
                  icon: const Icon(Icons.close),
                  onPressed: _ingredientControllers.length > 1
                      ? () => _removeIngredient(index)
                      : null,
                ),
              ],
            ),
          );
        }),
        AppButton(
          variant: AppButtonVariant.outline,
          color: AppButtonColor.primary,
          size: AppButtonSize.md,
          text: 'Add Ingredient',
          onPressed: _addIngredient,
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          'Steps'.toUpperCase(),
          style: MitlistTypography.labelXSmall(color: MitlistColors.textSecondary),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        ..._stepControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: MitlistSpacing.space8,
                  height: MitlistSpacing.space8,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: MitlistColors.neutral950,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: MitlistColors.surfacePrimary,
                        ),
                  ),
                ),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: AppInput(
                    hint: 'Step ${index + 1}',
                    controller: controller,
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: MitlistSpacing.sm),
                AppButton(
                  variant: AppButtonVariant.ghost,
                  color: AppButtonColor.error,
                  size: AppButtonSize.sm,
                  icon: const Icon(Icons.close),
                  onPressed: _stepControllers.length > 1
                      ? () => _removeStep(index)
                      : null,
                ),
              ],
            ),
          );
        }),
        AppButton(
          variant: AppButtonVariant.outline,
          color: AppButtonColor.primary,
          size: AppButtonSize.md,
          text: 'Add Step',
          onPressed: _addStep,
        ),
        const SizedBox(height: MitlistSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            text: _isSaving ? 'Creating...' : 'Create Recipe',
            isLoading: _isSaving,
            onPressed: _canCreate ? _onCreate : null,
          ),
        ),
      ],
    );
  }
}
