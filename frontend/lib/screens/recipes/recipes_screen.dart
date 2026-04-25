import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/recipe_provider.dart';
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

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});

  @override
  ConsumerState<RecipesScreen> createState() => _RecipesScreenState();
}

class _Recipe {
  final String id;
  final String title;
  final List<String> tags;

  const _Recipe({
    required this.id,
    required this.title,
    required this.tags,
  });
}

enum _ViewState { loading, error, empty, loaded }

class _RecipesScreenState extends ConsumerState<RecipesScreen> {
  static const int _pageLimit = 50;

  _ViewState _viewState = _ViewState.empty;
  String? _errorMessage;
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

  Future<void> _loadRecipes() async {
    setState(() {
      _viewState = _ViewState.loading;
      _errorMessage = null;
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
                tags: [
                  if (api.description.isNotEmpty) api.description,
                  api.isPublic ? 'Public' : 'Private',
                ],
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
      _errorMessage = null;
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
              tags: [
                if (api.description.isNotEmpty) api.description,
                api.isPublic ? 'Public' : 'Private',
              ],
            )));
        _hasMore = apiRecipes.length == _pageLimit;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load more recipes';
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
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
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(MitlistSpacing.md),
                child: AppEmptyState(
                  icon: AppIcon(
                    name: 'informationCircle',
                    size: 56,
                  ),
                  title: 'No recipes yet',
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
            _recipes.length + (_isLoadingMore || _errorMessage != null ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index >= _recipes.length) {
            return _errorMessage != null
                ? AppAlert(
                    type: AppAlertType.error,
                    message: _errorMessage!,
                  )
                : const Center(child: CircularProgressIndicator());
          }

          final _Recipe recipe = _recipes[index];
          return _RecipeCard(
            recipe: recipe,
            onTap: () {
              // TODO: navigate to RecipeDetailScreen
            },
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

  @override
  Widget build(BuildContext context) {
    return AppCard(
      interactive: true,
      animated: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: MitlistColors.neutral100,
              child: const Center(
                child: AppIcon(
                  name: 'informationCircle',
                  size: 32,
                  color: MitlistColors.neutral400,
                ),
              ),
            ),
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Text(
            recipe.title,
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Wrap(
            spacing: MitlistSpacing.sm,
            runSpacing: MitlistSpacing.sm,
            children:
                recipe.tags.map((String tag) => AppChip(label: tag)).toList(),
          ),
        ],
      ),
    );
  }
}
