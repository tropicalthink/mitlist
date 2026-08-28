import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../models/recipe_models.dart';
import '../../providers/recipe_provider.dart';
import '../../sheets/recipe_add_to_list_sheet.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../utils/latest_request_guard.dart';
import '../../utils/safe_launch.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_divider.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/skeleton.dart';

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final String recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  Recipe? _recipe;
  List<RecipeIngredient> _ingredients = const [];
  List<RecipeStep> _steps = const [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isDeleting = false;
  bool _isSharing = false;
  final LatestRequestGuard _loadGuard = LatestRequestGuard();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RecipeDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recipeId == widget.recipeId) return;
    _loadGuard.invalidate();
    _recipe = null;
    _ingredients = const [];
    _steps = const [];
    _hasError = false;
    _isDeleting = false;
    _isLoading = true;
    _load();
  }

  @override
  void dispose() {
    _loadGuard.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = _loadGuard.begin();
    final hadContent = _recipe != null;
    setState(() {
      _isLoading = !hadContent;
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
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      setState(() {
        _recipe = recipe;
        _ingredients = ingredients;
        _steps = steps;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      if (hadContent) {
        setState(() => _isLoading = false);
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.recipeDetailCouldNotLoad)),
        );
        return;
      }
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  /// Hands a share link to the OS share sheet.
  ///
  /// The link opens the recipe inside Mitlist for anyone who has it, and falls
  /// back to the web app — recipe visible, with a prompt to install — for
  /// anyone who does not. The server mints the token on first share and
  /// returns the same one afterwards, so sharing twice does not scatter extra
  /// live links.
  Future<void> _shareRecipe() async {
    final recipe = _recipe;
    if (recipe == null) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isSharing = true);
    try {
      final service = await ref.read(recipeServiceProviderAsync.future);
      final link = await service.createShareLink(recipe.id);
      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(text: l10n.recipeShareText(recipe.title, link.url)),
      );
      unawaited(Haptics.success());
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, friendlyErrorMessage(e, l10n));
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (_isDeleting) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.recipeDetailDeleteTitle,
      body: Text(l10n.recipeDetailDeleteBody),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: l10n.commonDelete,
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      unawaited(Haptics.failure());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: MitlistAppBar(
        title: Text(
          l10n.recipeDetailTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        showStandardActions: false,
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: l10n.commonBack,
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_recipe != null)
            IconButton(
              icon: const AppIcon(name: 'share'),
              tooltip: l10n.recipeDetailShareTooltip,
              onPressed: _isSharing ? null : _shareRecipe,
            ),
          if (_recipe != null)
            IconButton(
              icon: const AppIcon(name: 'trash'),
              tooltip: l10n.recipeDetailDeleteTooltip,
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
                        text: l10n.recipeDetailAddToList,
                        size: AppButtonSize.lg,
                        variant: AppButtonVariant.outline,
                        onPressed: _addToList,
                      ),
                    ),
                    if (_steps.isNotEmpty) ...[
                      const SizedBox(width: MitlistSpacing.sm),
                      Expanded(
                        child: AppButton(
                          text: l10n.recipeDetailCook,
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
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return _buildLoading();
    }
    if (_hasError || _recipe == null) {
      return Center(
        child: AppEmptyState(
          icon: const AppIcon(name: 'restaurant', size: 48),
          title: l10n.recipeDetailCouldNotLoad,
          description: l10n.commonCheckConnection,
          isError: true,
          actions: [
            AppButton(
              text: l10n.commonRetry,
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nutritionMap = _parseNutrition(recipe.nutritionJson);
    final equipmentList = _parseEquipment(recipe.equipmentJson);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppChip(
          label: recipe.isSharedWithHousehold
              ? l10n.recipeDetailSharedLabel
              : l10n.recipeDetailPrivateLabel,
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
            l10n.recipeDetailBy(recipe.author),
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
                l10n.recipeRatingLabel(
                    recipe.ratingValue.toStringAsFixed(1), recipe.ratingCount),
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
                child:
                    const Center(child: AppIcon(name: 'restaurant', size: 48)),
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
              _DetailRow(
                  label: l10n.recipeDetailPrep,
                  value: _formatMinutes(recipe.prepTime, l10n)),
              const AppDivider(),
              _DetailRow(
                  label: l10n.recipeDetailCook,
                  value: _formatMinutes(recipe.cookTime, l10n)),
              const AppDivider(),
              _DetailRow(
                  label: l10n.recipeDetailServings,
                  value: recipe.servings.toString()),
              const AppDivider(),
              _DetailRow(
                label: l10n.recipeDetailUpdated,
                value: DateFormat.yMMMd().format(recipe.updatedAt),
              ),
            ],
          ),
        ),
        if (nutritionMap.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          _SectionHeader(title: l10n.recipeDetailNutrition),
          const SizedBox(height: MitlistSpacing.xs),
          Wrap(
            spacing: MitlistSpacing.sm,
            runSpacing: MitlistSpacing.sm,
            children: nutritionMap.entries
                .map((e) =>
                    AppChip(label: '${e.key}: ${e.value}', selected: false))
                .toList(),
          ),
        ],
        if (equipmentList.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          _SectionHeader(title: l10n.recipeDetailEquipment),
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
          _SectionHeader(
            title: l10n.recipeDetailIngredients,
            count: _ingredients.length,
          ),
          const SizedBox(height: MitlistSpacing.xs),
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.none,
            child: Semantics(
              label:
                  '${_ingredients.length} ingredient${_ingredients.length == 1 ? '' : 's'}',
              child: Column(
                children: _ingredients.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final ing = entry.value;
                  final name = ing.name.isNotEmpty ? ing.name : ing.rawText;
                  final qty =
                      ing.quantity > 0 ? _formatQuantity(ing.quantity) : '';
                  final unit = ing.unit.isNotEmpty ? ing.unit : '';
                  final amount =
                      [qty, unit].where((s) => s.isNotEmpty).join(' ');
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MitlistSpacing.md,
                          vertical: MitlistSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            if (amount.isNotEmpty) ...[
                              const SizedBox(width: MitlistSpacing.sm),
                              Text(
                                amount,
                                style: MitlistTypography.monoBody(
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (idx < _ingredients.length - 1)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
        if (_steps.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          _SectionHeader(
            title: l10n.recipeDetailSteps,
            count: _steps.length,
          ),
          const SizedBox(height: MitlistSpacing.xs),
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.none,
            child: Semantics(
              label: l10n.recipeDetailStepCount(_steps.length),
              child: Column(
                children: _steps.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final step = entry.value;
                  final desc = step.description.isNotEmpty
                      ? step.description
                      : step.name;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MitlistSpacing.md,
                          vertical: MitlistSpacing.sm,
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
                              child: Text(
                                desc,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (idx < _steps.length - 1)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant,
                        ),
                    ],
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
            label: l10n.recipeDetailWatchVideo,
            semanticLabel: l10n.recipeDetailWatchVideoSemantics,
            onTap: () => safeLaunchUrl(recipe.videoUrl),
          ),
        ],
        if (recipe.sourceUrl.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          _LinkRow(
            icon: 'openInNew',
            label: l10n.recipeDetailViewOriginal,
            semanticLabel: l10n.recipeDetailViewOriginalSemantics,
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

  static String _formatMinutes(int minutes, AppLocalizations l10n) {
    if (minutes <= 0) {
      return l10n.recipeDetailNotSet;
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        if (count != null) ...[
          const SizedBox(width: MitlistSpacing.xs),
          Text(
            count.toString(),
            style: MitlistTypography.labelXSmall(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
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
