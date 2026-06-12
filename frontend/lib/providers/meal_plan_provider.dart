import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/meal_plan_models.dart';
import '../models/recipe_models.dart';
import '../providers/recipe_provider.dart';
import '../services/meal_plan_service.dart';

final mealPlanServiceProviderAsync = FutureProvider<MealPlanService>((ref) async {
  return await MealPlanService.create(ref);
});

typedef TodayMeal = ({MealPlan plan, Recipe? recipe});

final todayMealPlansProvider =
    FutureProvider.family<List<TodayMeal>, String>((ref, groupId) async {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final mealPlanSvc = await ref.read(mealPlanServiceProviderAsync.future);
  final plans = await mealPlanSvc.listMealPlans(groupId, from: today, to: today);

  final recipeSvc = await ref.read(recipeServiceProviderAsync.future);
  final results = <TodayMeal>[];
  for (final plan in plans) {
    Recipe? recipe;
    try {
      recipe = await recipeSvc.getRecipe(plan.recipeId);
    } catch (_) {}
    results.add((plan: plan, recipe: recipe));
  }
  return results;
});
