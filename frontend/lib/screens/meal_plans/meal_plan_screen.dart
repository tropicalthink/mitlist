import 'dart:async';

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
import '../../l10n/app_localizations.dart';
import '../../utils/active_group_context.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../utils/latest_request_guard.dart';
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
  String? _error;
  final List<MealPlan> _plans = [];
  final Map<String, Recipe> _recipeCache = {};
  final Set<String> _activeOperations = {};
  final LatestRequestGuard _loadGuard = LatestRequestGuard();
  String? _resolvedGroupId;

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(DateTime.now());
    _resolveAndLoad();
  }

  @override
  void didUpdateWidget(covariant MealPlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId == widget.groupId) return;
    _loadGuard.invalidate();
    _resolvedGroupId = null;
    _plans.clear();
    _recipeCache.clear();
    _error = null;
    _isLoading = true;
    _resolveAndLoad();
  }

  @override
  void dispose() {
    _loadGuard.dispose();
    super.dispose();
  }

  Future<void> _resolveAndLoad() async {
    if (widget.groupId.isNotEmpty) {
      _resolvedGroupId = widget.groupId;
      await _load();
      return;
    }
    try {
      final groups = await ref.read(cachedGroupsProvider.future);
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (groupId == null || groupId.isEmpty) {
        setState(() {
          _error = l10n.shareTargetValidationHousehold;
          _isLoading = false;
        });
        return;
      }
      _resolvedGroupId = groupId;
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e, AppLocalizations.of(context)!);
        _isLoading = false;
      });
    }
  }

  DateTime _startOfWeek(DateTime date) {
    final wd = date.weekday % 7;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: wd));
  }

  Future<void> _load() async {
    final request = _loadGuard.begin();
    final hadContent = _plans.isNotEmpty;
    final groupId = _resolvedGroupId;
    final weekStart = _weekStart;
    if (groupId == null || groupId.isEmpty) return;
    setState(() {
      _isLoading = !hadContent;
      _error = null;
    });
    try {
      // The repository falls back to the cached week when the network is
      // gone; reading the service directly here is what turned an offline
      // launch into a full-page error.
      final repo = await ref.read(mealPlanRepositoryProvider.future);
      final from = _formatDate(weekStart);
      final to = _formatDate(weekStart.add(const Duration(days: 6)));
      final plans = await repo.load(groupId, from: from, to: to);
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      setState(() {
        _plans.clear();
        _plans.addAll(plans);
        _isLoading = false;
      });
      await _preloadRecipes(plans, request);
    } catch (e) {
      if (!mounted || !_loadGuard.isCurrent(request)) return;
      final message = friendlyErrorMessage(e, AppLocalizations.of(context)!);
      if (hadContent) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      } else {
        setState(() {
          _error = message;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _preloadRecipes(List<MealPlan> plans, int request) async {
    final recipeIds = plans.map((p) => p.recipeId).toSet();
    if (recipeIds.isEmpty) return;
    try {
      final svc = await ref.read(recipeServiceProviderAsync.future);
      final loaded = <String, Recipe>{};
      for (final id in recipeIds) {
        if (_recipeCache.containsKey(id)) continue;
        loaded[id] = await svc.getRecipe(id);
        if (!mounted || !_loadGuard.isCurrent(request)) return;
      }
      if (loaded.isNotEmpty && mounted && _loadGuard.isCurrent(request)) {
        setState(() => _recipeCache.addAll(loaded));
      }
    } catch (_) {
      // best effort
    }
  }

  bool _beginOperation(String key) {
    if (_activeOperations.contains(key)) return false;
    setState(() => _activeOperations.add(key));
    return true;
  }

  void _finishOperation(String key) {
    if (!mounted) return;
    setState(() => _activeOperations.remove(key));
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
    final operation = 'slot:${_formatDate(date)}:$slot';
    if (!_beginOperation(operation)) return;
    try {
      final recipe = await _RecipePickerSheet.show(context);
      if (recipe == null || !mounted) return;

      final servings = await _ServingsPickerSheet.show(context,
          defaultServings: recipe.servings);
      if (servings == null || !mounted) return;

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
          SnackBar(
              content: Text(AppLocalizations.of(context)!.mealPlanCouldNotAdd)),
        );
      }
    } finally {
      _finishOperation(operation);
    }
  }

  Future<void> _removePlan(String planId) async {
    final operation = 'plan:$planId';
    if (!_beginOperation(operation)) return;
    try {
      final svc = await ref.read(mealPlanServiceProviderAsync.future);
      await svc.deleteMealPlan(planId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.mealPlanCouldNotRemove)),
        );
      }
    } finally {
      _finishOperation(operation);
    }
  }

  Future<void> _editPlan(String planId) async {
    final operation = 'plan:$planId';
    if (!_beginOperation(operation)) return;
    try {
      final plan = _plans.firstWhere(
        (p) => p.id == planId,
        orElse: () => throw const NotFoundException('Meal plan not found'),
      );
      final recipe = await _RecipePickerSheet.show(context,
          selectedRecipeId: plan.recipeId);
      if (recipe == null || !mounted) return;

      final servings = await _ServingsPickerSheet.show(context,
          defaultServings: recipe.servings);
      if (servings == null || !mounted) return;

      final svc = await ref.read(mealPlanServiceProviderAsync.future);
      await svc.updateMealPlan(
          planId,
          UpdateMealPlanRequest(
            recipeId: recipe.id,
            servings: servings,
          ));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.mealPlanCouldNotUpdate)),
        );
      }
    } finally {
      _finishOperation(operation);
    }
  }

  Future<void> _generateShoppingList() async {
    const operation = 'generate';
    if (!_beginOperation(operation)) return;
    unawaited(Haptics.light());
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
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.mealPlanShoppingListCreated(itemCount)),
            action: SnackBarAction(
              label: l10n.mealPlanTrackCosts,
              onPressed: () => context.pushNamed('money'),
            ),
          ),
        );
        if (listId != null) {
          unawaited(context
              .pushNamed('listDetail', pathParameters: {'listId': listId}));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
        );
      }
    } finally {
      _finishOperation(operation);
    }
  }

  List<MealPlan> _plansFor(DateTime date) {
    final ds = _formatDate(date);
    return _plans.where((p) => _formatDate(p.date) == ds).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final weekEnd = _weekStart.add(const Duration(days: 6));

    return Scaffold(
      appBar: MitlistAppBar(
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.mealPlanAppBarTitle),
        actions: [
          IconButton(
            icon: const AppIcon(name: 'shoppingCart'),
            tooltip: l10n.mealPlanGenerateShoppingList,
            onPressed: _activeOperations.contains('generate')
                ? null
                : _generateShoppingList,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: MitlistSpacing.md, vertical: MitlistSpacing.sm),
            child: Row(
              children: [
                IconButton(
                  icon: const AppIcon(name: 'chevronLeft'),
                  tooltip: l10n.mealPlanPreviousWeek,
                  onPressed: _prevWeek,
                ),
                Expanded(
                  child: Text(
                    '${DateFormat.yMMMd().format(_weekStart)} \u2013 ${DateFormat.yMMMd().format(weekEnd)}',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const AppIcon(name: 'chevronRight'),
                  tooltip: l10n.mealPlanNextWeek,
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
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
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
                  const AppSkeleton(width: 100, height: 16),
                  const Spacer(),
                  AppSkeleton(width: MitlistSpacing.space12, height: 16),
                ],
              ),
              const SizedBox(height: MitlistSpacing.sm),
              AppSkeleton(width: double.infinity, height: 40),
              const SizedBox(height: MitlistSpacing.sm),
              AppSkeleton(width: double.infinity, height: 40),
              const SizedBox(height: MitlistSpacing.sm),
              AppSkeleton(width: double.infinity, height: 40),
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
                    color: isToday
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
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
                  style: MitlistTypography.monoBody(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                onOpen: plan != null
                    ? () => context.pushNamed('recipeDetail',
                        pathParameters: {'recipeId': plan.recipeId})
                    : null,
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
  final VoidCallback? onOpen;

  const _SlotRow({
    required this.slot,
    this.plan,
    this.recipe,
    required this.onAdd,
    this.onRemove,
    this.onEdit,
    this.onOpen,
  });

  String _slotLabel(AppLocalizations l10n) {
    switch (slot) {
      case 'breakfast':
        return l10n.mealPlanBreakfast;
      case 'lunch':
        return l10n.mealPlanLunch;
      case 'dinner':
        return l10n.mealPlanDinner;
      default:
        return slot;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final slotLabel = _slotLabel(l10n);

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
      child: Semantics(
        button: true,
        label: plan != null
            ? l10n.mealPlanOpenRecipe(slotLabel)
            : l10n.mealPlanAddMealFor(slotLabel),
        child: InkWell(
          onTap: plan == null ? onAdd : onOpen,
          borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
          child: Container(
            padding: const EdgeInsets.all(MitlistSpacing.sm),
            decoration: BoxDecoration(
              border: Border.all(
                color: plan != null
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3)
                    : Theme.of(context).colorScheme.outlineVariant,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
              color: plan != null
                  ? Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3)
                  : null,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    slotLabel,
                    style: textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: plan == null
                      ? Text(
                          l10n.mealPlanAddMeal,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe?.title ?? l10n.mealPlanRecipeFallback,
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
                                  children: r.tags
                                      .take(2)
                                      .map((t) => Text(
                                            '#$t',
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary),
                                          ))
                                      .toList(),
                                );
                              }),
                          ],
                        ),
                ),
                if (plan != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: MitlistSpacing.xs, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius:
                          BorderRadius.circular(MitlistTheme.radiusSm),
                    ),
                    child: Text(
                      l10n.mealPlanServings(plan!.servings),
                      style: MitlistTypography.labelXSmall(),
                    ),
                  ),
                  const SizedBox(width: MitlistSpacing.xs),
                  IconButton(
                    icon: const AppIcon(name: 'pencil', size: 18),
                    tooltip: l10n.commonEdit,
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: AppIcon(name: 'xMark', size: 18),
                    tooltip: l10n.commonRemove,
                    onPressed: onRemove,
                  ),
                ] else
                  AppIcon(
                      name: 'plus',
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
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

  static Future<Recipe?> show(BuildContext context,
      {String? selectedRecipeId}) async {
    final l10n = AppLocalizations.of(context)!;
    return showAppBottomSheet<Recipe?>(
      context: context,
      title: l10n.mealPlanPickRecipe,
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
    // Cache first: the picker only needs something to choose from, and the
    // recipe cache already holds everything the kitchen has shown (including
    // recipes created offline that the server has not seen yet).
    final repo = await ref.read(recipeRepositoryProvider.future);
    final cached = await repo.getRecipesOnce();
    if (!mounted) return;
    if (cached.isNotEmpty) {
      setState(() {
        _recipes
          ..clear()
          ..addAll(cached);
        _isLoading = false;
      });
    }
    try {
      await repo.refreshRecipes(limit: 100);
      final fresh = await repo.getRecipesOnce();
      if (!mounted) return;
      setState(() {
        _recipes
          ..clear()
          ..addAll(fresh);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || cached.isNotEmpty) return;
      setState(() {
        _error = friendlyErrorMessage(e, AppLocalizations.of(context)!);
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
    final l10n = AppLocalizations.of(context)!;
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
        title: l10n.mealPlanCouldNotLoadRecipes,
        description: _error,
        actions: [
          AppButton(
            variant: AppButtonVariant.outline,
            text: l10n.commonRetry,
            onPressed: _load,
          ),
        ],
      );
    }
    if (_recipes.isEmpty) {
      return AppEmptyState(
        lottieAsset: 'assets/animations/lottie/Recipes.lottie',
        icon: const AppIcon(name: 'restaurantOutline'),
        title: l10n.mealPlanNoRecipes,
        description: l10n.mealPlanAddRecipesDesc,
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
              hintText: l10n.mealPlanSearchRecipes,
              prefixIcon: const AppIcon(name: 'magnifyingGlass', size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: AppIcon(name: 'clear', size: 20),
                      tooltip: l10n.commonClearSearch,
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
                borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 320,
          child: _filteredRecipes.isEmpty
              ? Center(
                  child: Text(
                    l10n.mealPlanNoMatch(_searchQuery),
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
                              borderRadius:
                                  BorderRadius.circular(MitlistTheme.radiusSm),
                              child: Semantics(
                                label: l10n.recipeImageSemantics(r.title),
                                child: Image.network(
                                  r.imageUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  cacheWidth: (48 *
                                          MediaQuery.devicePixelRatioOf(
                                              context) *
                                          1.5)
                                      .round(),
                                  errorBuilder: (_, __, ___) =>
                                      const AppIcon(name: 'image', size: 48),
                                ),
                              ),
                            )
                          : const AppIcon(name: 'restaurant', size: 48),
                      title: Text(r.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: r.descriptionShort.isNotEmpty
                          ? Text(r.descriptionShort,
                              maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                      trailing: isSelected
                          ? AppIcon(
                              name: 'check',
                              color: Theme.of(context).colorScheme.primary)
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

  static Future<int?> show(BuildContext context,
      {required int defaultServings}) async {
    final l10n = AppLocalizations.of(context)!;
    return showAppBottomSheet<int?>(
      context: context,
      title: l10n.mealPlanServingsSheet,
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
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const AppIcon(name: 'minusCircleOutline'),
              tooltip: l10n.mealPlanFewerServings,
              onPressed:
                  _servings > 1 ? () => setState(() => _servings--) : null,
            ),
            Text(
              '$_servings',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            IconButton(
              icon: const AppIcon(name: 'addCircleOutline'),
              tooltip: l10n.mealPlanMoreServings,
              onPressed: () => setState(() => _servings++),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            text: l10n.commonConfirm,
            onPressed: () => Navigator.of(context).pop(_servings),
          ),
        ),
      ],
    );
  }
}
