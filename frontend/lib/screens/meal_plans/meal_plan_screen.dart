import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/meal_plan_models.dart';
import '../../models/recipe_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../theme/theme.dart';
import '../../utils/active_group_context.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';
import '../../exceptions.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  final String groupId;
  const MealPlanScreen({super.key, this.groupId = ''});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  late DateTime _weekStart;
  bool _isLoading = true;
  bool _isMutating = false;
  String? _error;
  final List<MealPlan> _plans = [];
  final Map<String, Recipe> _recipeCache = {};
  String? _resolvedGroupId;

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(DateTime.now());
    _resolveAndLoad();
  }

  Future<void> _resolveAndLoad() async {
    if (widget.groupId.isNotEmpty) {
      _resolvedGroupId = widget.groupId;
      await _load();
      return;
    }
    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupService.listGroups(limit: 50);
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (!mounted) return;
      if (groupId == null || groupId.isEmpty) {
        setState(() {
          _error = 'Create or join a household first';
          _isLoading = false;
        });
        return;
      }
      _resolvedGroupId = groupId;
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Couldn\u2019t load this week\u2019s meal plans.';
        _isLoading = false;
      });
    }
  }

  DateTime _startOfWeek(DateTime date) {
    final wd = date.weekday % 7;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: wd));
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final svc = await ref.read(mealPlanServiceProviderAsync.future);
      final from = _formatDate(_weekStart);
      final to = _formatDate(_weekStart.add(const Duration(days: 6)));
      final plans = await svc.listMealPlans(_resolvedGroupId!, from: from, to: to);
      setState(() {
        _plans.clear();
        _plans.addAll(plans);
      });
      await _preloadRecipes(plans);
    } catch (e) {
      setState(() => _error = 'Couldn\u2019t load meal plans.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _preloadRecipes(List<MealPlan> plans) async {
    final recipeIds = plans.map((p) => p.recipeId).toSet();
    if (recipeIds.isEmpty) return;
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      for (final id in recipeIds) {
        if (_recipeCache.containsKey(id)) continue;
        final r = await svc.getRecipe(id);
        if (mounted) setState(() => _recipeCache[id] = r);
      }
    } catch (_) {
      // best effort
    }
  }

  String _formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  void _prevWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    _load();
  }

  void _nextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
    _load();
  }

  Future<void> _showRecipePicker(DateTime date, String slot) async {
    if (_isMutating) return;
    _isMutating = true;
    final recipe = await _RecipePickerSheet.show(context);
    if (recipe == null || !mounted) { _isMutating = false; return; }

    final servings = await _ServingsPickerSheet.show(context, defaultServings: recipe.servings);
    if (servings == null || !mounted) { _isMutating = false; return; }

    try {
      final svc = await ref.read(mealPlanServiceProviderAsync.future);
      await svc.createMealPlan(CreateMealPlanRequest(
        groupId: _resolvedGroupId!,
        date: _formatDate(date),
        slot: slot,
        recipeId: recipe.id,
        servings: servings,
      ));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Couldn\u2019t add meal.')),
        );
      }
    } finally {
      _isMutating = false;
    }
  }

  Future<void> _removePlan(String planId) async {
    if (_isMutating) return;
    _isMutating = true;
    try {
      final svc = await ref.read(mealPlanServiceProviderAsync.future);
      await svc.deleteMealPlan(planId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Couldn\u2019t remove meal.')),
        );
      }
    } finally {
      _isMutating = false;
    }
  }

  Future<void> _editPlan(String planId) async {
    if (_isMutating) return;
    _isMutating = true;
    final plan = _plans.firstWhere(
      (p) => p.id == planId,
      orElse: () => throw const NotFoundException('Meal plan not found'),
    );

    final recipe = await _RecipePickerSheet.show(context, selectedRecipeId: plan.recipeId);
    if (recipe == null || !mounted) { _isMutating = false; return; }

    final servings = await _ServingsPickerSheet.show(context, defaultServings: recipe.servings);
    if (servings == null || !mounted) { _isMutating = false; return; }

    try {
      final svc = await ref.read(mealPlanServiceProviderAsync.future);
      await svc.updateMealPlan(planId, UpdateMealPlanRequest(
        recipeId: recipe.id,
        servings: servings,
      ));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Couldn\u2019t update meal.')),
        );
      }
    } finally {
      _isMutating = false;
    }
  }

  Future<void> _generateShoppingList() async {
    if (_isMutating) return;
    _isMutating = true;
    Haptics.light();
    try {
      final svc = await ref.read(mealPlanServiceProviderAsync.future);
      final from = _formatDate(_weekStart);
      final to = _formatDate(_weekStart.add(const Duration(days: 6)));
      final result = await svc.generateShoppingList(
        _resolvedGroupId!,
        from: from,
        to: to,
      );
      final listId = result['list_id'] as String?;
      final itemCount = (result['item_count'] as int?) ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shopping list created with $itemCount items'),
            action: SnackBarAction(
              label: 'Track costs',
              onPressed: () => context.pushNamed('money'),
            ),
          ),
        );
        if (listId != null) {
          context.pushNamed('listDetail', pathParameters: {'listId': listId});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Something went wrong.')),
        );
      }
    } finally {
      _isMutating = false;
    }
  }

  List<MealPlan> _plansFor(DateTime date) {
    final ds = _formatDate(date);
    return _plans.where((p) => _formatDate(p.date) == ds).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final weekEnd = _weekStart.add(const Duration(days: 6));

    return Scaffold(
      appBar: MitlistAppBar(
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Meal Plan'),
        actions: [
          IconButton(
            icon: const AppIcon(name: 'shoppingCart'),
            tooltip: 'Generate shopping list',
            onPressed: _generateShoppingList,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md, vertical: MitlistSpacing.sm),
            child: Row(
              children: [
                IconButton(
                  icon: const AppIcon(name: 'chevronLeft'),
                  tooltip: 'Previous week',
                  onPressed: _prevWeek,
                ),
                Expanded(
                  child: Text(
                    '${DateFormat.yMMMd().format(_weekStart)} – ${DateFormat.yMMMd().format(weekEnd)}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const AppIcon(name: 'chevronRight'),
                  tooltip: 'Next week',
                  onPressed: _nextWeek,
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: _MealPlanLoadingBody(),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: AppEmptyState(
                  lottieAsset: 'assets/animations/lottie/404.lottie',
                  icon: const AppIcon(name: 'alertCircleOutline'),
                  title: 'Something went wrong',
                  description: _error,
                  actions: [
                    AppButton(
                      variant: AppButtonVariant.outline,
                      text: 'Retry',
                      onPressed: _load,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
                itemCount: 7,
                itemBuilder: (context, index) {
                  final date = _weekStart.add(Duration(days: index));
                  return _DayCard(
                    date: date,
                    plans: _plansFor(date),
                    recipeCache: _recipeCache,
                    onAdd: (slot) => _showRecipePicker(date, slot),
                    onRemove: _removePlan,
                    onEdit: _editPlan,
                  );
                },
              ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MealPlanLoadingBody extends StatelessWidget {
  const _MealPlanLoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
      itemCount: 4,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
        child: AppCard(
          variant: AppCardVariant.outlined,
          padding: AppCardPadding.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppSkeleton(
                      width: 100, height: 16),
                  const Spacer(),
                  AppSkeleton(
                      width: MitlistSpacing.space12,
                      height: 16),
                ],
              ),
              const SizedBox(height: MitlistSpacing.sm),
              AppSkeleton(
                  width: double.infinity, height: 40),
              const SizedBox(height: MitlistSpacing.sm),
              AppSkeleton(
                  width: double.infinity, height: 40),
              const SizedBox(height: MitlistSpacing.sm),
              AppSkeleton(
                  width: double.infinity, height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final DateTime date;
  final List<MealPlan> plans;
  final Map<String, Recipe> recipeCache;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onEdit;

  const _DayCard({
    required this.date,
    required this.plans,
    required this.recipeCache,
    required this.onAdd,
    required this.onRemove,
    required this.onEdit,
  });

  static const _slots = ['breakfast', 'lunch', 'dinner'];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isToday = DateTime.now().year == date.year &&
        DateTime.now().month == date.month &&
        DateTime.now().day == date.day;

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
      child: AppCard(
        variant: AppCardVariant.outlined,
        padding: AppCardPadding.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isToday ? Theme.of(context).colorScheme.primary : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: MitlistSpacing.sm),
                Text(
                  DateFormat.EEEE().format(date),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Spacer(),
                Text(
                  DateFormat.MMMd().format(date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MitlistTypography.monoBody(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: MitlistSpacing.md),
            ..._slots.map((slot) {
              final plan = plans.cast<MealPlan?>().firstWhere(
                    (p) => p?.slot == slot,
                    orElse: () => null,
                  );
              return _SlotRow(
                slot: slot,
                plan: plan,
                recipe: plan != null ? recipeCache[plan.recipeId] : null,
                onAdd: () => onAdd(slot),
                onRemove: plan != null ? () => onRemove(plan.id) : null,
                onEdit: plan != null ? () => onEdit(plan.id) : null,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final String slot;
  final MealPlan? plan;
  final Recipe? recipe;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onEdit;

  const _SlotRow({
    required this.slot,
    this.plan,
    this.recipe,
    required this.onAdd,
    this.onRemove,
    this.onEdit,
  });

  String get _slotLabel {
    switch (slot) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      default:
        return slot;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
      child: Semantics(
        button: true,
        label: 'Add meal for $_slotLabel',
        child: InkWell(
          onTap: plan == null ? onAdd : null,
          borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
          child: Container(
          padding: const EdgeInsets.all(MitlistSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(
              color: plan != null
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                  : Theme.of(context).colorScheme.outlineVariant,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
            color: plan != null
                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  _slotLabel,
                  style: textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: plan == null
                    ? Text(
                        'Add meal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe?.title ?? 'Recipe',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (recipe != null)
                            Builder(builder: (_) {
                              final r = recipe!;
                              return Wrap(
                                spacing: MitlistSpacing.xs,
                                children: r.tags.take(2).map((t) => Text(
                                      '#$t',
                                      style: textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                                    )).toList(),
                              );
                            }),
                        ],
                      ),
              ),
              if (plan != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.xs, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
                  ),
                  child: Text(
                    '${plan!.servings}p',
                    style: MitlistTypography.labelXSmall(),
                  ),
                ),
                const SizedBox(width: MitlistSpacing.xs),
                IconButton(
                  icon: const AppIcon(name: 'pencil', size: 18),
                  tooltip: 'Edit',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: AppIcon(name: 'xMark', size: 18),
                  tooltip: 'Remove',
                  onPressed: onRemove,
                ),
              ] else
                AppIcon(name: 'plus', size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _RecipePickerSheet extends ConsumerStatefulWidget {
  final String? selectedRecipeId;
  const _RecipePickerSheet({this.selectedRecipeId});

  static Future<Recipe?> show(BuildContext context, {String? selectedRecipeId}) async {
    return showAppBottomSheet<Recipe?>(
      context: context,
      title: 'Pick a recipe',
      body: _RecipePickerSheet(selectedRecipeId: selectedRecipeId),
    );
  }

  @override
  ConsumerState<_RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends ConsumerState<_RecipePickerSheet> {
  final List<Recipe> _recipes = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      final recipes = await svc.listRecipes(limit: 100);
      setState(() {
        _recipes.addAll(recipes);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Couldn\u2019t load recipes.';
        _isLoading = false;
      });
    }
  }

  List<Recipe> get _filteredRecipes {
    if (_searchQuery.isEmpty) return _recipes;
    return _recipes.where((r) {
      final title = r.title.toLowerCase();
      final desc = r.descriptionShort.toLowerCase();
      final tags = r.tags.map((t) => t.toLowerCase()).join(' ');
      return title.contains(_searchQuery) ||
          desc.contains(_searchQuery) ||
          tags.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return AppEmptyState(
        lottieAsset: 'assets/animations/lottie/404.lottie',
        icon: const AppIcon(name: 'alertCircleOutline'),
                        title: 'Couldn\u2019t load recipes',
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
    if (_recipes.isEmpty) {
      return const AppEmptyState(
        lottieAsset: 'assets/animations/lottie/Recipes.lottie',
        icon: AppIcon(name: 'restaurantOutline'),
        title: 'No recipes yet',
        description: 'Add recipes to plan meals',
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search recipes...',
              prefixIcon: const AppIcon(name: 'magnifyingGlass', size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: AppIcon(name: 'clear', size: 20),
                      tooltip: 'Clear search',
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 320,
          child: _filteredRecipes.isEmpty
              ? Center(
                  child: Text(
                    'No recipes match "$_searchQuery"',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final r = _filteredRecipes[index];
                    final isSelected = r.id == widget.selectedRecipeId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: r.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
                              child: Semantics(
                                label: 'Image of ${r.title}',
                                child: Image.network(
                                  r.imageUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const AppIcon(name: 'image', size: 48),
                                ),
                              ),
                            )
                          : const AppIcon(name: 'restaurant', size: 48),
                      title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: r.descriptionShort.isNotEmpty
                          ? Text(r.descriptionShort, maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                      trailing: isSelected
                          ? AppIcon(name: 'check', color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop(r),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ServingsPickerSheet extends StatefulWidget {
  final int defaultServings;
  const _ServingsPickerSheet({required this.defaultServings});

  static Future<int?> show(BuildContext context, {required int defaultServings}) async {
    return showAppBottomSheet<int?>(
      context: context,
      title: 'Servings',
      body: _ServingsPickerSheet(defaultServings: defaultServings),
    );
  }

  @override
  State<_ServingsPickerSheet> createState() => _ServingsPickerSheetState();
}

class _ServingsPickerSheetState extends State<_ServingsPickerSheet> {
  late int _servings;

  @override
  void initState() {
    super.initState();
    _servings = widget.defaultServings;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const AppIcon(name: 'minusCircleOutline'),
              tooltip: 'Fewer servings',
              onPressed: _servings > 1
                  ? () => setState(() => _servings--)
                  : null,
            ),
            Text(
              '$_servings',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            IconButton(
              icon: const AppIcon(name: 'addCircleOutline'),
              tooltip: 'More servings',
              onPressed: () => setState(() => _servings++),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            text: 'Confirm',
            onPressed: () => Navigator.of(context).pop(_servings),
          ),
        ),
      ],
    );
  }
}
