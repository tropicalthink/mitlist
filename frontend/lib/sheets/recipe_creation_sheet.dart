import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe_models.dart';
import '../providers/recipe_provider.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
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
  ConsumerState<RecipeCreationSheet> createState() =>
      _RecipeCreationSheetState();
}

class _RecipeCreationSheetState extends ConsumerState<RecipeCreationSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _prepTimeController = TextEditingController();
  final TextEditingController _cookTimeController = TextEditingController();
  final TextEditingController _servingsController =
      TextEditingController(text: '1');
  bool _isPublic = false;
  bool _isSaving = false;

  bool get _canCreate => _titleController.text.trim().isNotEmpty && !_isSaving;

  Future<void> _onCreate() async {
    if (!_canCreate) return;

    setState(() => _isSaving = true);

    try {
      final recipeService = await ref.read(recipeServiceProviderAsync.future);
      await recipeService.createRecipe(
        CreateRecipeRequest(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          prepTime: _parsePositiveInt(_prepTimeController.text) ?? 0,
          cookTime: _parsePositiveInt(_cookTimeController.text) ?? 0,
          servings: _parsePositiveInt(_servingsController.text) ?? 1,
          isPublic: _isPublic,
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

  int? _parsePositiveInt(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
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
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        TextField(
          controller: _descriptionController,
          minLines: 4,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'Recipe notes, ingredients, or steps',
          ),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppInput(
                label: 'Prep Time',
                hint: '0',
                controller: _prepTimeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: MitlistSpacing.md),
            Expanded(
              child: AppInput(
                label: 'Cook Time',
                hint: '0',
                controller: _cookTimeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: 'Servings',
          hint: '1',
          controller: _servingsController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: MitlistSpacing.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Make recipe public'),
          value: _isPublic,
          onChanged:
              _isSaving ? null : (value) => setState(() => _isPublic = value),
          activeColor: MitlistColors.primary500,
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
