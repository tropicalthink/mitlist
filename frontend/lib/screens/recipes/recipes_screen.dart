import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/recipe_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../services/group_id_validator.dart';
import '../../sheets/recipe_add_to_list_sheet.dart';
import '../../sheets/recipe_creation_sheet.dart';
import '../../sheets/recipe_detail_sheet.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icons.dart';
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

enum _RecipeMenuAction { sortNewest, sortOldest, sortAz }



class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  static const int _pageLimit = 50;

  _ViewState _viewState = _ViewState.empty;
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadKitchen();
    });
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
    final created = await RecipeCreationSheet.show(context);
    if (created == true) {
      await _loadKitchen();
    }
  }

  Future<void> _openRecipeDetail(_Recipe recipe) async {
    await RecipeDetailSheet.show(
      context,
      title: recipe.title,
      description: recipe.description,
      visibilityLabel: recipe.isPublic ? 'Shared' : 'Private',
      prepTimeMinutes: recipe.prepTime,
      cookTimeMinutes: recipe.cookTime,
      servings: recipe.servings,
      updatedAt: recipe.updatedAt,
      author: recipe.author,
      ratingValue: recipe.ratingValue,
      ratingCount: recipe.ratingCount,
      sourceUrl: recipe.sourceUrl,
      videoUrl: recipe.videoUrl,
      nutritionJson: recipe.nutritionJson,
      equipmentJson: recipe.equipmentJson,
      imageUrl: recipe.imageUrl,
      tags: recipe.tags,
    );
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
    setState(() {
      _viewState = _ViewState.loading;
      _errorMessage = null;
      _loadMoreErrorMessage = null;
      _hasMore = true;
    });

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
          _errorMessage = 'Failed to load kitchen';
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
        _errorMessage = 'Failed to load kitchen';
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
        _loadMoreErrorMessage = 'Failed to load more recipes';
        _isLoadingMore = false;
      });
    }
  }

  Future<String?> _resolveGroupId() async {
    final groupService = await ref.read(groupServiceProviderAsync.future);
    final groups = await groupService.listGroups(limit: 1);
    final groupId = groups.isEmpty ? null : groups.first.id;
    return isValidGroupId(groupId) ? groupId : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MitlistAppBar(
        centerTitle: false,
        showStandardActions: false,
        leading: _showSearch
            ? IconButton(
                icon: const Icon(AppIcons.arrowLeft),
                tooltip: 'Back',
                onPressed: _clearSearch,
              )
            : null,
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Search kitchen',
                  hintText: 'Recipe, tag, ingredient',
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : const Text(
                'Kitchen',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (!_showSearch) ...[
            IconButton(
              icon: const Icon(AppIcons.calendarDays),
              tooltip: 'Meal plan',
              onPressed: () async {
                final router = GoRouter.of(context);
                final groupId = await _resolveGroupId();
                if (!mounted) return;
                if (groupId != null) {
                  router.pushNamed('mealPlan');
                }
              },
            ),
            IconButton(
              icon: const Icon(AppIcons.magnifyingGlass),
              tooltip: 'Search',
              onPressed: () => setState(() => _showSearch = true),
            ),
            PopupMenuButton<_RecipeMenuAction>(
              icon: const Icon(AppIcons.ellipsisVertical),
              tooltip: 'Options',
              onSelected: (action) {
                setState(() {
                  switch (action) {
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
                  enabled: false,
                  child: Text(
                    'Sort recipes',
                    style: MitlistTypography.labelXSmall().copyWith(
                      color: MitlistColors.textSecondary,
                    ),
                  ),
                ),
                CheckedPopupMenuItem(
                  value: _RecipeMenuAction.sortNewest,
                  checked: _sort == _SortOption.newest,
                  child: const Text('Newest'),
                ),
                CheckedPopupMenuItem(
                  value: _RecipeMenuAction.sortOldest,
                  checked: _sort == _SortOption.oldest,
                  child: const Text('Oldest'),
                ),
                CheckedPopupMenuItem(
                  value: _RecipeMenuAction.sortAz,
                  checked: _sort == _SortOption.az,
                  child: const Text('A-Z'),
                ),
              ],
            ),
          ] else ...[
            IconButton(
              icon: const Icon(AppIcons.xMark),
              tooltip: 'Clear search',
              onPressed: _clearSearch,
            ),
          ],
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'kitchen_create_recipe_fab',
        onPressed: _onAddRecipe,
        icon: const Icon(AppIcons.plus),
        label: const Text('ADD RECIPE'),
      ),
    );
  }

  Widget _buildBody() {
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
        _buildMealPlanSummary(),
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
            color: MitlistColors.primary500,
            onRefresh: _loadKitchen,
            child: visible.isEmpty
                ? _buildEmptyState()
                : _buildRecipeList(visible),
          ),
        ),
      ],
    );
  }

  Widget _buildMealPlanSummary() {
    return FutureBuilder<List<dynamic>>(
      future: _fetchWeekMealPlans(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final plans = snapshot.data ?? [];
        if (plans.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            MitlistSpacing.md,
            MitlistSpacing.sm,
            MitlistSpacing.md,
            0,
          ),
          child: AppCard(
            variant: AppCardVariant.filled,
            onTap: () async {
              final groupId = await _resolveGroupId();
              if (!mounted || groupId == null) return;
              if (context.mounted) {
                context.pushNamed('mealPlan');
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(MitlistSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This week',
                    style: MitlistTypography.labelXSmall(
                      color: MitlistColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: MitlistSpacing.sm),
                  ...plans.take(3).map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: MitlistSpacing.xs),
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.calendarDays,
                            size: 14,
                            color: MitlistColors.primary500,
                          ),
                          const SizedBox(width: MitlistSpacing.sm),
                          Expanded(
                            child: Text(
                              '${p['day']} ${p['slot']}: ${p['title']}',
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (plans.length > 3)
                    Text(
                      '+ ${plans.length - 3} more',
                      style: MitlistTypography.labelXSmall(
                        color: MitlistColors.textTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<Map<String, String>>> _fetchWeekMealPlans() async {
    try {
      final groupId = await _resolveGroupId();
      if (groupId == null) return [];

      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      final mealPlanService = await ref.read(mealPlanServiceProviderAsync.future);
      final plans = await mealPlanService.listMealPlans(
        groupId,
        from: weekStart.toIso8601String().split('T')[0],
        to: weekEnd.toIso8601String().split('T')[0],
      );

      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return plans.map((p) {
        final dayIndex = p.date.weekday - 1;
        return {
          'day': days[dayIndex.clamp(0, 6)],
          'slot': p.slot,
          'title': 'Meal',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Widget _buildChipBar() {
    const filters = <_FilterOption, String>{
      _FilterOption.all: 'All',
      _FilterOption.public: 'Shared',
      _FilterOption.private: 'Private',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.md,
        vertical: MitlistSpacing.sm,
      ),
      child: Row(
        children: filters.entries.map((entry) {
          final option = entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: MitlistSpacing.sm),
            child: AppChip(
              label: entry.value,
              selected: _filter == option,
              onSelected: (_) => setState(() => _filter = option),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildErrorState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          children: <Widget>[
            AppAlert(
              type: AppAlertType.error,
              message: _errorMessage ?? 'Something went wrong.',
            ),
            const SizedBox(height: MitlistSpacing.md),
            AppButton(
              text: 'Retry',
              onPressed: _loadKitchen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
                  icon: const Icon(Icons.restaurant_menu, size: 56),
                  title: 'Build your kitchen',
                  description:
                      'Import recipes, group cookbooks, plan meals, and turn the week into a shopping list.',
                  actions: <Widget>[
                    AppButton(
                      text: 'Add recipe',
                      icon: const Icon(AppIcons.plus),
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
          return const Center(child: CircularProgressIndicator());
        }

        final recipe = visible[index];
        return _RecipeCard(
          recipe: recipe,
          onTap: () => _openRecipeDetail(recipe),
          onAddToList: () => RecipeAddToListSheet.show(
            context,
            recipeId: recipe.id,
            recipeTitle: recipe.title,
            defaultServings: recipe.servings,
          ),
        );
      },
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
    final colorScheme = Theme.of(context).colorScheme;
    final hasImage = recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty;

    if (!hasImage) {
      return Container(
        width: MitlistSpacing.space20,
        height: MitlistSpacing.space20,
        color: colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.restaurant_outlined,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Image.network(
      recipe.imageUrl!,
      width: MitlistSpacing.space20,
      height: MitlistSpacing.space20,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: MitlistSpacing.space20,
          height: MitlistSpacing.space20,
          color: colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }

  String _metaLine() {
    final parts = <String>[];
    if (recipe.totalMinutes > 0) {
      parts.add('${recipe.totalMinutes} min');
    }
    if (recipe.servings > 0) {
      parts.add('Serves ${recipe.servings}');
    }
    if (recipe.ratingValue > 0) {
      parts.add('${recipe.ratingValue.toStringAsFixed(1)} ${recipe.ratingCount > 0 ? '(${recipe.ratingCount})' : ''}');
    }
    return parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tags = recipe.tags;

    return AppCard(
      interactive: true,
      animated: true,
      onTap: onTap,
      semanticLabel: 'Open recipe ${recipe.title}',
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
                  _metaLine(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: MitlistSpacing.space6),
                  Wrap(
                    spacing: MitlistSpacing.xs,
                    runSpacing: MitlistSpacing.xs,
                    children: [
                      for (final tag in tags) AppChip(label: tag),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Add to list',
            icon: const Icon(AppIcons.shoppingCart),
            onPressed: onAddToList,
          ),
        ],
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
          text: 'Retry',
          onPressed: onRetry,
        ),
      ],
    );
  }
}
