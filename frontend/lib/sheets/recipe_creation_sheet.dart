import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

class RecipeCreationSheet extends StatefulWidget {
  const RecipeCreationSheet({super.key});

  static Future<void> show(BuildContext context) async {
    return showAppBottomSheet(
      context: context,
      title: 'New Recipe',
      body: const RecipeCreationSheet(),
    );
  }

  @override
  State<RecipeCreationSheet> createState() => _RecipeCreationSheetState();
}

class _RecipeCreationSheetState extends State<RecipeCreationSheet> {
  final TextEditingController _titleController = TextEditingController();
  final List<TextEditingController> _ingredientControllers = [
    TextEditingController(),
  ];
  final List<TextEditingController> _stepControllers = [
    TextEditingController(),
  ];

  bool get _canCreate => _titleController.text.trim().isNotEmpty;

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

  void _onCreate() {
    if (!_canCreate) return;
    Navigator.of(context).pop();
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
            text: 'Create Recipe',
            onPressed: _canCreate ? _onCreate : null,
          ),
        ),
      ],
    );
  }
}
