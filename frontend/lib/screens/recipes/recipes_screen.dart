import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/recipe_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../router.dart' show BottomNavScaffold, currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../sheets/recipe_add_to_list_sheet.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../theme/typography.dart';
import '../../utils/shell_tab_load.dart';
import '../../utils/active_group_context.dart';
import '../../utils/haptics.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/list_entrance.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _Recipe {
  final String id;
  final String title;
  final String description;
  final int prepTime;
  final int cookTime;
  final int servings;
  final String? imageUrl;
  final bool isPublic;
  final DateTime updatedAt;
  final String author;
  final double ratingValue;
  final int ratingCount;
  final String sourceUrl;
  final String videoUrl;
  final String nutritionJson;
  final String equipmentJson;
  final List<String> tags;

  const _Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.prepTime,
    required this.cookTime,
    required this.servings,
    this.imageUrl,
    required this.isPublic,
    required this.updatedAt,
    this.author = '',
    this.ratingValue = 0,
    this.ratingCount = 0,
    this.sourceUrl = '',
    this.videoUrl = '',
    this.nutritionJson = '',
    this.equipmentJson = '',
    this.tags = const [],
  });

  int get totalMinutes => prepTime + cookTime;
}

enum _ViewState { loading, error, empty, loaded }

enum _SortOption { newest, oldest, az }

enum _FilterOption { all, public, private }

enum _RecipeMenuAction { mealPlan, sortNewest, sortOldest, sortAz }

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  static const int _pageLimit = 50;

  bool _hasHousehold = true;
  _ViewState _viewState = _ViewState.loading;
  String? _errorMessage;
  String? _loadMoreErrorMessage;
  final List<_Recipe> _recipes = <_Recipe>[];
  final List<RecipeCollection> _collections = <RecipeCollection>[];
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _showSearch = false;
  String _searchQuery = '';
  Timer? _searchTimer;
  final TextEditingController _searchController = TextEditingController();
  _FilterOption _filter = _FilterOption.all;
  _SortOption _sort = _SortOption.newest;

  bool _tabLoadStarted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _activateTabIfNeeded());
  }

  void _activateTabIfNeeded() {
    if (_tabLoadStarted || !mounted) return;
    final insideShell =
        context.findAncestorWidgetOfExactType<BottomNavScaffold>() != null;
    if (insideShell && !shouldActivateShellTab(ref, kitchenShellTabIndex)) {
      return;
    }
    _tabLoadStarted = true;
    _loadKitchen();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) {
      return;
    }

    if (_scrollController.position.extentAfter < 400) {
      _loadMoreRecipes();
    }
  }

  Future<void> _onAddRecipe() async {
    unawaited(Haptics.light());
    final created = await context.pushNamed<bool>('recipeCreate');
    if (created == true) {
      await _loadKitchen();
    }
  }

  Future<void> _openRecipeDetail(_Recipe recipe) async {
    unawaited(Haptics.light());
    final changed = await context.pushNamed<bool>(
      'recipeDetail',
      pathParameters: {'recipeId': recipe.id},
    );
    if (changed == true && mounted) {
      await _loadKitchen();
    }
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = value);
    });
  }

  void _clearSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showSearch = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  List<_Recipe> get _filteredRecipes {
    var result = List<_Recipe>.from(_recipes);

    if (_filter != _FilterOption.all) {
      final wanted = _filter == _FilterOption.public;
      result = result.where((r) => r.isPublic == wanted).toList();
    }

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result
          .where((r) =>
              r.title.toLowerCase().contains(q) ||
              r.description.toLowerCase().contains(q) ||
              r.tags.any((tag) => tag.toLowerCase().contains(q)))
          .toList();
    }

    result.sort((a, b) {
      return switch (_sort) {
        _SortOption.newest => b.updatedAt.compareTo(a.updatedAt),
        _SortOption.oldest => a.updatedAt.compareTo(b.updatedAt),
        _SortOption.az =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      };
    });

    return result;
  }

  Future<void> _loadKitchen() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _viewState = _ViewState.loading;
      _errorMessage = null;
      _loadMoreErrorMessage = null;
      _hasMore = true;
    });

    final groupId = await _resolveGroupId();
    if (groupId != null) {
      ref.invalidate(weekMealPlansSummaryProvider(groupId));
    }

    try {
      final service = await ref.read(recipeServiceProviderAsync.future);

      try {
        final recipes = await service.listRecipes(limit: _pageLimit, offset: 0);
        if (!mounted) return;
        setState(() {
          _recipes
            ..clear()
            ..addAll(recipes.map(_fromApi));
          _hasMore = recipes.length == _pageLimit;
          _viewState = _recipes.isEmpty ? _ViewState.empty : _ViewState.loaded;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _errorMessage = l10n.recipeFailedLoad;
          _viewState = _ViewState.error;
        });
      }

      try {
        final collections = await service.listCollections(limit: 50, offset: 0);
        if (!mounted) return;
        setState(() {
          _collections
            ..clear()
            ..addAll(collections);
        });
      } catch (_) {
        // Cookbook support is optional.
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = l10n.recipeFailedLoad;
        _viewState = _ViewState.error;
      });
    }
  }

  _Recipe _fromApi(Recipe api) => _Recipe(
        id: api.id,
        title: api.title,
        description: api.description,
        prepTime: api.prepTime,
        cookTime: api.cookTime,
        servings: api.servings,
        imageUrl: api.imageUrl,
        isPublic: api.isPublic,
        updatedAt: api.updatedAt,
        author: api.author,
        ratingValue: api.ratingValue,
        ratingCount: api.ratingCount,
        sourceUrl: api.sourceUrl,
        videoUrl: api.videoUrl,
        nutritionJson: api.nutritionJson,
        equipmentJson: api.equipmentJson,
        tags: api.tags.take(5).toList(),
      );

  Future<void> _loadMoreRecipes() async {
    if (_isLoadingMore || !_hasMore || _viewState != _ViewState.loaded) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isLoadingMore = true;
      _loadMoreErrorMessage = null;
    });

    try {
      final service = await ref.read(recipeServiceProviderAsync.future);
      final recipes = await service.listRecipes(
        limit: _pageLimit,
        offset: _recipes.length,
      );
      if (!mounted) return;
      setState(() {
        _recipes.addAll(recipes.map(_fromApi));
        _hasMore = recipes.length == _pageLimit;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadMoreErrorMessage = l10n.recipeFailedMore;
        _isLoadingMore = false;
      });
    }
  }

  Future<String?> _resolveGroupId() async {
    try {
      final groups = await ref.read(cachedGroupsProvider.future);
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (!mounted) return null;
      setState(() => _hasHousehold = groups.isNotEmpty);
      return isValidGroupId(groupId) ? groupId : null;
    } catch (_) {
      if (mounted) {
        setState(() => _hasHousehold = true);
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen(shellVisitedTabsProvider, (previous, next) {
      _activateTabIfNeeded();
    });
    return Scaffold(
      appBar: MitlistAppBar(
        centerTitle: false,
        leading: _showSearch
            ? IconButton(
                icon: const AppIcon(name: 'arrowLeft'),
                tooltip: l10n.commonBack,
                onPressed: _clearSearch,
              )
            : null,
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.recipeSearchLabel,
                  hintText: l10n.recipeSearchHint,
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : Text(
                l10n.recipeAppBarTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (!_showSearch) ...[
            IconButton(
              icon: const AppIcon(name: 'magnifyingGlass'),
              tooltip: l10n.recipeSearchTooltip,
              onPressed: () => setState(() => _showSearch = true),
            ),
            PopupMenuButton<_RecipeMenuAction>(
              icon: const AppIcon(name: 'ellipsisVertical'),
              tooltip: l10n.commonOptions,
              onSelected: (action) async {
                if (action == _RecipeMenuAction.mealPlan) {
                  final router = GoRouter.of(context);
                  final groupId = await _resolveGroupId();
                  if (!mounted) return;
                  if (groupId != null) {
                    unawaited(router.pushNamed('mealPlan'));
                  }
                  return;
                }
                setState(() {
                  switch (action) {
                    case _RecipeMenuAction.mealPlan:
                      break;
                    case _RecipeMenuAction.sortNewest:
                      _sort = _SortOption.newest;
                      break;
                    case _RecipeMenuAction.sortOldest:
                      _sort = _SortOption.oldest;
                      break;
                    case _RecipeMenuAction.sortAz:
                      _sort = _SortOption.az;
                      break;
                  }
                });
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _RecipeMenuAction.mealPlan,
                  child: Row(
                    children: [
                      AppIcon(
                          name: 'calendarDays',
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface),
                      const SizedBox(width: MitlistSpacing.sm),
                      Text(l10n.recipeMealPlanTooltip),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    l10n.recipeSortLabel,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                CheckedPopupMenuItem(
                  value: _RecipeMenuAction.sortNewest,
                  checked: _sort == _SortOption.newest,
                  child: Text(l10n.recipeSortNewest),
                ),
                CheckedPopupMenuItem(
                  value: _RecipeMenuAction.sortOldest,
                  checked: _sort == _SortOption.oldest,
                  child: Text(l10n.recipeSortOldest),
                ),
                CheckedPopupMenuItem(
                  value: _RecipeMenuAction.sortAz,
                  checked: _sort == _SortOption.az,
                  child: Text(l10n.recipeSortAZ),
                ),
              ],
            ),
          ] else ...[
            IconButton(
              icon: const AppIcon(name: 'xMark'),
              tooltip: l10n.commonClearSearch,
              onPressed: _clearSearch,
            ),
          ],
        ],
      ),
      body: _buildBody(),
      floatingActionButton: AppButton(
        size: AppButtonSize.lg,
        icon: const AppIcon(name: 'plus'),
        text: l10n.recipeAddRecipe,
        onPressed: _onAddRecipe,
        tooltip: l10n.recipeAddRecipe,
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (!_hasHousehold) {
      return Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/House.lottie',
          icon: AppIcon(name: 'home', size: 56),
          title: l10n.commonNoHousehold,
          description: l10n.commonCreateJoinHousehold,
          actions: [
            AppButton(
              text: l10n.commonGoToHouseholds,
              onPressed: () => context.goNamed('groupsList'),
            ),
          ],
        ),
      );
    }
    switch (_viewState) {
      case _ViewState.loading:
        return const _LoadingListBody();
      case _ViewState.error:
        return _buildErrorState();
      case _ViewState.empty:
        return _buildEmptyState();
      case _ViewState.loaded:
        return _buildLoadedBody();
    }
  }

  Widget _buildLoadedBody() {
    final visible = _filteredRecipes;
    return Column(
      children: [
        _KitchenHeader(
          recipeCount: _recipes.length,
          visibleCount: visible.length,
          sharedCount: _recipes.where((r) => r.isPublic).length,
          collectionCount: _collections.length,
        ),
        _buildChipBar(),
        if (_loadMoreErrorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.md,
              MitlistSpacing.md,
              MitlistSpacing.md,
              0,
            ),
            child: AppAlert(
              type: AppAlertType.error,
              message: _loadMoreErrorMessage!,
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            color: Theme.of(context).colorScheme.primary,
            onRefresh: _loadKitchen,
            child: visible.isEmpty
                ? _buildNoMatchState()
                : _buildRecipeList(visible),
          ),
        ),
      ],
    );
  }

  Widget _buildChipBar() {
    final l10n = AppLocalizations.of(context)!;
    final filters = <_FilterOption, String Function()>{
      _FilterOption.all: () => l10n.recipeFilterAll,
      _FilterOption.public: () => l10n.recipeFilterShared,
      _FilterOption.private: () => l10n.recipeFilterPrivate,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        MitlistSpacing.md,
        0,
        MitlistSpacing.md,
        MitlistSpacing.sm,
      ),
      child: Row(
        children: filters.entries.map((entry) {
          final option = entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: MitlistSpacing.sm),
            child: AppChip(
              label: entry.value(),
              selected: _filter == option,
              onSelected: (_) => setState(() => _filter = option),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildErrorState() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          children: <Widget>[
            AppAlert(
              type: AppAlertType.error,
              message: _errorMessage ?? l10n.commonSomethingWentWrong,
            ),
            const SizedBox(height: MitlistSpacing.md),
            AppButton(
              text: l10n.commonRetry,
              onPressed: _loadKitchen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(MitlistSpacing.md),
                child: AppEmptyState(
                  lottieAsset: 'assets/animations/lottie/Recipes.lottie',
                  icon: const AppIcon(name: 'restaurantMenu', size: 56),
                  title: l10n.recipeBuildKitchen,
                  description: l10n.recipeBuildKitchenDesc,
                  actions: <Widget>[
                    AppButton(
                      text: l10n.recipeAddRecipe,
                      icon: const AppIcon(name: 'plus'),
                      onPressed: _onAddRecipe,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoMatchState() {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(MitlistSpacing.md),
                child: AppEmptyState(
                  paddingPreset: AppEmptyStatePadding.md,
                  icon: const AppIcon(name: 'magnifyingGlass', size: 56),
                  title: l10n.recipeNoMatchTitle,
                  description: l10n.recipeNoMatchDesc,
                  actions: <Widget>[
                    AppButton(
                      text: l10n.recipeShowAllRecipes,
                      variant: AppButtonVariant.outline,
                      onPressed: _resetFilters,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _resetFilters() {
    FocusScope.of(context).unfocus();
    setState(() {
      _filter = _FilterOption.all;
      _searchQuery = '';
      _searchController.clear();
      _showSearch = false;
    });
  }

  Widget _buildRecipeList(List<_Recipe> visible) {
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MitlistSpacing.md),
      itemCount: visible.length +
          (_isLoadingMore || _loadMoreErrorMessage != null ? 1 : 0),
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: MitlistSpacing.sm),
      itemBuilder: (BuildContext context, int index) {
        if (index >= visible.length) {
          if (_loadMoreErrorMessage != null) {
            return _LoadMoreErrorTile(
              message: _loadMoreErrorMessage!,
              onRetry: _loadMoreRecipes,
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.md),
            child: Center(
              child: SizedBox(
                width: MitlistSpacing.lg,
                height: MitlistSpacing.lg,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          );
        }

        final recipe = visible[index];
        return ListEntrance(
          index: index,
          child: _RecipeCard(
            recipe: recipe,
            onTap: () => _openRecipeDetail(recipe),
            onAddToList: () => RecipeAddToListSheet.show(
              context,
              recipeId: recipe.id,
              recipeTitle: recipe.title,
              defaultServings: recipe.servings,
            ),
          ),
        );
      },
    );
  }
}

class _KitchenHeader extends ConsumerWidget {
  final int recipeCount;
  final int visibleCount;
  final int sharedCount;
  final int collectionCount;

  const _KitchenHeader({
    required this.recipeCount,
    required this.visibleCount,
    required this.sharedCount,
    required this.collectionCount,
  });

  Future<void> _openMealPlan(BuildContext context, WidgetRef ref) async {
    unawaited(Haptics.light());
    final groups = ref.read(cachedGroupsProvider).valueOrNull;
    if (groups == null) return;
    final groupId = resolveActiveGroupId(
      groups,
      ref.read(currentGroupIdProvider),
    );
    if (!context.mounted || !isValidGroupId(groupId)) return;
    await context.pushNamed('mealPlan');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final privateCount = recipeCount - sharedCount;

    final countLabel = visibleCount == recipeCount
        ? l10n.recipeCountLabelAll(recipeCount)
        : l10n.recipeCountLabel(visibleCount, recipeCount);

    final groups = ref.watch(cachedGroupsProvider).valueOrNull;
    final groupId = groups == null
        ? null
        : resolveActiveGroupId(groups, ref.watch(currentGroupIdProvider));
    final mealPlansAsync = isValidGroupId(groupId)
        ? ref.watch(weekMealPlansSummaryProvider(groupId!))
        : null;
    final mealPlanCount = mealPlansAsync?.whenOrNull(
      data: (plans) => plans.isEmpty ? null : plans.length,
    );

    final detailLabel = l10n.recipeSharedPrivate(sharedCount, privateCount) +
        (collectionCount > 0
            ? l10n.recipeCookbooksLabel(collectionCount)
            : '') +
        (mealPlanCount != null
            ? ' · ${l10n.recipeMealsPlanned(mealPlanCount)}'
            : '');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MitlistSpacing.md,
        MitlistSpacing.md,
        MitlistSpacing.md,
        MitlistSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  countLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  detailLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: MitlistSpacing.sm),
          AppButton(
            text: l10n.recipePlanButton,
            size: AppButtonSize.sm,
            variant: AppButtonVariant.outline,
            icon: const AppIcon(name: 'calendarDays', size: 16),
            tooltip: l10n.recipeMealPlanTooltip,
            onPressed: () => _openMealPlan(context, ref),
          ),
        ],
      ),
    );
  }
}

class _LoadingListBody extends StatelessWidget {
  const _LoadingListBody();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MitlistSpacing.md),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: MitlistSpacing.sm),
      itemBuilder: (_, __) => AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AppSkeleton(
              width: MitlistSpacing.space20,
              height: MitlistSpacing.space20,
            ),
            const SizedBox(width: MitlistSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const AppSkeleton(
                    width: double.infinity,
                    height: MitlistSpacing.space5,
                  ),
                  const SizedBox(height: MitlistSpacing.space6),
                  const AppSkeleton(
                    width: MitlistSpacing.space16,
                    height: MitlistSpacing.space4,
                  ),
                  const SizedBox(height: MitlistSpacing.space6),
                  const AppSkeleton(
                    width: double.infinity,
                    height: MitlistSpacing.space4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final _Recipe recipe;
  final VoidCallback? onTap;
  final VoidCallback? onAddToList;

  const _RecipeCard({
    required this.recipe,
    this.onTap,
    this.onAddToList,
  });

  Widget _thumbnail(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty;

    if (!hasImage) {
      return Container(
        width: MitlistSpacing.space20,
        height: MitlistSpacing.space20,
        color: colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: AppIcon(
          name: 'restaurantOutline',
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Semantics(
      label: l10n.recipeImageSemantics(recipe.title),
      child: Image.network(
        recipe.imageUrl!,
        width: MitlistSpacing.space20,
        height: MitlistSpacing.space20,
        fit: BoxFit.cover,
        cacheWidth: (MitlistSpacing.space20 *
                MediaQuery.devicePixelRatioOf(context) *
                1.5)
            .round(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: MitlistSpacing.space20,
            height: MitlistSpacing.space20,
            color: colorScheme.surfaceContainerHighest,
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: MitlistSpacing.space20,
            height: MitlistSpacing.space20,
            color: colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: AppIcon(
              name: 'imageNotSupportedOutline',
              color: colorScheme.onSurfaceVariant,
            ),
          );
        },
      ),
    );
  }

  String _metaLine(AppLocalizations l10n) {
    final parts = <String>[];
    if (recipe.totalMinutes > 0) {
      parts.add(l10n.recipeMinLabel(recipe.totalMinutes));
    }
    if (recipe.servings > 0) {
      parts.add(l10n.recipeServesLabel(recipe.servings));
    }
    if (recipe.ratingValue > 0 && recipe.ratingCount > 0) {
      parts.add(l10n.recipeRatingLabel(
          recipe.ratingValue.toStringAsFixed(1), recipe.ratingCount));
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final tags = recipe.tags;

    return AppCard(
      interactive: true,
      animated: true,
      onTap: onTap,
      semanticLabel: l10n.recipeOpenRecipe(recipe.title),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _thumbnail(context),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  recipe.title,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: MitlistSpacing.space6),
                Text(
                  _metaLine(l10n),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: MitlistSpacing.xs),
                  _RecipeCardTags(tags: tags),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.recipeAddToList,
            icon: const AppIcon(name: 'shoppingCart'),
            onPressed: onAddToList,
          ),
        ],
      ),
    );
  }
}

class _RecipeCardTags extends StatelessWidget {
  static const int _maxVisible = 2;

  final List<String> tags;

  const _RecipeCardTags({required this.tags});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visible = tags.take(_maxVisible).toList();
    final overflow = tags.length - visible.length;

    return Row(
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(width: MitlistSpacing.xs),
          Flexible(
            child: _CompactTagChip(label: visible[i]),
          ),
        ],
        if (overflow > 0) ...[
          const SizedBox(width: MitlistSpacing.xs),
          Text(
            '+$overflow',
            style: MitlistTypography.labelXSmall(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactTagChip extends StatelessWidget {
  final String label;

  const _CompactTagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outline, width: 1),
        borderRadius:
            const BorderRadius.all(Radius.circular(MitlistTheme.radiusSm)),
      ),
      child: Text(
        label,
        style: MitlistTypography.labelXSmall(
          color: colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _LoadMoreErrorTile extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadMoreErrorTile({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppAlert(
          type: AppAlertType.error,
          message: message,
        ),
        const SizedBox(height: MitlistSpacing.sm),
        AppButton(
          text: l10n.commonRetry,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
