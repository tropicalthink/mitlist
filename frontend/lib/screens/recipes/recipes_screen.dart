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
import '../../services/recipe_service.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_input.dart';
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

  /// Whether housemates can actually see this recipe.
  final bool isSharedWithHousehold;
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
    required this.isSharedWithHousehold,
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

enum _FilterOption { all, household, private }

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
  String _searchQuery = '';
  Timer? _searchTimer;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  _FilterOption _filter = _FilterOption.all;

  /// Tags offered by the server, most-used first, and the subset the user has
  /// selected. Selection is ANDed and filters server-side, so it narrows the
  /// whole library, not just the loaded pages.
  List<RecipeTagCount> _availableTags = const [];
  final Set<String> _selectedTags = <String>{};

  /// Discards responses that arrive after a newer recipes request started.
  int _recipesRequestSeq = 0;
  _SortOption _sort = _SortOption.newest;
  String? _groupId;

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
    _searchFocus.dispose();
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

  bool get _hasActiveFilters =>
      _filter != _FilterOption.all ||
      _selectedTags.isNotEmpty ||
      _searchQuery.trim().isNotEmpty;

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

  Future<void> _openCookbooks() async {
    unawaited(Haptics.light());
    await context.pushNamed('cookbooks');
    // Cookbooks may have been created or deleted; the tile count should not
    // lag behind what the user just did.
    if (mounted) await _reloadCollections();
  }

  Future<void> _openMealPlan() async {
    unawaited(Haptics.light());
    final groupId = await _resolveGroupId();
    if (!mounted || groupId == null) return;
    await context.pushNamed('mealPlan');
    if (mounted) ref.invalidate(weekMealPlansSummaryProvider(groupId));
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = value);
    });
  }

  List<_Recipe> get _filteredRecipes {
    var result = List<_Recipe>.from(_recipes);

    if (_filter != _FilterOption.all) {
      final wanted = _filter == _FilterOption.household;
      result = result.where((r) => r.isSharedWithHousehold == wanted).toList();
    }

    if (_selectedTags.isNotEmpty) {
      // Exact and ANDed, matching the server's `tags @>` semantics so rows
      // still in flight from an older query filter the same way the server
      // filters the new one.
      result = result
          .where((r) => _selectedTags.every(r.tags.contains))
          .toList();
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
        _recipesRequestSeq++;
        // Passing the household widens the list beyond the user's own recipes
        // to everything shared with it.
        final recipes = await service.listRecipes(
          limit: _pageLimit,
          offset: 0,
          groupId: groupId,
          tags: _selectedTags.toList(),
        );
        if (!mounted) return;
        setState(() {
          _recipes
            ..clear()
            ..addAll(recipes.map(_fromApi));
          _hasMore = recipes.length == _pageLimit;
          // With a tag filter active an empty page means "no matches", not an
          // empty kitchen; the loaded body renders that with a way out.
          _viewState = _recipes.isEmpty && _selectedTags.isEmpty
              ? _ViewState.empty
              : _ViewState.loaded;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _errorMessage = l10n.recipeFailedLoad;
          _viewState = _ViewState.error;
        });
      }

      await _reloadCollections(service: service);

      try {
        final tags = await service.listRecipeTags(groupId: groupId);
        if (!mounted) return;
        setState(() {
          _availableTags = tags;
          // Drop any selection the new tag set no longer offers, or the bar
          // would filter by a tag the user can no longer see or clear.
          _selectedTags
              .removeWhere((t) => !tags.any((available) => available.tag == t));
        });
      } catch (_) {
        // The tag bar is an enhancement; the list works without it.
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = l10n.recipeFailedLoad;
        _viewState = _ViewState.error;
      });
    }
  }

  Future<void> _reloadCollections({RecipeService? service}) async {
    try {
      final RecipeService svc =
          service ?? await ref.read(recipeServiceProviderAsync.future);
      final collections = await svc.listCollections(
        limit: 50,
        offset: 0,
        groupId: _groupId,
      );
      if (!mounted) return;
      setState(() {
        _collections
          ..clear()
          ..addAll(collections);
      });
    } catch (_) {
      // Cookbook support is optional.
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
        isSharedWithHousehold: api.isSharedWithHousehold,
        updatedAt: api.updatedAt,
        author: api.author,
        ratingValue: api.ratingValue,
        ratingCount: api.ratingCount,
        sourceUrl: api.sourceUrl,
        videoUrl: api.videoUrl,
        nutritionJson: api.nutritionJson,
        equipmentJson: api.equipmentJson,
        // All of them, not a prefix: the tag filter matches against these, and
        // the card already caps how many it draws.
        tags: api.tags,
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
      // Same scope and tag filter as the first page, or page two would
      // silently mix in rows the bar says are filtered out.
      final recipes = await service.listRecipes(
        limit: _pageLimit,
        offset: _recipes.length,
        groupId: _groupId,
        tags: _selectedTags.toList(),
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
      final valid = isValidGroupId(groupId) ? groupId : null;
      setState(() {
        _hasHousehold = groups.isNotEmpty;
        _groupId = valid;
      });
      return valid;
    } catch (_) {
      if (mounted) {
        setState(() => _hasHousehold = true);
      }
      return null;
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (!_selectedTags.remove(tag)) {
        _selectedTags.add(tag);
      }
    });
    unawaited(_reloadRecipes());
  }

  /// Refetches page one for the current tag selection, without the full-screen
  /// skeleton of [_loadKitchen]: the already-loaded rows stay up (locally
  /// filtered the same way) until the server answers.
  Future<void> _reloadRecipes() async {
    final l10n = AppLocalizations.of(context)!;
    final seq = ++_recipesRequestSeq;
    try {
      final service = await ref.read(recipeServiceProviderAsync.future);
      final recipes = await service.listRecipes(
        limit: _pageLimit,
        offset: 0,
        groupId: _groupId,
        tags: _selectedTags.toList(),
      );
      if (!mounted || seq != _recipesRequestSeq) return;
      setState(() {
        _recipes
          ..clear()
          ..addAll(recipes.map(_fromApi));
        _hasMore = recipes.length == _pageLimit;
        _loadMoreErrorMessage = null;
        _viewState = _recipes.isEmpty && _selectedTags.isEmpty
            ? _ViewState.empty
            : _ViewState.loaded;
      });
    } catch (_) {
      if (!mounted || seq != _recipesRequestSeq) return;
      setState(() => _loadMoreErrorMessage = l10n.recipeFailedLoad);
    }
  }

  void _resetFilters() {
    FocusScope.of(context).unfocus();
    _searchTimer?.cancel();
    final hadTags = _selectedTags.isNotEmpty;
    setState(() {
      _filter = _FilterOption.all;
      _selectedTags.clear();
      _searchQuery = '';
      _searchController.clear();
    });
    // Tags filtered server-side, so clearing them needs the wide list back.
    if (hadTags) unawaited(_reloadRecipes());
  }

  Future<void> _pickSort() async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showAppBottomSheet<_SortOption>(
      context: context,
      title: l10n.recipeSortLabel,
      body: _SortPicker(current: _sort),
    );
    if (picked != null && mounted) {
      setState(() => _sort = picked);
    }
  }

  String _sortLabel(AppLocalizations l10n, _SortOption option) =>
      switch (option) {
        _SortOption.newest => l10n.recipeSortNewest,
        _SortOption.oldest => l10n.recipeSortOldest,
        _SortOption.az => l10n.recipeSortAZ,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.listen(shellVisitedTabsProvider, (previous, next) {
      _activateTabIfNeeded();
    });
    return Scaffold(
      appBar: MitlistAppBar(
        centerTitle: false,
        title: Text(
          l10n.recipeAppBarTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
    final footerCount = _isLoadingMore || _loadMoreErrorMessage != null ? 1 : 0;

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: _loadKitchen,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                MitlistSpacing.md,
                MitlistSpacing.md,
                MitlistSpacing.md,
                MitlistSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _QuickActions(
                    collectionCount: _collections.length,
                    groupId: _groupId,
                    onCookbooks: _openCookbooks,
                    onMealPlan: _openMealPlan,
                  ),
                  const SizedBox(height: MitlistSpacing.md),
                  _buildSearchField(),
                  const SizedBox(height: MitlistSpacing.sm),
                  _buildFilterRow(),
                  if (_availableTags.isNotEmpty) ...[
                    const SizedBox(height: MitlistSpacing.sm),
                    _buildTagRow(),
                  ],
                  const SizedBox(height: MitlistSpacing.md),
                  _buildCountLine(visible.length),
                ],
              ),
            ),
          ),
          if (_loadMoreErrorMessage != null && visible.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  MitlistSpacing.md,
                  0,
                  MitlistSpacing.md,
                  MitlistSpacing.sm,
                ),
                child: AppAlert(
                  type: AppAlertType.error,
                  message: _loadMoreErrorMessage!,
                ),
              ),
            ),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildNoMatchState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                MitlistSpacing.md,
                0,
                MitlistSpacing.md,
                // Room for the floating "Add recipe" button.
                MitlistSpacing.xxl + MitlistSpacing.xl,
              ),
              sliver: SliverList.separated(
                itemCount: visible.length + footerCount,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: MitlistSpacing.sm),
                itemBuilder: (context, index) {
                  if (index >= visible.length) {
                    return _buildLoadMoreFooter();
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
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    final l10n = AppLocalizations.of(context)!;
    return AppInput(
      controller: _searchController,
      focusNode: _searchFocus,
      hint: l10n.recipeSearchHint,
      prefixIcon: const AppIcon(name: 'magnifyingGlass'),
      clearable: true,
      textInputAction: TextInputAction.search,
      onChanged: _onSearchChanged,
    );
  }

  /// Scope chips (all / shared / private) and the sort chip share a row: they
  /// are the two controls that change *which* recipes are listed and in what
  /// order, so they belong together and next to the list they act on.
  Widget _buildFilterRow() {
    final l10n = AppLocalizations.of(context)!;
    final filters = <_FilterOption, String>{
      _FilterOption.all: l10n.recipeFilterAll,
      _FilterOption.household: l10n.recipeFilterShared,
      _FilterOption.private: l10n.recipeFilterPrivate,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final entry in filters.entries) ...[
            AppChip(
              label: entry.value,
              selected: _filter == entry.key,
              onSelected: (_) => setState(() => _filter = entry.key),
            ),
            const SizedBox(width: MitlistSpacing.sm),
          ],
          AppChip(
            label: l10n.recipeSortChip(_sortLabel(l10n, _sort)),
            leading: const AppIcon(name: 'tune'),
            selected: false,
            onSelected: (_) => _pickSort(),
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(width: MitlistSpacing.sm),
            AppChip(
              label: l10n.recipeFiltersClear,
              leading: const AppIcon(name: 'xMark'),
              selected: false,
              onSelected: (_) => _resetFilters(),
            ),
          ],
        ],
      ),
    );
  }

  /// The tag filter: one horizontally scrolling line, never taller than a
  /// single chip row.
  ///
  /// Tags come from the server across the whole library, not just the loaded
  /// page, so "Desserts" finds every dessert rather than the ones that happen
  /// to be in the first 50 rows. The scraper already fills these from
  /// schema.org recipeCategory/recipeCuisine/keywords, so most clipped recipes
  /// arrive pre-tagged.
  Widget _buildTagRow() {
    // Selected tags lead the line so an active filter always has its chip in
    // reach to turn off; the rest keep the server's most-used-first order.
    final ordered = <RecipeTagCount>[
      ..._availableTags.where((t) => _selectedTags.contains(t.tag)),
      ..._availableTags.where((t) => !_selectedTags.contains(t.tag)),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < ordered.length; i++) ...[
            if (i > 0) const SizedBox(width: MitlistSpacing.sm),
            AppChip(
              label: '${ordered[i].tag} · ${ordered[i].count}',
              selected: _selectedTags.contains(ordered[i].tag),
              onSelected: (_) => _toggleTag(ordered[i].tag),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCountLine(int visibleCount) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final total = _recipes.length;
    final shared = _recipes.where((r) => r.isSharedWithHousehold).length;
    final countLabel = visibleCount == total
        ? l10n.recipeCountLabelAll(total)
        : l10n.recipeCountLabel(visibleCount, total);

    return Row(
      children: [
        Expanded(
          child: Text(
            countLabel,
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        Text(
          l10n.recipeSharedPrivate(shared, total - shared),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildLoadMoreFooter() {
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
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: _loadKitchen,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(MitlistSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _QuickActions(
                      collectionCount: _collections.length,
                      groupId: _groupId,
                      onCookbooks: _openCookbooks,
                      onMealPlan: _openMealPlan,
                    ),
                    const SizedBox(height: MitlistSpacing.lg),
                    AppEmptyState(
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
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoMatchState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
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
    );
  }
}

/// Sort options as a picker sheet rather than an overflow menu: the choice is
/// a view control and belongs where the view is, not behind three dots.
class _SortPicker extends StatelessWidget {
  final _SortOption current;

  const _SortPicker({required this.current});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final options = <(_SortOption, String)>[
      (_SortOption.newest, l10n.recipeSortNewest),
      (_SortOption.oldest, l10n.recipeSortOldest),
      (_SortOption.az, l10n.recipeSortAZ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (option, label) in options)
          Padding(
            padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
            child: AppCard(
              variant: AppCardVariant.outlined,
              padding: AppCardPadding.md,
              interactive: true,
              onTap: () => Navigator.of(context).pop(option),
              semanticLabel: label,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: option == current
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (option == current)
                    AppIcon(name: 'check', color: colorScheme.primary),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The two places the kitchen leads to besides a recipe. Tiles, not icon
/// buttons: cookbooks and the meal plan were the two most-missed features when
/// they hid behind an unlabelled grid icon.
class _QuickActions extends ConsumerWidget {
  final int collectionCount;
  final String? groupId;
  final VoidCallback onCookbooks;
  final VoidCallback onMealPlan;

  const _QuickActions({
    required this.collectionCount,
    required this.groupId,
    required this.onCookbooks,
    required this.onMealPlan,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mealPlansAsync = isValidGroupId(groupId)
        ? ref.watch(weekMealPlansSummaryProvider(groupId!))
        : null;
    final mealCount = mealPlansAsync?.whenOrNull(
          data: (plans) => plans.length,
        ) ??
        0;

    return Row(
      children: [
        Expanded(
          child: _QuickActionTile(
            icon: 'squares2x2',
            title: l10n.recipeQuickCookbooks,
            subtitle: l10n.recipeQuickCookbooksDesc(collectionCount),
            onTap: onCookbooks,
          ),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        Expanded(
          child: _QuickActionTile(
            icon: 'calendarDays',
            title: l10n.recipeQuickMealPlan,
            subtitle: l10n.recipeQuickMealPlanDesc(mealCount),
            onTap: groupId == null ? null : onMealPlan,
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.md,
      interactive: onTap != null,
      animated: true,
      onTap: onTap,
      semanticLabel: title,
      child: Row(
        children: [
          Container(
            width: MitlistSpacing.space10,
            height: MitlistSpacing.space10,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              border: Border.all(color: colorScheme.outline, width: 2),
            ),
            alignment: Alignment.center,
            child: AppIcon(
              name: icon,
              size: 20,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
    final parts = <String>[
      recipe.isSharedWithHousehold
          ? l10n.recipeDetailSharedLabel
          : l10n.recipeDetailPrivateLabel,
    ];
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
                Row(
                  children: [
                    AppIcon(
                      name: recipe.isSharedWithHousehold
                          ? 'userGroup'
                          : 'keyOutline',
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: MitlistSpacing.xs),
                    Expanded(
                      child: Text(
                        _metaLine(l10n),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
