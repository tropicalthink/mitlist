import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/recipe_provider.dart';
import '../../sheets/recipe_detail_sheet.dart';
import '../../sheets/recipe_creation_sheet.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/chip.dart';
import '../../widgets/empty_state.dart';
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

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  static const int _pageLimit = 50;

  _ViewState _viewState = _ViewState.empty;
  String? _errorMessage;
  String? _loadMoreErrorMessage;
  final List<_Recipe> _recipes = <_Recipe>[];
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMore = true;

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

  Future<void> _loadRecipes() async {
    setState(() {
      _viewState = _ViewState.loading;
      _errorMessage = null;
      _loadMoreErrorMessage = null;
      _hasMore = true;
    });

    try {
      final recipeService = await ref.read(recipeServiceProviderAsync.future);
      final apiRecipes = await recipeService.listRecipes(
        limit: _pageLimit,
        offset: 0,
      );
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
        _hasMore = apiRecipes.length == _pageLimit;
        _viewState = apiRecipes.isEmpty ? _ViewState.empty : _ViewState.loaded;
      });
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
      final recipeService = await ref.read(recipeServiceProviderAsync.future);
      final apiRecipes = await recipeService.listRecipes(
        limit: _pageLimit,
        offset: _recipes.length,
      );
      if (!mounted) return;
      setState(() {
        _recipes.addAll(apiRecipes.map((api) => _Recipe(
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
        _hasMore = apiRecipes.length == _pageLimit;
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
      appBar: MitlistAppBar.titleText('Recipes'),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'recipes_create_fab',
        onPressed: _onAddRecipe,
        icon: const AppIcon(name: 'plus'),
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
        return _buildSkeletonGrid();
      case _ViewState.error:
        return _buildErrorState();
      case _ViewState.empty:
        return _buildEmptyState();
      case _ViewState.loaded:
        return _buildRecipeGrid();
    }
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: MitlistSpacing.md,
        crossAxisSpacing: MitlistSpacing.md,
        childAspectRatio: 0.7,
      ),
      itemCount: 4,
      itemBuilder: (BuildContext context, int index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AppSkeleton(
              width: double.infinity,
              height: MitlistSpacing.space24,
            ),
            const SizedBox(height: MitlistSpacing.sm),
            AppSkeleton(
              width: MitlistSpacing.space14,
              height: MitlistSpacing.space3,
            ),
            const SizedBox(height: MitlistSpacing.sm),
            Row(
              children: <Widget>[
                AppSkeleton(
                  width: MitlistSpacing.space8,
                  height: MitlistSpacing.space4,
                ),
                const SizedBox(width: MitlistSpacing.sm),
                AppSkeleton(
                  width: MitlistSpacing.space8,
                  height: MitlistSpacing.space4,
                ),
              ],
            ),
          ],
        );
      },
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

  Widget _buildRecipeGrid() {
    return RefreshIndicator(
      color: MitlistColors.primary500,
      onRefresh: _loadRecipes,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(MitlistSpacing.md),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: MitlistSpacing.md,
          crossAxisSpacing: MitlistSpacing.md,
          childAspectRatio: 0.7,
        ),
        itemCount:
            _recipes.length +
                (_isLoadingMore || _loadMoreErrorMessage != null ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index >= _recipes.length) {
            if (_loadMoreErrorMessage != null) {
              return _LoadMoreErrorTile(
                message: _loadMoreErrorMessage!,
                onRetry: _loadMoreRecipes,
              );
            }
            return const Center(child: CircularProgressIndicator());
          }

          final _Recipe recipe = _recipes[index];
          return _RecipeCard(
            recipe: recipe,
            onTap: () => _openRecipeDetail(recipe),
          );
        },
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty) ...[
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: Image.network(
                  recipe.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: MitlistSpacing.sm),
          ],
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: MitlistSpacing.sm),
          Wrap(
            spacing: MitlistSpacing.sm,
            runSpacing: MitlistSpacing.sm,
            children: <Widget>[
              if (recipe.isPublic) const AppChip(label: 'Public'),
            ],
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
