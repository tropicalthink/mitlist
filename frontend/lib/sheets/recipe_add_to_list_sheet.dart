import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/list_models.dart';
import '../../models/recipe_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/active_group_context.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';

class RecipeAddToListSheet extends ConsumerStatefulWidget {
  final String recipeId;
  final String recipeTitle;
  final int defaultServings;

  const RecipeAddToListSheet({
    super.key,
    required this.recipeId,
    required this.recipeTitle,
    required this.defaultServings,
  });

  static Future<void> show(
    BuildContext context, {
    required String recipeId,
    required String recipeTitle,
    required int defaultServings,
  }) async {
    return showAppBottomSheet(
      context: context,
      title: 'Add to list',
      body: RecipeAddToListSheet(
        recipeId: recipeId,
        recipeTitle: recipeTitle,
        defaultServings: defaultServings,
      ),
    );
  }

  @override
  ConsumerState<RecipeAddToListSheet> createState() => _RecipeAddToListSheetState();
}

class _RecipeAddToListSheetState extends ConsumerState<RecipeAddToListSheet> {
  bool _isLoading = true;
  String? _error;
  final List<RecipeIngredient> _ingredients = [];
  final Set<String> _selectedIngredientIds = {};
  int _servings = 2;
  final List<ItemList> _lists = [];
  String? _selectedListId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _servings = widget.defaultServings;
    _load();
  }

  Future<void> _load() async {
    try {
      final recipeSvc = await ref.read(recipeServiceProviderAsync.future);
      final listSvc = await ref.read(listServiceProviderAsync.future);
      final ingredients = await recipeSvc.getRecipeIngredients(widget.recipeId);

      final groupId = await _resolveGroupId();
      List<ItemList> lists = [];
      if (groupId != null) {
        lists = await listSvc.listLists(groupId, limit: 100);
        lists = lists.where((l) => l.type == 'shopping' || l.type == 'general').toList();
        lists.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }

      setState(() {
        _ingredients.addAll(ingredients);
        _selectedIngredientIds.addAll(ingredients.map((i) => i.id));
        _lists.addAll(lists);
        if (lists.isNotEmpty) _selectedListId = lists.first.id;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Something went wrong.';
        _isLoading = false;
      });
    }
  }

  Future<String?> _resolveGroupId() async {
    try {
      final groupSvc = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupSvc.listGroups(limit: 50);
      return resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
    } catch (_) {
      return null;
    }
  }

  double _scaledQuantity(double base) {
    if (base <= 0) return 0;
    return base * _servings / widget.defaultServings;
  }

  Future<void> _submit() async {
    if (_selectedListId == null || _selectedIngredientIds.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final recipeSvc = await ref.read(recipeServiceProviderAsync.future);
      await recipeSvc.addToList(
        widget.recipeId,
        _selectedListId!,
        servings: _servings,
        ingredientIds: _selectedIngredientIds.toList(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingredients added to list')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return AppEmptyState(
        icon: const Icon(Icons.error_outline),
        title: 'Failed to load',
        description: _error,
        actions: [
          AppButton(
            variant: AppButtonVariant.outline,
            text: 'Retry',
            onPressed: _load,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.recipeTitle,
          style: textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppCardPadding.md,
          child: Row(
            children: [
              const Text('Servings'),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.remove_circle_outline),
                tooltip: 'Decrease servings',
                onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
              ),
              Text(
                '$_servings',
                style: MitlistTypography.monoBody(color: Theme.of(context).colorScheme.onSurface),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Increase servings',
                onPressed: () => setState(() => _servings++),
              ),
            ],
          ),
        ),
        const SizedBox(height: MitlistSpacing.md),
        if (_lists.isEmpty)
          const AppEmptyState(
            icon: Icon(Icons.list_alt_outlined),
            title: 'No lists',
            description: 'Create a list first to add ingredients',
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _selectedListId,
            decoration: const InputDecoration(
              labelText: 'Target list',
              border: OutlineInputBorder(),
            ),
            items: _lists.map((list) => DropdownMenuItem<String>(
              value: list.id,
              child: Text(list.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: (value) => setState(() => _selectedListId = value),
          ),
        const SizedBox(height: MitlistSpacing.md),
        Text('Ingredients', style: textTheme.titleSmall),
        const SizedBox(height: MitlistSpacing.sm),
        if (_ingredients.isEmpty)
          const AppEmptyState(
            icon: Icon(Icons.restaurant_outlined),
            title: 'No ingredients',
            description: 'This recipe has no parsed ingredients',
          )
        else
          ..._ingredients.map((ing) {
            final isSelected = _selectedIngredientIds.contains(ing.id);
            final scaled = _scaledQuantity(ing.quantity);
            final qtyText = scaled > 0
                ? '${scaled.toStringAsFixed(scaled == scaled.roundToDouble() ? 0 : 1)} ${ing.unit}'
                : ing.unit;
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              value: isSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedIngredientIds.add(ing.id);
                  } else {
                    _selectedIngredientIds.remove(ing.id);
                  }
                });
              },
              title: Text(ing.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                qtyText.trim(),
                style: MitlistTypography.labelXSmall(),
              ),
            );
          }),
        const SizedBox(height: MitlistSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            text: 'Add to list',
            isLoading: _isSubmitting,
            onPressed: _selectedListId != null && _selectedIngredientIds.isNotEmpty && !_isSubmitting
                ? _submit
                : null,
          ),
        ),
      ],
    );
  }
}
