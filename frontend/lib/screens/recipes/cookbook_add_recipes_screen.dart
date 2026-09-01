import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/recipe_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../theme/spacing.dart';
import '../../utils/active_group_context.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/animated_check_toggle.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';
import 'cookbook_detail_screen.dart' show RecipeThumbnail;

/// Full-screen picker for filing recipes into a cookbook.
///
/// A page rather than a sheet: the whole library has to fit, with a search
/// box and a submit button that stays reachable however long the list gets —
/// the previous sheet put the button under 200 rows.
class CookbookAddRecipesScreen extends ConsumerStatefulWidget {
  final String collectionId;

  /// Recipes already in the cookbook; listed but not selectable.
  final Set<String> excludedRecipeIds;

  const CookbookAddRecipesScreen({
    super.key,
    required this.collectionId,
    this.excludedRecipeIds = const {},
  });

  @override
  ConsumerState<CookbookAddRecipesScreen> createState() =>
      _CookbookAddRecipesScreenState();
}

class _CookbookAddRecipesScreenState
    extends ConsumerState<CookbookAddRecipesScreen> {
  bool _isLoading = true;
  String? _error;
  final List<Recipe> _recipes = [];
  final Set<String> _selectedIds = {};
  bool _isSubmitting = false;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      String? groupId;
      try {
        final groups = await ref.read(cachedGroupsProvider.future);
        final id =
            resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
        if (isValidGroupId(id)) groupId = id;
      } catch (_) {
        // Personal recipes still list without a household.
      }
      final svc = await ref.read(recipeServiceProviderAsync.future);
      // The household's recipes are as fileable as the user's own; without
      // the group id they would simply never appear here.
      final recipes = await svc.listRecipes(limit: 200, groupId: groupId);
      if (!mounted) return;
      setState(() {
        _recipes
          ..clear()
          ..addAll(recipes);
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

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = value.trim().toLowerCase());
    });
  }

  List<Recipe> get _visible {
    if (_query.isEmpty) return _recipes;
    return _recipes
        .where((r) =>
            r.title.toLowerCase().contains(_query) ||
            r.tags.any((t) => t.toLowerCase().contains(_query)))
        .toList();
  }

  void _toggle(Recipe r) {
    unawaited(Haptics.light());
    setState(() {
      if (!_selectedIds.remove(r.id)) _selectedIds.add(r.id);
    });
  }

  Future<void> _submit() async {
    if (_selectedIds.isEmpty || _isSubmitting) return;
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
      unawaited(Haptics.success());
      AppToast.success(context, l10n.cookbookRecipesAdded(selected.length));
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppToast.error(context, friendlyErrorMessage(e, l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: MitlistAppBar(
        title: Text(l10n.cookbookAddRecipesSheetTitle),
        showStandardActions: false,
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: l10n.commonBack,
          onPressed: () => context.pop(false),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _isLoading || _error != null || _recipes.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  MitlistSpacing.md,
                  MitlistSpacing.sm,
                  MitlistSpacing.md,
                  MitlistSpacing.md,
                ),
                child: AppButton(
                  size: AppButtonSize.lg,
                  text: l10n.cookbookAddRecipesSubmit(_selectedIds.length),
                  isLoading: _isSubmitting,
                  onPressed:
                      _selectedIds.isEmpty || _isSubmitting ? null : _submit,
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        itemCount: 8,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: MitlistSpacing.sm),
          child: AppSkeleton(width: double.infinity, height: 88),
        ),
      );
    }
    if (_error != null) {
      return Center(
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
      );
    }
    if (_recipes.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: const AppIcon(name: 'restaurantMenu', size: 56),
          title: l10n.recipeBuildKitchen,
          description: l10n.recipeBuildKitchenDesc,
        ),
      );
    }

    final visible = _visible;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MitlistSpacing.md,
            MitlistSpacing.md,
            MitlistSpacing.md,
            MitlistSpacing.sm,
          ),
          child: AppInput(
            controller: _searchController,
            hint: l10n.cookbookAddRecipesSearchHint,
            prefixIcon: const AppIcon(name: 'magnifyingGlass'),
            clearable: true,
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: AppEmptyState(
                    paddingPreset: AppEmptyStatePadding.md,
                    icon: const AppIcon(name: 'magnifyingGlass', size: 48),
                    title: l10n.cookbookAddRecipesNoMatch,
                    description: l10n.recipeNoMatchDesc,
                  ),
                )
              : ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    MitlistSpacing.md,
                    0,
                    MitlistSpacing.md,
                    MitlistSpacing.md,
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: MitlistSpacing.sm),
                  itemBuilder: (context, index) {
                    final r = visible[index];
                    final alreadyIn = widget.excludedRecipeIds.contains(r.id);
                    return _PickRow(
                      recipe: r,
                      selected: _selectedIds.contains(r.id),
                      alreadyIn: alreadyIn,
                      onTap:
                          alreadyIn || _isSubmitting ? null : () => _toggle(r),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PickRow extends StatelessWidget {
  final Recipe recipe;
  final bool selected;
  final bool alreadyIn;
  final VoidCallback? onTap;

  const _PickRow({
    required this.recipe,
    required this.selected,
    required this.alreadyIn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final subtitle = alreadyIn
        ? l10n.cookbookAddRecipesAlreadyIn
        : (recipe.isSharedWithHousehold
            ? l10n.recipeDetailSharedLabel
            : l10n.recipeDetailPrivateLabel);

    return Opacity(
      opacity: alreadyIn ? 0.55 : 1,
      child: AppCard(
        variant: AppCardVariant.outlined,
        padding: AppCardPadding.md,
        interactive: onTap != null,
        onTap: onTap,
        semanticLabel: recipe.title,
        child: Row(
          children: [
            AnimatedCheckToggle(
              value: selected || alreadyIn,
              onChanged: onTap == null ? null : (_) => onTap!(),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            RecipeThumbnail(
              imageUrl: recipe.imageUrl,
              title: recipe.title,
              size: MitlistSpacing.space12,
            ),
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
      ),
    );
  }
}
