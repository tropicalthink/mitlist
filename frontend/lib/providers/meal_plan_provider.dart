import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/meal_plan_models.dart';
import '../models/recipe_models.dart';
import '../providers/recipe_provider.dart';
import '../services/meal_plan_service.dart';

final mealPlanServiceProviderAsync =
    FutureProvider<MealPlanService>((ref) async {
  return await MealPlanService.create(ref);
});

typedef TodayMeal = ({MealPlan plan, Recipe? recipe});

typedef WeekMealPlanSummary = ({String day, String slot, String title});

const _weekDayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

final todayMealPlansProvider =
    FutureProvider.family<List<TodayMeal>, String>((ref, groupId) async {
  ref.keepAlive();
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final mealPlanSvc = await ref.read(mealPlanServiceProviderAsync.future);
  final plans =
      await mealPlanSvc.listMealPlans(groupId, from: today, to: today);

  final recipeSvc = await ref.read(recipeServiceProviderAsync.future);
  final recipes = await Future.wait(
    plans.map((plan) async {
      try {
        return await recipeSvc.getRecipe(plan.recipeId);
      } catch (_) {
        return null;
      }
    }),
  );
  final results = <TodayMeal>[];
  for (var i = 0; i < plans.length; i++) {
    results.add((plan: plans[i], recipe: recipes[i]));
  }
  return results;
});

/// This-week meal plan rows for the Kitchen tab summary card.
final weekMealPlansSummaryProvider =
    FutureProvider.family<List<WeekMealPlanSummary>, String>(
        (ref, groupId) async {
  ref.keepAlive();
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 6));
  final mealPlanSvc = await ref.read(mealPlanServiceProviderAsync.future);
  final plans = await mealPlanSvc.listMealPlans(
    groupId,
    from: DateFormat('yyyy-MM-dd').format(weekStart),
    to: DateFormat('yyyy-MM-dd').format(weekEnd),
  );
  return plans.map((plan) {
    final dayIndex = plan.date.weekday - 1;
    return (
      day: _weekDayLabels[dayIndex.clamp(0, 6)],
      slot: plan.slot,
      title: 'Meal',
    );
  }).toList();
});
