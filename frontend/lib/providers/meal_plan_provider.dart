import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/meal_plan_service.dart';

final mealPlanServiceProviderAsync = FutureProvider<MealPlanService>((ref) async {
  return await MealPlanService.create(ref);
});
