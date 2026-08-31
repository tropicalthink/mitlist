import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/recipe_models.dart';
import '../../providers/recipe_provider.dart';
import '../../theme/spacing.dart';
import '../../utils/friendly_error.dart';
import '../../utils/latest_request_guard.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/list_entrance.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';

class CookbookDetailScreen extends ConsumerStatefulWidget {
  final String collectionId;

  /// The cookbook as the list screen knew it, so the header renders before
  /// the first fetch lands. Null when arriving by deep link.
  final RecipeCollection? initial;

  const CookbookDetailScreen({
    super.key,
    required this.collectionId,
    this.initial,
  });

  @override
  ConsumerState<CookbookDetailScreen> createState() =>
      _CookbookDetailScreenState();
}

class _CookbookDetailScreenState extends ConsumerState<CookbookDetailScreen> {
  bool _isLoading = true;
  String? _error;
  RecipeCollection? _collection;
  final List<Recipe> _recipes = [];
  String? _submittingId;
  bool _changed = false;
  final LatestRequestGuard _loadGuard = LatestRequestGuard();

  @override
  void initState() {
    super.initState();
    _collection = widget.initial;
    _load();
  }

  @override
  void didUpdateWidget(covariant CookbookDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collectionId == widget.collectionId) return;
    _loadGuard.invalidate();
    _recipes.clear();
    _collection = widget.initial;
    _error = null;
    _submittingId = null;
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
    final hadContent = _recipes.isNotEmpty;
    setState(() {
      _isLoading = !hadContent;
      _error = null;
    });
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      final results = await Future.wait([
        svc.getCollectionRecipes(widget.collectionId, limit: 200),
        svc.getCollection(widget.collectionId),
      ]);
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      setState(() {
        _recipes
          ..clear()
          ..addAll(results[0] as List<Recipe>);
        _collection = results[1] as RecipeCollection;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      final message = friendlyErrorMessage(e, AppLocalizations.of(context)!);
      if (hadContent) {
        setState(() => _isLoading = false);
        AppToast.error(context, message);
        return;
      }
      setState(() {
        _error = message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Tell the list screen whether counts need refreshing.
        context.pop(_changed);
      },
      child: Scaffold(
        appBar: MitlistAppBar(
          title: Text(
            _collection?.name ?? l10n.cookbooksTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          showStandardActions: false,
        ),
        body: _buildBody(),
        floatingActionButton: _isLoading || _error != null
            ? null
            : AppButton(
                size: AppButtonSize.lg,
                onPressed: _openAddRecipes,
                text: l10n.cookbookDetailAddRecipes,
                icon: const AppIcon(name: 'plus'),
                tooltip: l10n.cookbookDetailAddRecipes,
              ),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: _load,
      child: _buildBodyContent(),
    );
  }

  Widget _wrapForRefresh(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final collection = _collection;
    final shared = collection?.isSharedWithHousehold ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MitlistSpacing.md,
        MitlistSpacing.md,
        MitlistSpacing.md,
        MitlistSpacing.sm,
      ),
      child: Row(
        children: [
          AppIcon(
            name: shared ? 'userGroup' : 'keyOutline',
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: MitlistSpacing.xs),
          Expanded(
            child: Text(
              '${l10n.cookbooksRecipeCount(_recipes.length)} · '
              '${shared ? l10n.recipeDetailSharedLabel : l10n.cookbookDetailPersonal}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(MitlistSpacing.md),
        itemCount: 6,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: MitlistSpacing.sm),
          child: AppSkeleton(width: double.infinity, height: 96),
        ),
      );
    }
    if (_error != null) {
      return _wrapForRefresh(
        Center(
          child: AppEmptyState(
            icon: const AppIcon(name: 'alertCircleOutline'),
            title: l10n.commonSomethingWentWrong,
            description: _error,
            isError: true,
            actions: [
              AppButton(
                variant: AppButtonVariant.outline,
                text: l10n.commonRetry,
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }
    if (_recipes.isEmpty) {
      return _wrapForRefresh(
        Center(
          child: AppEmptyState(
            icon: const AppIcon(name: 'restaurantMenu', size: 56),
            title: l10n.cookbookDetailEmptyTitle,
            description: l10n.cookbookDetailEmptyDesc,
            actions: [
              AppButton(
                text: l10n.cookbookDetailAddRecipes,
                icon: const AppIcon(name: 'plus'),
                onPressed: _openAddRecipes,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        0,
        0,
        0,
        MitlistSpacing.xxl + MitlistSpacing.xl,
      ),
      itemCount: _recipes.length + 1,
      separatorBuilder: (_, index) => index == 0
          ? const SizedBox.shrink()
          : const SizedBox(height: MitlistSpacing.sm),
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeader();
        final r = _recipes[index - 1];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
          child: ListEntrance(
            index: index - 1,
            child: _RecipeRow(
              recipe: r,
              isSubmitting: _submittingId == r.id,
              onOpen: () => _openRecipe(r),
              onRemove: () => _removeRecipe(r),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openRecipe(Recipe r) async {
    final changed = await context.pushNamed<bool>(
      'recipeDetail',
      pathParameters: {'recipeId': r.id},
    );
    if (changed == true && mounted) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _removeRecipe(Recipe r) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _submittingId = r.id);
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      await svc.removeRecipeFromCollection(widget.collectionId, r.id);
      _changed = true;
      await _load();
      if (!mounted) return;
      AppToast.success(context, l10n.cookbookRecipeRemoved);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, friendlyErrorMessage(e, l10n));
    } finally {
      if (mounted) setState(() => _submittingId = null);
    }
  }

  Future<void> _openAddRecipes() async {
    final added = await context.pushNamed<bool>(
      'cookbookAddRecipes',
      pathParameters: {'collectionId': widget.collectionId},
      extra: _recipes.map((r) => r.id).toSet(),
    );
    if (added == true && mounted) {
      _changed = true;
      await _load();
    }
  }
}

class _RecipeRow extends StatelessWidget {
  final Recipe recipe;
  final bool isSubmitting;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  const _RecipeRow({
    required this.recipe,
    required this.isSubmitting,
    required this.onOpen,
    required this.onRemove,
  });

  String _metaLine(AppLocalizations l10n) {
    final parts = <String>[];
    final minutes = recipe.prepTime + recipe.cookTime;
    if (minutes > 0) parts.add(l10n.recipeMinLabel(minutes));
    if (recipe.servings > 0) parts.add(l10n.recipeServesLabel(recipe.servings));
    parts.add(recipe.isSharedWithHousehold
        ? l10n.recipeDetailSharedLabel
        : l10n.recipeDetailPrivateLabel);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.md,
      interactive: !isSubmitting,
      animated: true,
      onTap: isSubmitting ? null : onOpen,
      semanticLabel: l10n.recipeOpenRecipe(recipe.title),
      child: Row(
        children: [
          RecipeThumbnail(imageUrl: recipe.imageUrl, title: recipe.title),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  recipe.title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: MitlistSpacing.space1),
                Text(
                  _metaLine(l10n),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isSubmitting)
            SizedBox(
              width: MitlistSpacing.space5,
              height: MitlistSpacing.space5,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            )
          else
            IconButton(
              icon: const AppIcon(name: 'minusCircleOutline'),
              tooltip: l10n.cookbookRemoveRecipe,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

/// Square recipe thumbnail with the same placeholder and error treatment the
/// kitchen list uses, so a recipe looks the same wherever it is listed.
class RecipeThumbnail extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final double size;

  const RecipeThumbnail({
    super.key,
    required this.imageUrl,
    required this.title,
    this.size = MitlistSpacing.space16,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final url = imageUrl;

    Widget placeholder(String icon) => Container(
          width: size,
          height: size,
          color: colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: AppIcon(name: icon, color: colorScheme.onSurfaceVariant),
        );

    if (url == null || url.isEmpty) {
      return placeholder('restaurantOutline');
    }

    return Semantics(
      label: l10n.recipeImageSemantics(title),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth:
            (size * MediaQuery.devicePixelRatioOf(context) * 1.5).round(),
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : Container(
                width: size,
                height: size,
                color: colorScheme.surfaceContainerHighest,
              ),
        errorBuilder: (_, __, ___) => placeholder('imageNotSupportedOutline'),
      ),
    );
  }
}
