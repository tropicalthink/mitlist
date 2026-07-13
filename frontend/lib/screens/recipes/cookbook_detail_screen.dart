import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/recipe_models.dart';
import '../../providers/recipe_provider.dart';
import '../../theme/spacing.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/animated_check_toggle.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';

class CookbookDetailScreen extends ConsumerStatefulWidget {
  final String collectionId;
  final String? initialName;

  const CookbookDetailScreen({
    super.key,
    required this.collectionId,
    this.initialName,
  });

  @override
  ConsumerState<CookbookDetailScreen> createState() =>
      _CookbookDetailScreenState();
}

class _CookbookDetailScreenState extends ConsumerState<CookbookDetailScreen> {
  bool _isLoading = true;
  String? _error;
  final List<Recipe> _recipes = [];
  String? _submittingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      final recipes =
          await svc.getCollectionRecipes(widget.collectionId, limit: 200);
      if (!mounted) return;
      setState(() {
        _recipes.clear();
        _recipes.addAll(recipes);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e, AppLocalizations.of(context)!);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: MitlistAppBar(
        title: Text(widget.initialName ?? l10n.cookbooksTitle),
      ),
      body: _buildBody(),
      floatingActionButton: _isLoading
          ? null
          : AppButton(
              size: AppButtonSize.lg,
              onPressed: _openAddRecipesSheet,
              text: l10n.cookbookDetailAddRecipes,
              icon: const AppIcon(name: 'plus'),
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

  Widget _buildBodyContent() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(MitlistSpacing.md),
        itemCount: 6,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: MitlistSpacing.sm),
          child: AppSkeleton(width: double.infinity, height: 72),
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
            icon: const AppIcon(name: 'squares2x2'),
            title: l10n.cookbookDetailEmptyTitle,
            description: l10n.cookbookDetailEmptyDesc,
            actions: [
              AppButton(
                variant: AppButtonVariant.outline,
                size: AppButtonSize.sm,
                text: l10n.cookbookDetailAddRecipes,
                onPressed: _openAddRecipesSheet,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(MitlistSpacing.md),
      itemCount: _recipes.length,
      itemBuilder: (context, index) {
        final r = _recipes[index];
        return _RecipeRow(
          recipe: r,
          isSubmitting: _submittingId == r.id,
          onOpen: () => context.pushNamed(
            'recipeDetail',
            pathParameters: {'recipeId': r.id},
          ),
          onRemove: () => _removeRecipe(r),
        );
      },
    );
  }

  Future<void> _removeRecipe(Recipe r) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _submittingId = r.id);
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      await svc.removeRecipeFromCollection(widget.collectionId, r.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cookbookRecipeRemoved)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, l10n))),
      );
    } finally {
      if (mounted) setState(() => _submittingId = null);
    }
  }

  Future<void> _openAddRecipesSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final existingIds = _recipes.map((r) => r.id).toSet();
    final added = await showAppBottomSheet<bool>(
      context: context,
      title: l10n.cookbookAddRecipesSheetTitle,
      body: _AddRecipesSheet(
        collectionId: widget.collectionId,
        excludedRecipeIds: existingIds,
      ),
    );
    if (added == true) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
      child: AppCard(
        variant: AppCardVariant.outlined,
        padding: AppCardPadding.md,
        onTap: isSubmitting ? null : onOpen,
        child: Row(
          children: [
            Expanded(
              child: Text(
                recipe.title,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSubmitting)
              const SizedBox(
                width: MitlistSpacing.space5,
                height: MitlistSpacing.space5,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const AppIcon(name: 'trashOutline'),
                tooltip: l10n.cookbookRemoveRecipe,
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

class _AddRecipesSheet extends ConsumerStatefulWidget {
  final String collectionId;
  final Set<String> excludedRecipeIds;

  const _AddRecipesSheet({
    required this.collectionId,
    required this.excludedRecipeIds,
  });

  @override
  ConsumerState<_AddRecipesSheet> createState() => _AddRecipesSheetState();
}

class _AddRecipesSheetState extends ConsumerState<_AddRecipesSheet> {
  bool _isLoading = true;
  String? _error;
  final List<Recipe> _available = [];
  final Set<String> _selectedIds = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      final recipes = await svc.listRecipes(limit: 200);
      if (!mounted) return;
      setState(() {
        _available
          ..clear()
          ..addAll(recipes
              .where((r) => !widget.excludedRecipeIds.contains(r.id)));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e, AppLocalizations.of(context)!);
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedIds.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSubmitting = true);
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      final selected = _selectedIds.toList();
      for (final id in selected) {
        await svc.addRecipeToCollection(
          widget.collectionId,
          AddRecipeToCollectionRequest(recipeId: id),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cookbookRecipesAdded(selected.length))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, l10n))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return AppEmptyState(
        icon: const AppIcon(name: 'alertCircleOutline'),
        title: l10n.commonSomethingWentWrong,
        description: _error,
        actions: [
          AppButton(
            variant: AppButtonVariant.outline,
            text: l10n.commonRetry,
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _load();
            },
          ),
        ],
      );
    }

    if (_available.isEmpty) {
      return AppEmptyState(
        icon: const AppIcon(name: 'squares2x2'),
        title: l10n.cookbookAddRecipesEmpty,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._available.map((r) {
          final isSelected = _selectedIds.contains(r.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
            child: Row(
              children: [
                AnimatedCheckToggle(
                  value: isSelected,
                  onChanged: _isSubmitting
                      ? null
                      : (_) {
                          setState(() {
                            if (isSelected) {
                              _selectedIds.remove(r.id);
                            } else {
                              _selectedIds.add(r.id);
                            }
                          });
                        },
                ),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: Text(
                    r.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: MitlistSpacing.md),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            text: l10n.cookbookAddRecipesSheetTitle,
            isLoading: _isSubmitting,
            onPressed:
                _selectedIds.isNotEmpty && !_isSubmitting ? _submit : null,
          ),
        ),
      ],
    );
  }
}
