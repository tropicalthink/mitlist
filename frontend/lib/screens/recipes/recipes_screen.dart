import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/recipe_provider.dart';
import '../../models/recipe_models.dart';
import '../../sheets/recipe_detail_sheet.dart';
import '../../sheets/recipe_creation_sheet.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/icons.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/mitlist_app_bar.dart';

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
  });
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
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMore = true;
  StreamSubscription<List<Recipe>>? _sub;

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
      _loadRecipes();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _sub?.cancel();
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
      await _loadRecipes();
    }
  }

  Future<void> _openRecipeDetail(_Recipe recipe) async {
    await RecipeDetailSheet.show(
      context,
      title: recipe.title,
      description: recipe.description,
      visibilityLabel: recipe.isPublic ? 'Public' : 'Private',
      prepTimeMinutes: recipe.prepTime,
      cookTimeMinutes: recipe.cookTime,
      servings: recipe.servings,
      updatedAt: recipe.updatedAt,
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
              r.description.toLowerCase().contains(q))
          .toList();
    }

    result.sort((a, b) {
      return switch (_sort) {
        _SortOption.newest => b.updatedAt.compareTo(a.updatedAt),
        _SortOption.oldest => a.updatedAt.compareTo(b.updatedAt),
        _SortOption.az => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      };
    });

    return result;
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _viewState = _ViewState.loading;
      _errorMessage = null;
      _loadMoreErrorMessage = null;
      _hasMore = true;
    });

    try {
      final repo = await ref.read(recipeRepositoryProvider.future);

      await _sub?.cancel();
      _sub = repo.watchRecipes().listen((apiRecipes) {
        if (!mounted) return;
        setState(() {
          _recipes
            ..clear()
            ..addAll(apiRecipes.map((api) => _Recipe(
                  id: api.id,
                  title: api.title,
                  description: api.description,
                  prepTime: api.prepTime,
                  cookTime: api.cookTime,
                  servings: api.servings,
                  imageUrl: api.imageUrl,
                  isPublic: api.isPublic,
                  updatedAt: api.updatedAt,
                )));
          _viewState = _recipes.isEmpty ? _ViewState.empty : _ViewState.loaded;
        });
      });

      final cached = await repo.getRecipesOnce();
      if (!mounted) return;
      final hadCache = cached.isNotEmpty;
      setState(() {
        _recipes
          ..clear()
          ..addAll(cached.map((api) => _Recipe(
                id: api.id,
                title: api.title,
                description: api.description,
                prepTime: api.prepTime,
                cookTime: api.cookTime,
                servings: api.servings,
                imageUrl: api.imageUrl,
                isPublic: api.isPublic,
                updatedAt: api.updatedAt,
              )));
        _viewState =
            _recipes.isEmpty ? _ViewState.loading : _ViewState.loaded;
      });

      try {
        final fetchedCount = await repo.refreshRecipes(
          limit: _pageLimit,
          offset: 0,
        );
        if (!mounted) return;
        setState(() {
          _hasMore = fetchedCount == _pageLimit;
          _viewState = _recipes.isEmpty ? _ViewState.empty : _ViewState.loaded;
        });
      } catch (e) {
        if (!mounted) return;
        if (!hadCache) {
          setState(() {
            _errorMessage = 'Failed to load recipes';
            _viewState = _ViewState.error;
          });
        } else {
          setState(() {
            _viewState = _recipes.isEmpty ? _ViewState.empty : _ViewState.loaded;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load recipes';
        _viewState = _ViewState.error;
      });
    }
  }

  Future<void> _loadMoreRecipes() async {
    if (_isLoadingMore || !_hasMore || _viewState != _ViewState.loaded) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
      _loadMoreErrorMessage = null;
    });

    try {
      final repo = await ref.read(recipeRepositoryProvider.future);
      final fetchedCount = await repo.refreshRecipes(
        limit: _pageLimit,
        offset: _recipes.length,
      );
      if (!mounted) return;
      setState(() {
        _hasMore = fetchedCount == _pageLimit;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadMoreErrorMessage = 'Failed to load more recipes';
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MitlistAppBar(
        centerTitle: false,
        leading: _showSearch
            ? IconButton(
                icon: const Icon(AppIcons.arrowLeft),
                tooltip: 'Back',
                onPressed: _clearSearch,
              )
            : IconButton(
                icon: const Icon(AppIcons.userGroup),
                tooltip: 'To households',
                onPressed: () => context.goNamed('groupsList'),
              ),
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Search recipes',
                  hintText: 'Title, ingredient, link…',
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : const Text(
                'Recipes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        actions: [
          if (!_showSearch) ...[
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
                    'Sort',
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
                  child: const Text('A–Z'),
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
        heroTag: 'recipes_create_fab',
        onPressed: _onAddRecipe,
        icon: const Icon(AppIcons.plus),
        label: Text(
          'ADD RECIPE',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_viewState) {
      case _ViewState.loading:
        return _buildLoadingScaffold();
      case _ViewState.error:
        return _buildErrorState();
      case _ViewState.empty:
        return _buildEmptyState();
      case _ViewState.loaded:
        return _buildLoadedScaffold();
    }
  }

  Widget _buildLoadingScaffold() {
    return Column(
      children: [
        _buildQuickAddRow(),
        _buildChipBar(),
        const Expanded(child: _LoadingListBody()),
      ],
    );
  }

  Widget _buildLoadedScaffold() {
    final visible = _filteredRecipes;
    return Column(
      children: [
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
        _buildQuickAddRow(),
        _buildChipBar(),
        Expanded(
          child: RefreshIndicator(
            color: MitlistColors.primary500,
            onRefresh: _loadRecipes,
            child: visible.isEmpty ? _buildEmptyState() : _buildRecipeList(visible),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAddRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MitlistSpacing.md,
        MitlistSpacing.md,
        MitlistSpacing.md,
        0,
      ),
      child: AppCard(
        interactive: true,
        onTap: _onAddRecipe,
        variant: AppCardVariant.filled,
        tint: AppCardTint.primary,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              AppIcons.plus,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: MitlistSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add a recipe',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: MitlistSpacing.space1),
                  Text(
                    'Save links, jot ingredients, or keep staples here.',
                    style: MitlistTypography.labelXSmall().copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipBar() {
    const filters = <_FilterOption, String>{
      _FilterOption.all: 'All',
      _FilterOption.public: 'Public',
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
          final label = entry.value;
          return Padding(
            padding: const EdgeInsets.only(right: MitlistSpacing.sm),
            child: AppChip(
              label: label,
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
              onPressed: _loadRecipes,
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
                  icon: const AppIcon(
                    name: 'clipboardDocumentList',
                    size: 56,
                  ),
                  title: 'No recipes yet',
                  description:
                      'Save links, jot ingredients, or keep your household staples here.',
                  actions: <Widget>[
                    AppButton(
                      text: 'Add recipe',
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
      itemCount:
          visible.length + (_isLoadingMore || _loadMoreErrorMessage != null ? 1 : 0),
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

        final _Recipe recipe = visible[index];
        return _RecipeCard(
          recipe: recipe,
          onTap: () => _openRecipeDetail(recipe),
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
            AppSkeleton(
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
                  AppSkeleton(
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

  const _RecipeCard({
    required this.recipe,
    this.onTap,
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(0),
      child: Image.network(
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
      ),
    );
  }

  String _metaLine() {
    final int totalMinutes = recipe.prepTime + recipe.cookTime;
    final List<String> parts = <String>[];
    if (totalMinutes > 0) {
      parts.add('$totalMinutes min');
    }
    if (recipe.servings > 0) {
      parts.add('Serves ${recipe.servings}');
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final meta = _metaLine();

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
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: MitlistSpacing.space6),
                  Text(
                    meta,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (recipe.description.trim().isNotEmpty) ...[
                  const SizedBox(height: MitlistSpacing.space6),
                  Text(
                    recipe.description.trim(),
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (recipe.isPublic) ...[
                  const SizedBox(height: MitlistSpacing.space6),
                  const AppChip(label: 'Public'),
                ],
              ],
            ),
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
    return AppCard(
      variant: AppCardVariant.outlined,
      interactive: true,
      semanticLabel: 'Retry loading more recipes',
      onTap: onRetry,
      child: Column(
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
      ),
    );
  }
}
