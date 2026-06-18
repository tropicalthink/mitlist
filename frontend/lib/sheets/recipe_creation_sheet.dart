import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recipe_models.dart';
import '../l10n/app_localizations.dart';
import '../providers/recipe_provider.dart';
import '../theme/spacing.dart';
import '../utils/haptics.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../utils/friendly_error.dart';
import '../widgets/app_input.dart';

class RecipeCreationSheet extends ConsumerStatefulWidget {
  final String? initialTitle;
  final String? initialIngredients;
  final String? initialSteps;

  const RecipeCreationSheet({
    super.key,
    this.initialTitle,
    this.initialIngredients,
    this.initialSteps,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? initialTitle,
    String? initialIngredients,
    String? initialSteps,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    return showAppBottomSheet<bool>(
      context: context,
      title: l10n.recipeCreationTitle,
      body: RecipeCreationSheet(
        initialTitle: initialTitle,
        initialIngredients: initialIngredients,
        initialSteps: initialSteps,
      ),
    );
  }

  @override
  ConsumerState<RecipeCreationSheet> createState() =>
      _RecipeCreationSheetState();
}

class _RecipeCreationSheetState extends ConsumerState<RecipeCreationSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _stepsController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialIngredients != null) {
      _ingredientsController.text = widget.initialIngredients!;
    }
    if (widget.initialSteps != null) {
      _stepsController.text = widget.initialSteps!;
    }
  }

  bool get _hasTitle => _titleController.text.trim().isNotEmpty;
  bool get _canCreate => !_isSaving && _hasTitle;

  Future<void> _onCreate() async {
    final l10n = AppLocalizations.of(context)!;
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
        SnackBar(content: Text(l10n.recipeCreationCreated)),
      );
      unawaited(Haptics.success());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
      );
    }
  }

  String _buildDescription() {
    const maxTotalLen = 8000;
    final parts = <String>[];
    if (_ingredientsController.text.trim().isNotEmpty) {
      parts
          .add('Ingredients:\n${_normalizeLines(_ingredientsController.text)}');
    }
    if (_stepsController.text.trim().isNotEmpty) {
      parts.add('Steps:\n${_normalizeLines(_stepsController.text)}');
    }
    final joined = parts.join('\n\n');
    if (joined.length <= maxTotalLen) return joined;
    return '${joined.substring(0, maxTotalLen)}\u2026';
  }

  String _normalizeLines(String value) {
    return value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.startsWith('-') ? line : '- $line')
        .join('\n');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ingredientsController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppInput(
            label: l10n.recipeCreationTitleInput,
            hint: l10n.recipeCreationTitleHint,
            controller: _titleController,
            textInputAction: TextInputAction.next,
            maxLength: 150,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: MitlistSpacing.md),
          AppInput(
            label: l10n.recipeCreationIngredients,
            hint: l10n.recipeCreationIngredientHint,
            controller: _ingredientsController,
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: MitlistSpacing.md),
          AppInput(
            label: l10n.recipeCreationSteps,
            hint: l10n.recipeCreationStepHint,
            controller: _stepsController,
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: MitlistSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              variant: AppButtonVariant.solid,
              color: AppButtonColor.primary,
              size: AppButtonSize.lg,
              text: _isSaving ? l10n.recipeCreationCreating : l10n.recipeCreationCreateRecipe,
              isLoading: _isSaving,
              onPressed: _canCreate ? _onCreate : null,
            ),
          ),
        ],
      ),
    );
  }
}
