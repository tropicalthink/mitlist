import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/group_models.dart';
import '../../models/recipe_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/grocery_provider.dart';
import '../../providers/list_provider.dart' show grocerySeedProvider;
import '../../providers/recipe_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../services/scan/grocery_suggestion_service.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/haptics.dart';
import '../../utils/active_group_context.dart';
import '../../utils/list_composer_parser.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_switch.dart';
import '../../widgets/chip.dart';
import '../../widgets/mitlist_app_bar.dart';

import '../../widgets/app_toast.dart';

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

  /// Whether to share the new recipe with the active household. Backed by a
  /// real group id at save time — the old flag set a server-wide public bit
  /// while this switch promised household-only sharing.
  bool _shareWithHousehold = false;
  bool _isSaving = false;
  bool _isScraping = false;
  _RecipeEntryMode _mode = _RecipeEntryMode.url;
  List<Group> _groups = [];

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGroups());
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await ref.read(cachedGroupsProvider.future);
      if (mounted) setState(() => _groups = groups);
    } catch (_) {}
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
    final l10n = AppLocalizations.of(context)!;
    if (!_isDirty) return true;
    final result = await showAppDialog<bool>(
      context: context,
      title: l10n.recipeCreationDiscardTitle,
      body: Text(l10n.recipeCreationDiscardBody),
      actions: [
        AppButton(
          text: l10n.recipeCreationKeepEditing,
          variant: AppButtonVariant.outline,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: l10n.recipeCreationDiscard,
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    return result == true;
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
      final l10n = AppLocalizations.of(context)!;
      AppToast.success(context, l10n.recipeCreationImported(parts.join(', ')));
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _isScraping = false);
      AppToast.error(context, l10n.recipeCreationCouldNotFetch);
    }
  }

  Future<void> _onCreate() async {
    if (!_canCreate) return;

    setState(() => _isSaving = true);

    try {
      final l10n = AppLocalizations.of(context)!;
      final recipeService = await ref.read(recipeServiceProviderAsync.future);
      final url = _urlController.text.trim();
      final title = _titleController.text.trim().isEmpty
          ? _titleFromUrl(url, l10n)
          : _titleController.text.trim();
      final ingredients = await _buildEnrichedIngredients();

      await recipeService.createRecipe(
        CreateRecipeRequest(
          title: title,
          description: _buildDescription(url, l10n),
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
          visibility: _shareWithHousehold
              ? RecipeVisibility.household
              : RecipeVisibility.private,
          groupId: _shareWithHousehold ? _activeGroupId() : null,
          ingredients: ingredients,
          steps: _buildSteps(),
        ),
      );

      if (!mounted) return;
      if (context.mounted) context.pop(true);
      AppToast.success(context, l10n.recipeCreationCreated);
      unawaited(Haptics.success());
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() => _isSaving = false);
      AppToast.error(context, l10n.recipeCreationCouldNotCreate);
    }
  }

  String _titleFromUrl(String url, AppLocalizations l10n) {
    final fallback = url.replaceFirst(RegExp(r'^https?://'), '');
    final host = Uri.tryParse(url)?.host;
    if (host == null || host.isEmpty) {
      return fallback.isEmpty ? l10n.recipeCreationImportedTitle : fallback;
    }
    return l10n.recipeCreationFromHost(host.replaceFirst('www.', ''));
  }

  String _buildDescription(String url, AppLocalizations l10n) {
    final parts = <String>[];
    if (_descriptionController.text.trim().isNotEmpty) {
      parts.add(_descriptionController.text.trim());
    }
    if (_nutritionController.text.trim().isNotEmpty &&
        _scrapedNutrition == null) {
      parts.add(l10n.recipeCreationNutrition(_nutritionController.text.trim()));
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
        .map((line) {
      final parsed = parseComposerItem(line);
      return CreateIngredientRequest(
        name: parsed.name,
        quantity: parsed.quantity == 1
            ? ''
            : parsed.quantity
                .toStringAsFixed(2)
                .replaceAll(RegExp(r'0+$'), '')
                .replaceAll(RegExp(r'\.$'), ''),
        unit: parsed.unit,
        rawText: line,
      );
    }).toList();
  }

  /// The household a shared recipe would land in: the one the user is
  /// currently looking at, falling back to their only household.
  Group? _activeGroup() {
    final id = _activeGroupId();
    if (id == null) return null;
    for (final g in _groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  String? _activeGroupId() =>
      resolveActiveGroupId(_groups, ref.read(currentGroupIdProvider));

  Future<List<CreateIngredientRequest>> _buildEnrichedIngredients() async {
    final ingredients = _buildIngredients();
    final groupId = resolveActiveGroupId(
      _groups,
      ref.read(currentGroupIdProvider),
    );
    if (groupId == null || ingredients.isEmpty) return ingredients;
    try {
      await ref.read(grocerySeedProvider.future);
      final links = ref.read(canonicalLinkServiceProvider);
      final context = <String>[];
      final resolutionContext = await links.prepareContext(groupId);
      final enriched = <CreateIngredientRequest>[];
      for (final ingredient in ingredients) {
        final result = await links.resolveHighConfidenceResult(
          ingredient.name,
          groupId,
          listContext: context,
          context: resolutionContext,
        );
        if (result?.canonicalItemId case final canonicalId?) {
          context.add(canonicalId);
        }
        enriched.add(CreateIngredientRequest(
          // Keep the original line in rawText, while giving recipe/list
          // integrations the clean canonical label for matching and merging.
          name: result == null
              ? ingredient.name
              : GrocerySuggestionService.labelForSelection(
                  ingredient.name,
                  result.displayName,
                ),
          quantity: ingredient.quantity,
          unit: ingredient.unit,
          rawText: ingredient.rawText,
        ));
      }
      return enriched;
    } catch (_) {
      return ingredients;
    }
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

  String _nextButtonLabel(AppLocalizations l10n) {
    return switch (_currentStep) {
      0 => l10n.recipeCreationNextDetails,
      1 => l10n.recipeCreationNextContent,
      _ => l10n.commonNext,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          title: Text(
            l10n.recipeCreationTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          showStandardActions: false,
          leading: IconButton(
            icon: const AppIcon(name: 'xMark'),
            tooltip: l10n.commonClose,
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
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.recipeCreationStepSource,
      l10n.recipeCreationStepDetails,
      l10n.recipeCreationStepContent,
    ];
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
            _buildDot(i, colorScheme, labels[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildDot(int index, ColorScheme colorScheme, String label) {
    final l10n = AppLocalizations.of(context)!;
    final isActive = index == _currentStep;
    final isComplete = index < _currentStep;
    final status =
        isActive ? 'current' : (isComplete ? 'complete' : 'upcoming');

    Color dotColor;
    if (isActive) {
      dotColor = colorScheme.primary;
    } else if (isComplete) {
      dotColor = colorScheme.primary;
    } else {
      dotColor = colorScheme.surfaceContainerHighest;
    }

    return Semantics(
      label: l10n.recipeCreationStepSemantics(index + 1, 3, label, status),
      selected: isActive,
      child: Column(
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
            label,
            style: MitlistTypography.labelXSmall(
              color:
                  isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.recipeCreationStartHeadline,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: MitlistSpacing.xs),
        Text(
          l10n.recipeCreationStartSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: MitlistSpacing.lg),
        _buildEntryOption(
          colorScheme: colorScheme,
          icon: 'link',
          title: l10n.recipeCreationImportURL,
          subtitle: l10n.recipeCreationImportURLDesc,
          selected: _mode == _RecipeEntryMode.url,
          onTap: _isSaving
              ? null
              : () => setState(() => _mode = _RecipeEntryMode.url),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        _buildEntryOption(
          colorScheme: colorScheme,
          icon: 'editNote',
          title: l10n.recipeCreationTypeItIn,
          subtitle: l10n.recipeCreationTypeItInDesc,
          selected: _mode == _RecipeEntryMode.manual,
          onTap: _isSaving
              ? null
              : () => setState(() => _mode = _RecipeEntryMode.manual),
        ),
        const SizedBox(height: MitlistSpacing.lg),
        if (_mode == _RecipeEntryMode.url) ...[
          AppInput(
            label: l10n.recipeCreationURLInput,
            hint: l10n.recipeCreationURLHint,
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
            text: _isScraping
                ? l10n.recipeCreationFetching
                : l10n.recipeCreationFetchDetails,
            isLoading: _isScraping,
            onPressed: _canScrape ? _onScrape : null,
          ),
          if (_scrapedImageOptions.length > 1) ...[
            const SizedBox(height: MitlistSpacing.md),
            Text(
              l10n.recipeCreationChooseImage,
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
                    label: l10n.recipeCreationSelectImage(index + 1),
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
            label: l10n.recipeCreationTitleInput,
            hint: l10n.recipeCreationTitleHint,
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppInput(
          label: _mode == _RecipeEntryMode.url
              ? l10n.recipeCreationTitleOverride
              : l10n.recipeCreationTitleInput,
          hint: l10n.recipeCreationTitleHint,
          controller: _titleController,
          textInputAction: TextInputAction.next,
          maxLength: 150,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: l10n.recipeCreationNotesInput,
          hint: l10n.recipeCreationNotesHint,
          controller: _descriptionController,
          minLines: 2,
          maxLines: 4,
        ),
        const SizedBox(height: MitlistSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppInput(
                label: l10n.recipeCreationPrepLabel,
                hint: l10n.recipeCreationPrepHint,
                controller: _prepTimeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: MitlistSpacing.md),
            Expanded(
              child: AppInput(
                label: l10n.recipeCreationCookLabel,
                hint: l10n.recipeCreationCookHint,
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
                label: l10n.recipeCreationServingsLabel,
                hint: l10n.recipeCreationServingsHint,
                controller: _servingsController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: MitlistSpacing.md),
            Expanded(
              child: AppInput(
                label: l10n.recipeCreationTagsInput,
                hint: l10n.recipeCreationTagsHint,
                controller: _tagsController,
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppSwitchListTile(
          title: l10n.recipeCreationSaveForHousehold,
          // Without a household there is nobody to share with, so the switch
          // is disabled and says so rather than silently doing nothing.
          subtitle: _activeGroup() == null
              ? l10n.recipeCreationNoHousehold
              : (_shareWithHousehold
                  ? l10n.recipeCreationSharedWithHousehold(_activeGroup()!.name)
                  : l10n.recipeCreationSaveForHouseholdPrivate),
          value: _shareWithHousehold,
          onChanged: _isSaving || _activeGroup() == null
              ? null
              : (value) => setState(() => _shareWithHousehold = value),
        ),
      ],
    );
  }

  Widget _buildStep3(ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RecipeLineEditor(
          title: l10n.recipeCreationIngredients,
          helperText: l10n.recipeCreationIngredientsHelper,
          addLabel: l10n.recipeCreationAddIngredient,
          emptyHint: l10n.recipeCreationIngredientHint,
          lines: _controllerLines(_ingredientsController),
          onChanged: _setIngredientLines,
          groceryGroupId: resolveActiveGroupId(
            _groups,
            ref.watch(currentGroupIdProvider),
          ),
        ),
        // Wider than the md used elsewhere: with the cards gone, this gap is
        // the only thing separating the two editors.
        const SizedBox(height: MitlistSpacing.lg),
        _RecipeLineEditor(
          title: l10n.recipeCreationSteps,
          helperText: l10n.recipeCreationStepsHelper,
          addLabel: l10n.recipeCreationAddStep,
          emptyHint: l10n.recipeCreationStepHint,
          numbered: true,
          lines: _controllerLines(_stepsController),
          onChanged: (lines) => _setControllerLines(_stepsController, lines),
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: l10n.recipeCreationNutritionInput,
          hint: l10n.recipeCreationNutritionHint,
          controller: _nutritionController,
          minLines: 2,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildBottomBar(ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;
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
                  text: l10n.commonBack,
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
                      text: _nextButtonLabel(l10n),
                      variant: AppButtonVariant.solid,
                      color: AppButtonColor.primary,
                      onPressed: _canGoNext ? _goNext : null,
                    )
                  : AppButton(
                      text: _isSaving
                          ? l10n.recipeCreationCreating
                          : l10n.recipeCreationCreateRecipe,
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

class _RecipeLineEditor extends ConsumerStatefulWidget {
  final String title;
  final String helperText;
  final String addLabel;
  final String emptyHint;
  final bool numbered;
  final List<String> lines;
  final ValueChanged<List<String>> onChanged;
  final String? groceryGroupId;

  const _RecipeLineEditor({
    required this.title,
    required this.helperText,
    required this.addLabel,
    required this.emptyHint,
    required this.lines,
    required this.onChanged,
    this.groceryGroupId,
    this.numbered = false,
  });

  @override
  ConsumerState<_RecipeLineEditor> createState() => _RecipeLineEditorState();
}

class _RecipeLineEditorState extends ConsumerState<_RecipeLineEditor> {
  final TextEditingController _draftController = TextEditingController();
  final FocusNode _draftFocusNode = FocusNode();
  late List<TextEditingController> _controllers;
  Timer? _suggestDebounce;
  List<GrocerySuggestion> _suggestions = const [];
  int _suggestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controllers =
        widget.lines.map((line) => TextEditingController(text: line)).toList();
    _draftController.addListener(_handleDraftChanged);
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
    _suggestDebounce?.cancel();
    _draftController.removeListener(_handleDraftChanged);
    _draftFocusNode.dispose();
    _draftController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleDraftChanged() {
    if (mounted) setState(() {});
    _scheduleSuggestions();
  }

  void _scheduleSuggestions() {
    final groupId = widget.groceryGroupId;
    final query = parseComposerItem(_draftController.text).name.trim();
    final generation = ++_suggestGeneration;
    _suggestDebounce?.cancel();
    if (groupId == null || query.length < 2) {
      if (_suggestions.isNotEmpty && mounted) {
        setState(() => _suggestions = const []);
      }
      return;
    }
    _suggestDebounce = Timer(const Duration(milliseconds: 220), () async {
      try {
        await ref.read(grocerySeedProvider.future);
        final suggestions =
            await ref.read(grocerySuggestionServiceProvider).suggest(
                  query,
                  groupId,
                  suggestionContext: GrocerySuggestionContext.recipe,
                  limit: 5,
                );
        if (!mounted || generation != _suggestGeneration) return;
        setState(() => _suggestions = suggestions);
      } catch (_) {}
    });
  }

  void _selectSuggestion(GrocerySuggestion suggestion) {
    final typed = _draftController.text.trim();
    final parsed = parseComposerItem(typed);
    final label = GrocerySuggestionService.labelForSelection(
      parsed.name,
      suggestion.name,
    );
    final nameOffset = typed.lastIndexOf(parsed.name);
    final prefix = nameOffset <= 0 ? '' : typed.substring(0, nameOffset);
    final replacement = '$prefix$label';
    _draftController.value = TextEditingValue(
      text: replacement,
      selection: TextSelection.collapsed(offset: replacement.length),
    );
    setState(() => _suggestions = const []);
    _draftFocusNode.requestFocus();
  }

  bool get _canAddDraft => _draftController.text.trim().isNotEmpty;

  String get _itemLabel => widget.numbered ? 'step' : 'ingredient';

  String _countLabel(AppLocalizations l10n) {
    final count = _controllers.length;
    final type = l10n.recipeCreationStepLabel(_itemLabel);
    return '$count $type${count == 1 ? '' : 's'}';
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
    _draftFocusNode.requestFocus();
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
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Deliberately not an AppCard: the ingredient and step editors are the
    // main body of this page, not asides. Boxing them nested a bordered card
    // inside the bordered page for the two sections the user is actually
    // filling in, and left them looking heavier than the plain inputs below.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _countLabel(l10n),
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
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
              l10n.recipeCreationNoItemsYet(widget.title.toLowerCase()),
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
                    widget.numbered ? '${i + 1}' : '\u2022',
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
                  tooltip: l10n.recipeCreationRemoveItem(_itemLabel, i + 1),
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
                focusNode: _draftFocusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addDraft(),
              ),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            AppButton(
              text: widget.addLabel,
              size: AppButtonSize.sm,
              variant: AppButtonVariant.outline,
              icon: const AppIcon(name: 'plus', size: 16),
              semanticLabel: widget.addLabel,
              onPressed: _canAddDraft ? _addDraft : null,
            ),
          ],
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.sm),
          Wrap(
            spacing: MitlistSpacing.xs,
            runSpacing: MitlistSpacing.xs,
            children: [
              for (final suggestion in _suggestions)
                AppChip(
                  label: suggestion.name,
                  onSelected: (_) => _selectSuggestion(suggestion),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
