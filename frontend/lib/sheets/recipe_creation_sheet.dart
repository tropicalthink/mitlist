import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/recipe_models.dart';
import '../providers/recipe_provider.dart';
import '../providers/scan_provider.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
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
      title: 'New Recipe',
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

enum _RecipeEntryMode { url, manual }

class _RecipeCreationSheetState extends ConsumerState<RecipeCreationSheet> {
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
        const SnackBar(content: Text('Couldn\u2019t scan recipe.')),
      );
    }
  }

  bool get _hasTitle => _titleController.text.trim().isNotEmpty;
  bool get _hasUrl => _urlController.text.trim().isNotEmpty;
  bool get _canCreate =>
      !_isSaving && (_mode == _RecipeEntryMode.url ? _hasUrl : _hasTitle);

  bool get _canScrape => _mode == _RecipeEntryMode.url && _hasUrl && !_isSaving;

  Future<void> _onScrape() async {
    if (_isScraping || _isSaving) return;
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isScraping = true);
    try {
      final recipeService = await ref.read(recipeServiceProviderAsync.future);
      final clip = await recipeService.clipRecipeFromUrl(url);

      if (!mounted) return;

      if (_titleController.text.trim().isEmpty && clip.title.trim().isNotEmpty) {
        _titleController.text = clip.title.trim();
      }

      if (clip.description.trim().isNotEmpty && _descriptionController.text.trim().isEmpty) {
        _descriptionController.text = clip.description.trim();
      }

      if (clip.prepTimeMinutes != null && clip.prepTimeMinutes! > 0) {
        _prepTimeController.text = clip.prepTimeMinutes.toString();
      }
      if (clip.cookTimeMinutes != null && clip.cookTimeMinutes! > 0) {
        _cookTimeController.text = clip.cookTimeMinutes.toString();
      }
      final servings = (clip.servings ?? '').trim();
      if (servings.isNotEmpty) {
        final parsed = int.tryParse(servings);
        if (parsed != null && parsed > 0 && _servingsController.text.trim() == '1') {
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

      // Store scraped metadata
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
        const SnackBar(content: Text('Couldn\u2019t fetch details from that link.')),
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
          nutritionJson: _scrapedNutrition != null ? jsonEncode(_scrapedNutrition) : '',
          videoUrl: _scrapedVideoUrl,
          equipmentJson: _scrapedEquipment.isNotEmpty ? jsonEncode(_scrapedEquipment) : '',
          sourceUrl: url.isNotEmpty ? url : _scrapedSourceUrl,
          prepTime: _parsePositiveInt(_prepTimeController.text) ?? 0,
          cookTime: _parsePositiveInt(_cookTimeController.text) ?? 0,
          servings: _parsePositiveInt(_servingsController.text) ?? 1,
          imageUrl: _selectedImageUrl,
          imageOptions: _scrapedImageOptions,
          tags: _tagsController.text.trim().isNotEmpty
              ? _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
              : const [],
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
        const SnackBar(content: Text('Couldn\u2019t create recipe.')),
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppButton(
            text: _isScanning ? 'Scanning…' : 'Scan recipe',
            icon: Icon(
              _isScanning ? Icons.hourglass_empty : Icons.document_scanner_outlined,
              size: 20,
            ),
            variant: AppButtonVariant.outline,
            color: AppButtonColor.neutral,
            onPressed: _isScanning ? null : _onScan,
          ),
          const SizedBox(height: MitlistSpacing.md),
          SegmentedButton<_RecipeEntryMode>(
            segments: const [
              ButtonSegment(
                value: _RecipeEntryMode.url,
                icon: Icon(Icons.link),
                label: Text('URL'),
              ),
              ButtonSegment(
                value: _RecipeEntryMode.manual,
                icon: Icon(Icons.edit_note),
                label: Text('Manual'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: _isSaving
                ? null
                : (value) => setState(() => _mode = value.first),
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
              Text('Choose an image', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: MitlistSpacing.sm),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _scrapedImageOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: MitlistSpacing.sm),
                  itemBuilder: (context, index) {
                    final imgUrl = _scrapedImageOptions[index];
                    final isSelected = imgUrl == _selectedImageUrl;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedImageUrl = imgUrl),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? MitlistColors.primary500 : Colors.transparent,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(imgUrl),
                            fit: BoxFit.cover,
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
                borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _selectedImageUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: MitlistColors.neutral100,
                  child: const Center(child: Icon(Icons.restaurant, size: 48)),
                ),
              ),
              ),
            ],
            const SizedBox(height: MitlistSpacing.md),
          ],
          AppInput(
            label: _mode == _RecipeEntryMode.url
                ? 'Title override'
                : 'Recipe title',
            hint: 'Sunday pancakes',
            controller: _titleController,
            textInputAction: TextInputAction.next,
            maxLength: 150,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: MitlistSpacing.md),
          TextField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'What makes this recipe worth saving',
            ),
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
          TextField(
            controller: _ingredientsController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Ingredients',
              hintText: '2 cups flour\n1 cup milk\n3 eggs',
            ),
          ),
          const SizedBox(height: MitlistSpacing.md),
          TextField(
            controller: _stepsController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Steps',
              hintText: 'Mix batter\nCook until golden',
            ),
          ),
          const SizedBox(height: MitlistSpacing.md),
          TextField(
            controller: _nutritionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Nutrition',
              hintText: '520 kcal, 24g protein, high fiber',
            ),
          ),
          const SizedBox(height: MitlistSpacing.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Share with household'),
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
      ),
    );
  }
}
