import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/list_models.dart';
import '../../models/recipe_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../services/group_id_validator.dart';
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

  int get totalMinutes => prepTime + cookTime;

  List<String> get tags {
    final marker = RegExp(r'(^|\n)Tags:\s*(.+)', caseSensitive: false)
        .firstMatch(description);
    if (marker == null) return const [];
    return marker
        .group(2)!
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .take(5)
        .toList();
  }

  List<_ShoppingIngredient> get ingredients {
    final lines = description.split('\n');
    final parsed = <_ShoppingIngredient>[];
    var inIngredients = false;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final lower = line.toLowerCase();
      if (lower.startsWith('ingredients')) {
        inIngredients = true;
        continue;
      }
      if (lower.startsWith('steps') ||
          lower.startsWith('nutrition') ||
          lower.startsWith('tags') ||
          lower.startsWith('source')) {
        inIngredients = false;
      }

      if (!inIngredients) continue;

      final clean = line.replaceFirst(RegExp(r'^[-*]\s*'), '');
      if (clean.isNotEmpty) parsed.add(_ShoppingIngredient.parse(clean));
    }

    if (parsed.isNotEmpty) return parsed;
    return [_ShoppingIngredient(name: title, section: 'Prepared food')];
  }

  String get sourceUrl {
    final marker =
        RegExp(r'(^|\n)Source:\s*(https?://\S+)', caseSensitive: false)
            .firstMatch(description);
    return marker?.group(2) ?? '';
  }
}

enum _ViewState { loading, error, empty, loaded }

enum _KitchenTab { recipes, planner, shopping, cookbooks }

enum _SortOption { newest, oldest, az }

enum _FilterOption { all, public, private }

enum _RecipeMenuAction { sortNewest, sortOldest, sortAz }

const List<String> _weekDays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _mealSlots = ['Breakfast', 'Lunch', 'Dinner', 'Snack'];

class _PlannedMeal {
  final String id;
  final String day;
  final String slot;
  final _Recipe recipe;
  final int servings;

  const _PlannedMeal({
    required this.id,
    required this.day,
    required this.slot,
    required this.recipe,
    required this.servings,
  });
}

class _ShoppingIngredient {
  final String name;
  final int quantity;
  final String unit;
  final String section;

  const _ShoppingIngredient({
    required this.name,
    this.quantity = 1,
    this.unit = '',
    this.section = 'Pantry',
  });

  static _ShoppingIngredient parse(String value) {
    final section = _sectionFor(value);
    final match = RegExp(r'^(\d+)\s*([A-Za-z]+)?\s+(.+)$').firstMatch(value);
    if (match == null) {
      return _ShoppingIngredient(name: value, section: section);
    }
    return _ShoppingIngredient(
      quantity: int.tryParse(match.group(1) ?? '') ?? 1,
      unit: match.group(2) ?? '',
      name: match.group(3)?.trim() ?? value,
      section: section,
    );
  }

  static String _sectionFor(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('tomato') ||
        lower.contains('onion') ||
        lower.contains('lettuce') ||
        lower.contains('carrot') ||
        lower.contains('pepper') ||
        lower.contains('fruit') ||
        lower.contains('apple') ||
        lower.contains('banana')) {
      return 'Produce';
    }
    if (lower.contains('milk') ||
        lower.contains('cheese') ||
        lower.contains('yogurt') ||
        lower.contains('cream')) {
      return 'Dairy';
    }
    if (lower.contains('chicken') ||
        lower.contains('beef') ||
        lower.contains('pork') ||
        lower.contains('fish') ||
        lower.contains('tofu')) {
      return 'Protein';
    }
    if (lower.contains('bread') ||
        lower.contains('flour') ||
        lower.contains('pasta') ||
        lower.contains('rice')) {
      return 'Bakery and grains';
    }
    return 'Pantry';
  }
}

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  static const int _pageLimit = 50;

  _ViewState _viewState = _ViewState.empty;
  _KitchenTab _tab = _KitchenTab.recipes;
  String? _errorMessage;
  String? _loadMoreErrorMessage;
  final List<_Recipe> _recipes = <_Recipe>[];
  final List<RecipeCollection> _collections = <RecipeCollection>[];
  final List<_PlannedMeal> _plan = <_PlannedMeal>[];
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isGeneratingList = false;
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

    if (_tab == _KitchenTab.recipes &&
        _scrollController.position.extentAfter < 400) {
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
        // Cookbook support is optional for older fakes and partially deployed APIs.
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

  void _planRecipe(_Recipe recipe, String day, String slot) {
    setState(() {
      _plan.add(
        _PlannedMeal(
          id: '${recipe.id}-$day-$slot-${DateTime.now().microsecondsSinceEpoch}',
          day: day,
          slot: slot,
          recipe: recipe,
          servings: max(1, recipe.servings),
        ),
      );
      _tab = _KitchenTab.planner;
    });
  }

  void _removePlannedMeal(String id) {
    setState(() {
      _plan.removeWhere((meal) => meal.id == id);
    });
  }

  Map<String, List<_ShoppingIngredient>> get _shoppingSections {
    final grouped = <String, Map<String, _ShoppingIngredient>>{};
    for (final meal in _plan) {
      final scale = meal.recipe.servings <= 0
          ? 1
          : max(1, (meal.servings / meal.recipe.servings).round());
      for (final ingredient in meal.recipe.ingredients) {
        final section = grouped.putIfAbsent(
            ingredient.section, () => <String, _ShoppingIngredient>{});
        final key = '${ingredient.name.toLowerCase()}|${ingredient.unit}';
        final existing = section[key];
        section[key] = _ShoppingIngredient(
          name: ingredient.name,
          quantity:
              (existing?.quantity ?? 0) + max(1, ingredient.quantity * scale),
          unit: ingredient.unit,
          section: ingredient.section,
        );
      }
    }

    final sections = <String, List<_ShoppingIngredient>>{};
    for (final entry in grouped.entries) {
      sections[entry.key] = entry.value.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    }
    return sections;
  }

  Future<String?> _resolveGroupId() async {
    final groupService = await ref.read(groupServiceProviderAsync.future);
    final groups = await groupService.listGroups(limit: 1);
    final groupId = groups.isEmpty ? null : groups.first.id;
    return isValidGroupId(groupId) ? groupId : null;
  }

  Future<void> _createShoppingList() async {
    if (_shoppingSections.isEmpty || _isGeneratingList) return;
    setState(() => _isGeneratingList = true);

    try {
      final groupId = await _resolveGroupId();
      if (groupId == null) {
        throw Exception('Create or join a household first');
      }

      final listService = await ref.read(listServiceProviderAsync.future);
      final list = await listService.createList(
        CreateListRequest(
          groupId: groupId,
          name: 'Meal plan shopping',
          type: 'shopping',
        ),
      );

      var position = 0;
      for (final section in _shoppingSections.entries) {
        await listService.createItem(
          list.id,
          CreateListItemRequest(name: section.key, quantity: 1, unit: ''),
        );
        position++;
        for (final ingredient in section.value) {
          await listService.createItem(
            list.id,
            CreateListItemRequest(
              name: ingredient.name,
              quantity: ingredient.quantity,
              unit: ingredient.unit,
            ),
          );
          position++;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shopping list created with $position lines')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingList = false);
    }
  }

  Future<void> _createCookbook() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New cookbook'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Cookbook name',
            hintText: 'Weeknight wins',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;

    try {
      final service = await ref.read(recipeServiceProviderAsync.future);
      await service.createCollection(CreateCollectionRequest(name: name));
      await _loadKitchen();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create cookbook: $e')),
      );
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
      floatingActionButton: _buildFab(),
    );
  }

  Widget? _buildFab() {
    return switch (_tab) {
      _KitchenTab.recipes => FloatingActionButton.extended(
          heroTag: 'kitchen_create_recipe_fab',
          onPressed: _onAddRecipe,
          icon: const Icon(AppIcons.plus),
          label: Text(
            'ADD RECIPE',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      _KitchenTab.shopping => FloatingActionButton.extended(
          heroTag: 'kitchen_shopping_fab',
          onPressed: _shoppingSections.isEmpty ? null : _createShoppingList,
          icon: const Icon(AppIcons.shoppingCart),
          label: Text(_isGeneratingList ? 'Creating' : 'Create list'),
        ),
      _KitchenTab.cookbooks => FloatingActionButton.extended(
          heroTag: 'kitchen_cookbook_fab',
          onPressed: _createCookbook,
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Cookbook'),
        ),
      _KitchenTab.planner => null,
    };
  }

  Widget _buildBody() {
    switch (_viewState) {
      case _ViewState.loading:
        return _buildLoadingScaffold();
      case _ViewState.error:
        return _buildErrorState();
      case _ViewState.empty:
        return _buildKitchenFrame(child: _buildEmptyState());
      case _ViewState.loaded:
        return _buildKitchenFrame(child: _buildTabBody());
    }
  }

  Widget _buildKitchenFrame({required Widget child}) {
    return Column(
      children: [
        _buildSummaryBand(),
        _buildTabBar(),
        Expanded(child: child),
      ],
    );
  }

  Widget _buildSummaryBand() {
    final planned = _plan.length;
    final ingredientCount = _shoppingSections.values.fold<int>(
      0,
      (sum, items) => sum + items.length,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MitlistSpacing.md,
        MitlistSpacing.md,
        MitlistSpacing.md,
        MitlistSpacing.sm,
      ),
      child: AppCard(
        variant: AppCardVariant.filled,
        tint: AppCardTint.primary,
        child: Row(
          children: [
            Expanded(
              child: _MetricBlock(
                label: 'Recipes',
                value: _recipes.length.toString(),
              ),
            ),
            Expanded(
              child: _MetricBlock(
                label: 'Planned',
                value: planned.toString(),
              ),
            ),
            Expanded(
              child: _MetricBlock(
                label: 'Groceries',
                value: ingredientCount.toString(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = <_KitchenTab, ({IconData icon, String label})>{
      _KitchenTab.recipes: (icon: Icons.restaurant_menu, label: 'Recipes'),
      _KitchenTab.planner: (icon: AppIcons.calendarDays, label: 'Plan'),
      _KitchenTab.shopping: (icon: AppIcons.shoppingCart, label: 'Shopping'),
      _KitchenTab.cookbooks: (icon: Icons.menu_book_outlined, label: 'Books'),
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
      child: Row(
        children: tabs.entries.map((entry) {
          final selected = _tab == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: MitlistSpacing.sm),
            child: ChoiceChip(
              selected: selected,
              avatar: Icon(entry.value.icon, size: MitlistSpacing.space4),
              label: Text(entry.value.label),
              onSelected: (_) => setState(() => _tab = entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLoadingScaffold() {
    return _buildKitchenFrame(child: const _LoadingListBody());
  }

  Widget _buildTabBody() {
    return switch (_tab) {
      _KitchenTab.recipes => _buildRecipesTab(),
      _KitchenTab.planner => _buildPlannerTab(),
      _KitchenTab.shopping => _buildShoppingTab(),
      _KitchenTab.cookbooks => _buildCookbooksTab(),
    };
  }

  Widget _buildRecipesTab() {
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
        _buildChipBar(),
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
        return LongPressDraggable<_Recipe>(
          data: recipe,
          feedback: Material(
            elevation: 6,
            child: SizedBox(
              width: 260,
              child: _RecipeCard(recipe: recipe, compact: true),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.45,
            child: _RecipeCard(recipe: recipe, compact: true),
          ),
          child: _RecipeCard(
            recipe: recipe,
            onTap: () => _openRecipeDetail(recipe),
            onPlan: () => _planRecipe(recipe, _weekDays.first, 'Dinner'),
          ),
        );
      },
    );
  }

  Widget _buildPlannerTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Drag recipes onto meals. Multiple recipes can sit in the same slot.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              AppButton(
                variant: AppButtonVariant.soft,
                text: 'Clear',
                onPressed: _plan.isEmpty ? null : () => setState(_plan.clear),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.md,
              0,
              MitlistSpacing.md,
              MitlistSpacing.md,
            ),
            child: Column(
              children: [
                for (final day in _weekDays)
                  Padding(
                    padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
                    child: _DayPlanner(
                      day: day,
                      meals: _plan.where((meal) => meal.day == day).toList(),
                      onAccept: (slot, recipe) =>
                          _planRecipe(recipe, day, slot),
                      onRemove: _removePlannedMeal,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShoppingTab() {
    final sections = _shoppingSections;
    if (sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          child: AppEmptyState(
            icon: const Icon(AppIcons.shoppingCart, size: 56),
            title: 'No shopping list yet',
            description:
                'Plan recipes first; ingredients are grouped into supermarket sections here.',
            actions: [
              AppButton(
                text: 'Open planner',
                icon: const Icon(AppIcons.calendarDays),
                onPressed: () => setState(() => _tab = _KitchenTab.planner),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      children: [
        AppCard(
          variant: AppCardVariant.filled,
          child: Row(
            children: [
              const Icon(AppIcons.shoppingCart),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: Text(
                  'Generated from ${_plan.length} planned meals',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              AppButton(
                size: AppButtonSize.sm,
                text: _isGeneratingList ? 'Creating' : 'Create list',
                isLoading: _isGeneratingList,
                onPressed: _isGeneratingList ? null : _createShoppingList,
              ),
            ],
          ),
        ),
        const SizedBox(height: MitlistSpacing.md),
        for (final section in sections.entries) ...[
          Text(
            section.key,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          AppCard(
            variant: AppCardVariant.outlined,
            child: Column(
              children: [
                for (var i = 0; i < section.value.length; i++) ...[
                  _ShoppingRow(ingredient: section.value[i]),
                  if (i != section.value.length - 1) const Divider(),
                ],
              ],
            ),
          ),
          const SizedBox(height: MitlistSpacing.md),
        ],
      ],
    );
  }

  Widget _buildCookbooksTab() {
    if (_collections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          child: AppEmptyState(
            icon: const Icon(Icons.menu_book_outlined, size: 56),
            title: 'No cookbooks yet',
            description:
                'Collect recipes by season, diet, household favorite, or occasion.',
            actions: [
              AppButton(
                text: 'Create cookbook',
                icon: const Icon(AppIcons.plus),
                onPressed: _createCookbook,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadKitchen,
      child: ListView.separated(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        itemCount: _collections.length,
        separatorBuilder: (_, __) => const SizedBox(height: MitlistSpacing.sm),
        itemBuilder: (context, index) {
          final cookbook = _collections[index];
          return AppCard(
            variant: AppCardVariant.outlined,
            child: Row(
              children: [
                const Icon(Icons.menu_book_outlined),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cookbook.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: MitlistSpacing.space1),
                      Text(
                        '${cookbook.recipeCount ?? 0} recipes',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(AppIcons.chevronRight),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

class _DayPlanner extends StatelessWidget {
  const _DayPlanner({
    required this.day,
    required this.meals,
    required this.onAccept,
    required this.onRemove,
  });

  final String day;
  final List<_PlannedMeal> meals;
  final void Function(String slot, _Recipe recipe) onAccept;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(day, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: MitlistSpacing.sm),
          for (final slot in _mealSlots)
            Padding(
              padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
              child: _MealDropSlot(
                label: slot,
                meals: meals.where((meal) => meal.slot == slot).toList(),
                onAccept: (recipe) => onAccept(slot, recipe),
                onRemove: onRemove,
              ),
            ),
        ],
      ),
    );
  }
}

class _MealDropSlot extends StatelessWidget {
  const _MealDropSlot({
    required this.label,
    required this.meals,
    required this.onAccept,
    required this.onRemove,
  });

  final String label;
  final List<_PlannedMeal> meals;
  final ValueChanged<_Recipe> onAccept;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_Recipe>(
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidates, rejected) {
        final active = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(MitlistSpacing.sm),
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerLow,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: MitlistTypography.labelXSmall().copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: MitlistSpacing.xs),
              if (meals.isEmpty)
                Text(
                  'Drop recipe',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                Wrap(
                  spacing: MitlistSpacing.sm,
                  runSpacing: MitlistSpacing.sm,
                  children: [
                    for (final meal in meals)
                      InputChip(
                        label: Text(meal.recipe.title),
                        avatar: const Icon(Icons.restaurant_menu, size: 18),
                        onDeleted: () => onRemove(meal.id),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ShoppingRow extends StatelessWidget {
  const _ShoppingRow({required this.ingredient});

  final _ShoppingIngredient ingredient;

  @override
  Widget build(BuildContext context) {
    final amount = ingredient.unit.isEmpty
        ? ingredient.quantity.toString()
        : '${ingredient.quantity} ${ingredient.unit}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(ingredient.name)),
          Text(
            amount,
            style: MitlistTypography.monoBody(color: MitlistColors.textPrimary),
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
  final VoidCallback? onPlan;
  final bool compact;

  const _RecipeCard({
    required this.recipe,
    this.onTap,
    this.onPlan,
    this.compact = false,
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
    parts.add('${recipe.ingredients.length} items');
    return parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tags = recipe.tags;

    return AppCard(
      interactive: !compact,
      animated: !compact,
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
                  maxLines: compact ? 2 : 1,
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
                if (!compact && tags.isNotEmpty) ...[
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
          if (!compact)
            IconButton(
              tooltip: 'Plan for dinner',
              icon: const Icon(AppIcons.calendarDays),
              onPressed: onPlan,
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
