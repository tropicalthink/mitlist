import 'dart:async';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/recipe_models.dart';
import '../providers/recipe_provider.dart';
import '../providers/scan_provider.dart';
import '../theme/spacing.dart';
import '../utils/haptics.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon.dart';
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
    return showAppBottomSheet<bool>(
      context: context,
      title: 'New recipe',
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
  bool _isScanning = false;

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

  Future<void> _onScan() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null || !mounted) return;

    setState(() => _isScanning = true);

    try {
      final service = await ref.read(scanServiceProviderAsync.future);
      final bytes = await File(picked.path).readAsBytes();
      final result = await service.scanImage(bytes, 'image/jpeg');

      if (!mounted) return;

      if (result.title != null && result.title!.isNotEmpty) {
        _titleController.text = result.title!;
      }
      if (result.items.isNotEmpty) {
        _ingredientsController.text =
            result.items.map((i) => i.name).join('\n');
      }
      if (result.steps.isNotEmpty) {
        _stepsController.text = result.steps.join('\n');
      }

      setState(() => _isScanning = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
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
      unawaited(Haptics.success());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
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
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppButton(
            text: _isScanning ? 'Scanning...' : 'Scan recipe',
            icon: AppIcon(
              name: _isScanning ? 'hourglassEmpty' : 'documentScanner',
              size: 20,
            ),
            variant: AppButtonVariant.outline,
            color: AppButtonColor.neutral,
            onPressed: _isScanning ? null : _onScan,
            semanticLabel: 'Scan recipe via camera',
          ),
          const SizedBox(height: MitlistSpacing.md),
          AppInput(
            label: 'Recipe title',
            hint: 'Sunday pancakes',
            controller: _titleController,
            textInputAction: TextInputAction.next,
            maxLength: 150,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: MitlistSpacing.md),
          AppInput(
            label: 'Ingredients',
            hint: '2 cups flour\n1 cup milk\n3 eggs',
            controller: _ingredientsController,
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: MitlistSpacing.md),
          AppInput(
            label: 'Steps',
            hint: 'Mix batter\nCook until golden',
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
              text: _isSaving ? 'Creating...' : 'Create recipe',
              isLoading: _isSaving,
              onPressed: _canCreate ? _onCreate : null,
            ),
          ),
        ],
      ),
    );
  }
}
