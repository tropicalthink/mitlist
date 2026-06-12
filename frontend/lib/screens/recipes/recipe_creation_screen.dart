import 'dart:async';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/recipe_models.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/scan_provider.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/mitlist_app_bar.dart';

class RecipeCreationScreen extends ConsumerStatefulWidget {
  final String? initialTitle;
  final String? initialIngredients;
  final String? initialSteps;

  const RecipeCreationScreen({
    super.key,
    this.initialTitle,
    this.initialIngredients,
    this.initialSteps,
  });

  @override
  ConsumerState<RecipeCreationScreen> createState() =>
      _RecipeCreationScreenState();
}

enum _RecipeEntryMode { url, manual, scan }

class _RecipeCreationScreenState extends ConsumerState<RecipeCreationScreen> {
  int _currentStep = 0;

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _stepsController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _nutritionController = TextEditingController();
  final TextEditingController _prepTimeController = TextEditingController();
  final TextEditingController _cookTimeController = TextEditingController();
  final TextEditingController _servingsController =
      TextEditingController(text: '1');
  bool _isPublic = false;
  bool _isSaving = false;
  bool _isScraping = false;
  bool _isScanning = false;
  _RecipeEntryMode _mode = _RecipeEntryMode.manual;

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

  // Scraped metadata
  String _scrapedAuthor = '';
  double _scrapedRatingValue = 0;
  int _scrapedRatingCount = 0;
  String _scrapedSourceUrl = '';
  String _scrapedVideoUrl = '';
  List<String> _scrapedImageOptions = [];
  String? _selectedImageUrl;
  List<String> _scrapedEquipment = [];
  Map<String, dynamic>? _scrapedNutrition;

  bool get _isDirty {
    return _titleController.text.trim().isNotEmpty ||
        _urlController.text.trim().isNotEmpty ||
        _ingredientsController.text.trim().isNotEmpty ||
        _stepsController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _tagsController.text.trim().isNotEmpty ||
        _nutritionController.text.trim().isNotEmpty ||
        _prepTimeController.text.trim().isNotEmpty ||
        _cookTimeController.text.trim().isNotEmpty ||
        _servingsController.text.trim() != '1' ||
        _selectedImageUrl != null;
  }

  Future<bool> _onWillPop() async {
    if (!_isDirty) return true;
    final result = await showAppDialog<bool>(
      context: context,
      title: 'Discard recipe?',
      body: const Text('You have unsaved content in this recipe.'),
      actions: [
        AppButton(
          text: 'Keep editing',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: 'Discard',
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    return result == true;
  }

  Future<void> _onScan() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _isScanning = true;
      _mode = _RecipeEntryMode.manual;
    });

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
    } catch (_) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't scan recipe.")),
      );
    }
  }

  bool get _hasTitle => _titleController.text.trim().isNotEmpty;
  bool get _hasUrl => _urlController.text.trim().isNotEmpty;
  bool get _canCreate =>
      !_isSaving && (_mode == _RecipeEntryMode.url ? _hasUrl : _hasTitle);

  bool get _canScrape =>
      _mode == _RecipeEntryMode.url && _hasUrl && !_isSaving;

  bool get _canGoNext {
    if (_currentStep == 0) {
      if (_mode == _RecipeEntryMode.url) return _hasUrl;
      if (_mode == _RecipeEntryMode.scan) return true;
      return _hasTitle;
    }
    return true;
  }

  Future<void> _onScrape() async {
    if (_isScraping || _isSaving) return;
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isScraping = true);
    try {
      final recipeService = await ref.read(recipeServiceProviderAsync.future);
      final clip = await recipeService.clipRecipeFromUrl(url);

      if (!mounted) return;

      if (_titleController.text.trim().isEmpty &&
          clip.title.trim().isNotEmpty) {
        _titleController.text = clip.title.trim();
      }

      if (clip.description.trim().isNotEmpty &&
          _descriptionController.text.trim().isEmpty) {
        _descriptionController.text = clip.description.trim();
      }

      if (clip.prepTimeMinutes != null && clip.prepTimeMinutes! > 0 &&
          _prepTimeController.text.trim().isEmpty) {
        _prepTimeController.text = clip.prepTimeMinutes.toString();
      }
      if (clip.cookTimeMinutes != null && clip.cookTimeMinutes! > 0 &&
          _cookTimeController.text.trim().isEmpty) {
        _cookTimeController.text = clip.cookTimeMinutes.toString();
      }
      final servings = (clip.servings ?? '').trim();
      if (servings.isNotEmpty) {
        final parsed = int.tryParse(servings);
        if (parsed != null &&
            parsed > 0 &&
            _servingsController.text.trim() == '1') {
          _servingsController.text = parsed.toString();
        }
      }

      if (_ingredientsController.text.trim().isEmpty &&
          clip.ingredients.isNotEmpty) {
        _ingredientsController.text =
            clip.ingredients.map((i) => i.rawText).join('\n');
      }

      if (_stepsController.text.trim().isEmpty &&
          clip.instructionsMd.trim().isNotEmpty) {
        _stepsController.text = clip.instructionsMd
            .split('\n\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .join('\n');
      }

      if (_tagsController.text.trim().isEmpty && clip.tags.isNotEmpty) {
        _tagsController.text = clip.tags.join(', ');
      }

      _scrapedAuthor = clip.author;
      _scrapedRatingValue = clip.ratingValue;
      _scrapedRatingCount = clip.ratingCount;
      _scrapedSourceUrl = clip.sourceUrl;
      _scrapedVideoUrl = clip.videoUrl;
      _scrapedImageOptions = clip.imageOptions;
      _selectedImageUrl = clip.imageUrl;
      _scrapedEquipment = clip.equipment;
      _scrapedNutrition = clip.nutrition;

      setState(() => _isScraping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Details fetched')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScraping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Couldn't fetch details from that link.")),
      );
    }
  }

  Future<void> _onCreate() async {
    if (!_canCreate) return;

    setState(() => _isSaving = true);

    try {
      final recipeService = await ref.read(recipeServiceProviderAsync.future);
      final url = _urlController.text.trim();
      final title = _titleController.text.trim().isEmpty
          ? _titleFromUrl(url)
          : _titleController.text.trim();

      await recipeService.createRecipe(
        CreateRecipeRequest(
          title: title,
          description: _buildDescription(url),
          descriptionShort: _descriptionController.text.trim(),
          author: _scrapedAuthor,
          ratingValue: _scrapedRatingValue,
          ratingCount: _scrapedRatingCount,
          nutritionJson:
              _scrapedNutrition != null ? jsonEncode(_scrapedNutrition) : '',
          videoUrl: _scrapedVideoUrl,
          equipmentJson:
              _scrapedEquipment.isNotEmpty ? jsonEncode(_scrapedEquipment) : '',
          sourceUrl: url.isNotEmpty ? url : _scrapedSourceUrl,
          prepTime: _parsePositiveInt(_prepTimeController.text) ?? 0,
          cookTime: _parsePositiveInt(_cookTimeController.text) ?? 0,
          servings: _parsePositiveInt(_servingsController.text) ?? 1,
          imageUrl: _selectedImageUrl,
          imageOptions: _scrapedImageOptions,
          tags: _tagsController.text.trim().isNotEmpty
              ? _tagsController.text
                  .split(',')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toList()
              : const [],
          isPublic: _isPublic,
        ),
      );

      if (!mounted) return;
      if (context.mounted) context.pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipe created')),
      );
      unawaited(Haptics.success());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't create recipe.")),
      );
    }
  }

  String _titleFromUrl(String url) {
    final fallback = url.replaceFirst(RegExp(r'^https?://'), '');
    final host = Uri.tryParse(url)?.host;
    if (host == null || host.isEmpty) {
      return fallback.isEmpty ? 'Imported recipe' : fallback;
    }
    return 'Recipe from ${host.replaceFirst('www.', '')}';
  }

  String _buildDescription(String url) {
    final parts = <String>[];
    if (_descriptionController.text.trim().isNotEmpty) {
      parts.add(_descriptionController.text.trim());
    }
    if (url.isNotEmpty) {
      parts.add('Source: $url');
    }
    if (_ingredientsController.text.trim().isNotEmpty) {
      parts
          .add('Ingredients:\n${_normalizeLines(_ingredientsController.text)}');
    }
    if (_stepsController.text.trim().isNotEmpty) {
      parts.add('Steps:\n${_normalizeLines(_stepsController.text)}');
    }
    if (_nutritionController.text.trim().isNotEmpty) {
      parts.add('Nutrition: ${_nutritionController.text.trim()}');
    }
    if (_tagsController.text.trim().isNotEmpty) {
      parts.add('Tags: ${_tagsController.text.trim()}');
    }
    return parts.join('\n\n');
  }

  String _normalizeLines(String value) {
    return value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.startsWith('-') ? line : '- $line')
        .join('\n');
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
    _urlController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _ingredientsController.dispose();
    _stepsController.dispose();
    _tagsController.dispose();
    _nutritionController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final allowed = await _onWillPop();
        if (allowed && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: MitlistAppBar(
          title: const Text(
            'New recipe',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          showStandardActions: false,
          leading: IconButton(
            icon: const AppIcon(name: 'xMark'),
            tooltip: 'Close',
            onPressed: () async {
              final allowed = await _onWillPop();
              if (allowed && context.mounted) {
                context.pop();
              }
            },
          ),
        ),
        body: Column(
          children: [
            _buildStepIndicator(colorScheme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(MitlistSpacing.md),
                child: _buildStepContent(colorScheme),
              ),
            ),
            _buildBottomBar(colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outline, width: 2),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: MitlistSpacing.md,
        horizontal: MitlistSpacing.xxl,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0)
              Container(
                width: 32,
                height: 2,
                color: i <= _currentStep
                    ? colorScheme.primary
                    : colorScheme.surfaceContainerHighest,
                margin: const EdgeInsets.symmetric(horizontal: MitlistSpacing.sm),
              ),
            _buildDot(i, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildDot(int index, ColorScheme colorScheme) {
    final isActive = index == _currentStep;
    final isComplete = index < _currentStep;

    Color dotColor;
    if (isActive) {
      dotColor = colorScheme.primary;
    } else if (isComplete) {
      dotColor = colorScheme.primary;
    } else {
      dotColor = colorScheme.surfaceContainerHighest;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: dotColor,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: isActive || isComplete
                  ? colorScheme.primary
                  : colorScheme.outline,
              width: 2,
            ),
          ),
          child: isComplete
              ? AppIcon(
                  name: 'check',
                  size: 8,
                  color: colorScheme.onPrimary,
                )
              : null,
        ),
        const SizedBox(height: MitlistSpacing.xs),
        Text(
          ['Source', 'Details', 'Content'][index],
          style: MitlistTypography.labelXSmall(
            color: isActive
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStepContent(ColorScheme colorScheme) {
    switch (_currentStep) {
      case 0:
        return _buildStep1(colorScheme);
      case 1:
        return _buildStep2(colorScheme);
      case 2:
        return _buildStep3(colorScheme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppButton(
          text: _isScanning ? 'Scanning…' : 'Scan recipe',
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
        SegmentedButton<_RecipeEntryMode>(
          segments: const [
            ButtonSegment(
              value: _RecipeEntryMode.url,
              icon: AppIcon(name: 'link'),
              label: Text('URL'),
            ),
            ButtonSegment(
              value: _RecipeEntryMode.manual,
              icon: AppIcon(name: 'editNote'),
              label: Text('Manual'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: _isSaving
              ? null
              : (value) => setState(() {
                    if (value.first == _RecipeEntryMode.url) {
                      _mode = _RecipeEntryMode.url;
                    } else {
                      _mode = _RecipeEntryMode.manual;
                    }
                  }),
        ),
        const SizedBox(height: MitlistSpacing.md),
        if (_mode == _RecipeEntryMode.url) ...[
          AppInput(
            label: 'Recipe URL',
            hint: 'https://example.com/recipe',
            controller: _urlController,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Row(
            children: [
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.outline,
                color: AppButtonColor.neutral,
                text: _isScraping ? 'Fetching…' : 'Fetch details',
                isLoading: _isScraping,
                onPressed: _canScrape ? _onScrape : null,
              ),
            ],
          ),
          if (_scrapedImageOptions.length > 1) ...[
            const SizedBox(height: MitlistSpacing.md),
            Text('Choose an image',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: MitlistSpacing.sm),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _scrapedImageOptions.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: MitlistSpacing.sm),
                itemBuilder: (context, index) {
                  final imgUrl = _scrapedImageOptions[index];
                  final isSelected = imgUrl == _selectedImageUrl;
                  return Semantics(
                    label: 'Select image ${index + 1}',
                    button: true,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedImageUrl = imgUrl),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.surface,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.zero,
                          image: DecorationImage(
                            image: NetworkImage(imgUrl),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else if (_selectedImageUrl != null) ...[
            const SizedBox(height: MitlistSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: Image.network(
                _selectedImageUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context) * 1.5).round(),
                errorBuilder: (_, __, ___) => Container(
                  color: colorScheme.surfaceContainerLow,
                  child: const Center(
                      child: AppIcon(name: 'restaurant', size: 48)),
                ),
              ),
            ),
          ],
          const SizedBox(height: MitlistSpacing.md),
        ],
        if (_mode == _RecipeEntryMode.manual) ...[
          AppInput(
            label: 'Recipe title',
            hint: 'Sunday pancakes',
            controller: _titleController,
            textInputAction: TextInputAction.next,
            maxLength: 150,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ],
    );
  }

  Widget _buildStep2(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput(
          label: _mode == _RecipeEntryMode.url ? 'Title override' : 'Recipe title',
          hint: 'Sunday pancakes',
          controller: _titleController,
          textInputAction: TextInputAction.next,
          maxLength: 150,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: 'Notes',
          hint: 'What makes this recipe worth saving',
          controller: _descriptionController,
          minLines: 2,
          maxLines: 4,
        ),
        const SizedBox(height: MitlistSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppInput(
                label: 'Prep',
                hint: '10',
                controller: _prepTimeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: MitlistSpacing.md),
            Expanded(
              child: AppInput(
                label: 'Cook',
                hint: '20',
                controller: _cookTimeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppInput(
                label: 'Servings',
                hint: '4',
                controller: _servingsController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: MitlistSpacing.md),
            Expanded(
              child: AppInput(
                label: 'Tags',
                hint: 'quick, vegetarian',
                controller: _tagsController,
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppSwitchListTile(
          title: 'Share with household',
          value: _isPublic,
          onChanged:
              _isSaving ? null : (value) => setState(() => _isPublic = value),
        ),
      ],
    );
  }

  Widget _buildStep3(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput(
          label: 'Ingredients',
          hint: '2 cups flour\n1 cup milk\n3 eggs',
          controller: _ingredientsController,
          minLines: 4,
          maxLines: 8,
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: 'Steps',
          hint: 'Mix batter\nCook until golden',
          controller: _stepsController,
          minLines: 3,
          maxLines: 6,
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: 'Nutrition',
          hint: '520 kcal, 24g protein, high fiber',
          controller: _nutritionController,
          minLines: 2,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildBottomBar(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outline, width: 2),
        ),
      ),
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: AppButton(
                text: 'Back',
                variant: AppButtonVariant.outline,
                color: AppButtonColor.neutral,
                onPressed: _goBack,
              ),
            )
          else
            const Expanded(child: SizedBox.shrink()),
          const SizedBox(width: MitlistSpacing.md),
          Expanded(
            child: _currentStep < 2
                ? AppButton(
                    text: 'Next',
                    variant: AppButtonVariant.solid,
                    color: AppButtonColor.primary,
                    onPressed: _canGoNext ? _goNext : null,
                  )
                : AppButton(
                    text: _isSaving ? 'Creating…' : 'Create recipe',
                    variant: AppButtonVariant.solid,
                    color: AppButtonColor.primary,
                    size: AppButtonSize.lg,
                    isLoading: _isSaving,
                    onPressed: _canCreate ? _onCreate : null,
                  ),
          ),
        ],
      ),
    );
  }
}
