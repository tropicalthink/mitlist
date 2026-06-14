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
import '../../widgets/app_card.dart';
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

enum _RecipeEntryMode { url, manual }

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
  _RecipeEntryMode _mode = _RecipeEntryMode.url;

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
  List<RecipeClipIngredient> _scrapedIngredients = [];

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

  bool get _canScrape => _mode == _RecipeEntryMode.url && _hasUrl && !_isSaving;

  bool get _canGoNext {
    if (_currentStep == 0) {
      if (_mode == _RecipeEntryMode.url) return _hasUrl;
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

      if (clip.prepTimeMinutes != null &&
          clip.prepTimeMinutes! > 0 &&
          _prepTimeController.text.trim().isEmpty) {
        _prepTimeController.text = clip.prepTimeMinutes.toString();
      }
      if (clip.cookTimeMinutes != null &&
          clip.cookTimeMinutes! > 0 &&
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
      _scrapedIngredients = clip.ingredients;

      setState(() {
        _isScraping = false;
        if (_currentStep == 0) _currentStep = 1;
      });

      final ingCount = clip.ingredients.length;
      final stepCount = clip.instructionsMd
          .split('\n\n')
          .where((s) => s.trim().isNotEmpty)
          .length;
      final parts = <String>[
        if (ingCount > 0) '$ingCount ingredient${ingCount == 1 ? '' : 's'}',
        if (stepCount > 0) '$stepCount step${stepCount == 1 ? '' : 's'}',
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            parts.isEmpty ? 'Recipe imported' : 'Imported: ${parts.join(', ')}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScraping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't fetch details from that link.")),
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
          ingredients: _buildIngredients(),
          steps: _buildSteps(),
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
    // Include free-text nutrition only when no structured nutrition was scraped,
    // since the detail screen has no other place to show it.
    if (_nutritionController.text.trim().isNotEmpty &&
        _scrapedNutrition == null) {
      parts.add('Nutrition: ${_nutritionController.text.trim()}');
    }
    return parts.join('\n\n');
  }

  // Strips common list prefixes: "- ", "* ", "• ", "1. ", "1) ", "Step 1: " etc.
  static final _listPrefixRe = RegExp(
    r'^(?:Step\s+\d+[:.)\s]\s*|\d+[.)]\s*|[-*•]\s*)',
    caseSensitive: false,
  );

  static String _stripPrefix(String line) =>
      line.trim().replaceFirst(_listPrefixRe, '').trim();

  // Clears scraped ingredients when the user manually edits the text area,
  // so that _buildIngredients() falls back to text parsing for their edits.
  void _onIngredientsChanged(String value) {
    if (_scrapedIngredients.isEmpty) return;
    final expected = _scrapedIngredients.map((i) => i.rawText).join('\n');
    if (value != expected) {
      setState(() => _scrapedIngredients = []);
    }
  }

  List<String> _controllerLines(TextEditingController controller) {
    return controller.text
        .split('\n')
        .map(_stripPrefix)
        .where((line) => line.isNotEmpty)
        .toList();
  }

  void _setControllerLines(
    TextEditingController controller,
    List<String> lines, {
    VoidCallback? afterSet,
  }) {
    final text = lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    afterSet?.call();
    setState(() {});
  }

  void _setIngredientLines(List<String> lines) {
    _setControllerLines(
      _ingredientsController,
      lines,
      afterSet: () => _onIngredientsChanged(_ingredientsController.text),
    );
  }

  List<CreateIngredientRequest> _buildIngredients() {
    if (_scrapedIngredients.isNotEmpty) {
      return _scrapedIngredients
          .map((i) => CreateIngredientRequest(
                name: i.name.isNotEmpty ? i.name : i.rawText,
                quantity: i.quantity > 0
                    ? (i.quantity == i.quantity.roundToDouble()
                        ? i.quantity.toInt().toString()
                        : i.quantity
                            .toStringAsFixed(2)
                            .replaceAll(RegExp(r'0+$'), ''))
                    : '',
                unit: i.unit,
                rawText: i.rawText,
              ))
          .toList();
    }
    final text = _ingredientsController.text.trim();
    if (text.isEmpty) return const [];
    return text
        .split('\n')
        .map(_stripPrefix)
        .where((line) => line.isNotEmpty)
        .map((line) => CreateIngredientRequest(name: line, rawText: line))
        .toList();
  }

  List<CreateStepRequest> _buildSteps() {
    final text = _stepsController.text.trim();
    if (text.isEmpty) return const [];
    return text
        .split('\n')
        .map(_stripPrefix)
        .where((line) => line.isNotEmpty)
        .map((line) => CreateStepRequest(description: line))
        .toList();
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
                margin:
                    const EdgeInsets.symmetric(horizontal: MitlistSpacing.sm),
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
            color:
                isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
        Text(
          'Start your recipe',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: MitlistSpacing.xs),
        Text(
          'Import from a link, type it yourself, or scan a photo.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: MitlistSpacing.lg),
        _buildEntryOption(
          colorScheme: colorScheme,
          icon: 'link',
          title: 'Import from URL',
          subtitle: 'Paste a recipe link and we\u2019ll pull the details',
          selected: _mode == _RecipeEntryMode.url,
          onTap: _isSaving
              ? null
              : () => setState(() => _mode = _RecipeEntryMode.url),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        _buildEntryOption(
          colorScheme: colorScheme,
          icon: 'editNote',
          title: 'Type it in',
          subtitle: 'Start with a title and add ingredients later',
          selected: _mode == _RecipeEntryMode.manual,
          onTap: _isSaving
              ? null
              : () => setState(() => _mode = _RecipeEntryMode.manual),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        _buildEntryOption(
          colorScheme: colorScheme,
          icon: _isScanning ? 'hourglassEmpty' : 'documentScanner',
          title: _isScanning ? 'Scanning\u2026' : 'Scan a photo',
          subtitle: 'Snap a recipe card or cookbook page',
          selected: false,
          onTap: _isScanning || _isSaving ? null : _onScan,
        ),
        const SizedBox(height: MitlistSpacing.lg),
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
          AppButton(
            size: AppButtonSize.sm,
            variant: AppButtonVariant.outline,
            color: AppButtonColor.neutral,
            text: _isScraping ? 'Fetching\u2026' : 'Fetch details',
            isLoading: _isScraping,
            onPressed: _canScrape ? _onScrape : null,
          ),
          if (_scrapedImageOptions.length > 1) ...[
            const SizedBox(height: MitlistSpacing.md),
            Text(
              'Choose an image',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
                      onTap: () => setState(() => _selectedImageUrl = imgUrl),
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
                cacheWidth: (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context) *
                        1.5)
                    .round(),
                errorBuilder: (_, __, ___) => Container(
                  color: colorScheme.surfaceContainerLow,
                  child: const Center(
                    child: AppIcon(name: 'restaurant', size: 48),
                  ),
                ),
              ),
            ),
          ],
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

  Widget _buildEntryOption({
    required ColorScheme colorScheme,
    required String icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return AppCard(
      variant: selected ? AppCardVariant.outlined : AppCardVariant.soft,
      tint: selected ? AppCardTint.primary : AppCardTint.neutral,
      padding: AppCardPadding.md,
      interactive: onTap != null,
      onTap: onTap,
      semanticLabel: title,
      child: Row(
        children: [
          Container(
            width: MitlistSpacing.space11,
            height: MitlistSpacing.space11,
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              border: Border.all(
                color: selected ? colorScheme.primary : colorScheme.outline,
                width: 2,
              ),
            ),
            child: Center(
              child: AppIcon(
                name: icon,
                size: 20,
                color: selected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: MitlistSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: MitlistSpacing.xs),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (selected)
            AppIcon(name: 'check', size: 18, color: colorScheme.primary),
        ],
      ),
    );
  }

  Widget _buildStep2(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput(
          label:
              _mode == _RecipeEntryMode.url ? 'Title override' : 'Recipe title',
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
                label: 'Prep (min)',
                hint: '10',
                controller: _prepTimeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: MitlistSpacing.md),
            Expanded(
              child: AppInput(
                label: 'Cook (min)',
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
          title: 'Save for household',
          subtitle: _isPublic
              ? 'Everyone in this household can find and use this recipe.'
              : 'Keep it private for now. You can share it later.',
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
        _RecipeLineEditor(
          title: 'Ingredients',
          helperText: 'Add one ingredient per row.',
          addLabel: 'Add ingredient',
          emptyHint: '2 cups flour',
          lines: _controllerLines(_ingredientsController),
          onChanged: _setIngredientLines,
        ),
        const SizedBox(height: MitlistSpacing.md),
        _RecipeLineEditor(
          title: 'Steps',
          helperText: 'Keep each step short enough to follow while cooking.',
          addLabel: 'Add step',
          emptyHint: 'Mix batter',
          numbered: true,
          lines: _controllerLines(_stepsController),
          onChanged: (lines) => _setControllerLines(_stepsController, lines),
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
    return SafeArea(
      top: false,
      child: Container(
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
      ),
    );
  }
}

class _RecipeLineEditor extends StatefulWidget {
  final String title;
  final String helperText;
  final String addLabel;
  final String emptyHint;
  final bool numbered;
  final List<String> lines;
  final ValueChanged<List<String>> onChanged;

  const _RecipeLineEditor({
    required this.title,
    required this.helperText,
    required this.addLabel,
    required this.emptyHint,
    required this.lines,
    required this.onChanged,
    this.numbered = false,
  });

  @override
  State<_RecipeLineEditor> createState() => _RecipeLineEditorState();
}

class _RecipeLineEditorState extends State<_RecipeLineEditor> {
  final TextEditingController _draftController = TextEditingController();
  late List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers =
        widget.lines.map((line) => TextEditingController(text: line)).toList();
  }

  @override
  void didUpdateWidget(covariant _RecipeLineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameLines(widget.lines, _currentLines())) return;
    for (final controller in _controllers) {
      controller.dispose();
    }
    _controllers =
        widget.lines.map((line) => TextEditingController(text: line)).toList();
  }

  @override
  void dispose() {
    _draftController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _sameLines(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  List<String> _currentLines() {
    return _controllers
        .map((controller) => controller.text.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  void _emit() {
    widget.onChanged(_currentLines());
  }

  void _addDraft() {
    final text = _draftController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _controllers.add(TextEditingController(text: text));
      _draftController.clear();
    });
    _emit();
  }

  void _removeAt(int index) {
    setState(() {
      final controller = _controllers.removeAt(index);
      controller.dispose();
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: MitlistSpacing.xs),
          Text(
            widget.helperText,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: MitlistSpacing.md),
          if (_controllers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(MitlistSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                border: Border.all(color: colorScheme.outline, width: 1),
              ),
              child: Text(
                'No ${widget.title.toLowerCase()} yet.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (var i = 0; i < _controllers.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: MitlistSpacing.space7,
                    height: MitlistSpacing.space11,
                    alignment: Alignment.center,
                    child: Text(
                      widget.numbered ? '${i + 1}' : '•',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: MitlistSpacing.xs),
                  Expanded(
                    child: AppInput(
                      hint: widget.emptyHint,
                      controller: _controllers[i],
                      minLines: 1,
                      maxLines: 3,
                      onChanged: (_) => _emit(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove ${widget.title.toLowerCase()} ${i + 1}',
                    icon: const AppIcon(name: 'xMark', size: 18),
                    onPressed: () => _removeAt(i),
                  ),
                ],
              ),
              if (i != _controllers.length - 1)
                const SizedBox(height: MitlistSpacing.sm),
            ],
          const SizedBox(height: MitlistSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppInput(
                  hint: widget.emptyHint,
                  controller: _draftController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addDraft(),
                ),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              AppButton(
                text: 'Add',
                size: AppButtonSize.sm,
                variant: AppButtonVariant.outline,
                icon: const AppIcon(name: 'plus', size: 16),
                semanticLabel: widget.addLabel,
                onPressed: _addDraft,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
