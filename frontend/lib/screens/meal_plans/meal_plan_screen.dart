import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/meal_plan_models.dart';
import '../../models/recipe_models.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../theme/theme.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  final String groupId;
  const MealPlanScreen({super.key, required this.groupId});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  late DateTime _weekStart;
  bool _isLoading = true;
  String? _error;
  final List<MealPlan> _plans = [];
  final Map<String, Recipe> _recipeCache = {};

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(DateTime.now());
    _load();
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
      final plans = await svc.listMealPlans(widget.groupId, from: from, to: to);
      setState(() {
        _plans.clear();
        _plans.addAll(plans);
      });
      await _preloadRecipes(plans);
    } catch (e) {
      setState(() => _error = e.toString());
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

  void _showRecipePicker(DateTime date, String slot) async {
    final recipe = await _RecipePickerSheet.show(context);
    if (recipe == null || !mounted) return;

    final servings = await _ServingsPickerSheet.show(context, defaultServings: recipe.servings);
    if (servings == null || !mounted) return;

    try {
      final svc = await ref.read(mealPlanServiceProviderAsync.future);
      await svc.createMealPlan(CreateMealPlanRequest(
        groupId: widget.groupId,
        date: _formatDate(date),
        slot: slot,
        recipeId: recipe.id,
        servings: servings,
      ));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add meal: $e')),
        );
      }
    }
  }

  void _removePlan(String planId) async {
    try {
      final svc = await ref.read(mealPlanServiceProviderAsync.future);
      await svc.deleteMealPlan(planId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e')),
        );
      }
    }
  }

  void _generateShoppingList() async {
    try {
      final svc = await ref.read(mealPlanServiceProviderAsync.future);
      final from = _formatDate(_weekStart);
      final to = _formatDate(_weekStart.add(const Duration(days: 6)));
      final result = await svc.generateShoppingList(
        widget.groupId,
        from: from,
        to: to,
      );
      final listId = result['list_id'] as String?;
      final itemCount = (result['item_count'] as int?) ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shopping list created with $itemCount items')),
        );
        if (listId != null) {
          context.pushNamed('listDetail', pathParameters: {'listId': listId});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
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
                  icon: const Icon(Icons.chevron_left),
                  tooltip: 'Previous week',
                  onPressed: _prevWeek,
                ),
                Expanded(
                  child: Text(
                    '${DateFormat.yMMMd().format(_weekStart)} – ${DateFormat.yMMMd().format(weekEnd)}',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: 'Next week',
                  onPressed: _nextWeek,
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: AppEmptyState(
                  icon: const Icon(Icons.error_outline),
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
                  );
                },
              ),
            ),
        ],
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

  const _DayCard({
    required this.date,
    required this.plans,
    required this.recipeCache,
    required this.onAdd,
    required this.onRemove,
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
                    color: isToday ? MitlistColors.primary500 : Colors.transparent,
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
                const Spacer(),
                Text(
                  DateFormat.MMMd().format(date),
                  style: MitlistTypography.monoBody(color: MitlistColors.textSecondary),
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

  const _SlotRow({
    required this.slot,
    this.plan,
    this.recipe,
    required this.onAdd,
    this.onRemove,
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
      child: InkWell(
        onTap: plan == null ? onAdd : null,
        borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
        child: Container(
          padding: const EdgeInsets.all(MitlistSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(
              color: plan != null
                  ? MitlistColors.primary500.withValues(alpha: 0.3)
                  : MitlistColors.borderSubtle,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
            color: plan != null
                ? MitlistColors.primary50.withValues(alpha: 0.3)
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  _slotLabel,
                  style: textTheme.labelSmall?.copyWith(color: MitlistColors.textSecondary),
                ),
              ),
              Expanded(
                child: plan == null
                    ? Text(
                        'Add meal',
                        style: textTheme.bodyMedium?.copyWith(
                          color: MitlistColors.textSecondary,
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
                                      style: textTheme.labelSmall?.copyWith(color: MitlistColors.primary500),
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
                    border: Border.all(color: MitlistColors.borderSubtle),
                    borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
                  ),
                  child: Text(
                    '${plan!.servings}p',
                    style: MitlistTypography.labelXSmall(),
                  ),
                ),
                const SizedBox(width: MitlistSpacing.xs),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Remove',
                  onPressed: onRemove,
                ),
              ] else
                const Icon(Icons.add, size: 18, color: MitlistColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipePickerSheet extends ConsumerStatefulWidget {
  const _RecipePickerSheet();

  static Future<Recipe?> show(BuildContext context) async {
    return showAppBottomSheet<Recipe?>(
      context: context,
      title: 'Pick a recipe',
      body: const _RecipePickerSheet(),
    );
  }

  @override
  ConsumerState<_RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends ConsumerState<_RecipePickerSheet> {
  final List<Recipe> _recipes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
        _error = e.toString();
        _isLoading = false;
      });
    }
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
        icon: const Icon(Icons.error_outline),
        title: 'Failed to load recipes',
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
        icon: Icon(Icons.restaurant_outlined),
        title: 'No recipes yet',
        description: 'Add recipes to plan meals',
      );
    }
    return SizedBox(
      height: 320,
      child: ListView.builder(
        itemCount: _recipes.length,
        itemBuilder: (context, index) {
          final r = _recipes[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: r.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
                    child: Image.network(
                      r.imageUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 48),
                    ),
                  )
                : const Icon(Icons.restaurant, size: 48),
            title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: r.descriptionShort.isNotEmpty
                ? Text(r.descriptionShort, maxLines: 1, overflow: TextOverflow.ellipsis)
                : null,
            onTap: () => Navigator.of(context).pop(r),
          );
        },
      ),
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
              icon: const Icon(Icons.remove_circle_outline),
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
              icon: const Icon(Icons.add_circle_outline),
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
