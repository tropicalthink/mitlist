import 'activity_models.dart';
import 'group_models.dart';
import 'meal_plan_models.dart';
import 'pinwall_models.dart';
import 'recipe_models.dart';

class HomeMeal {
  const HomeMeal({required this.plan, this.recipe});

  final MealPlan plan;
  final Recipe? recipe;

  factory HomeMeal.fromJson(Map<String, dynamic> json) => HomeMeal(
    plan: MealPlan.fromJson((json['plan'] as Map).cast<String, dynamic>()),
    recipe: json['recipe'] is Map
        ? Recipe.fromJson((json['recipe'] as Map).cast<String, dynamic>())
        : null,
  );
}

class HomeSnapshot {
  const HomeSnapshot({
    required this.group,
    required this.activities,
    required this.activityError,
    required this.pinwallPosts,
    required this.pinwallError,
    required this.todayMeals,
    required this.todayMealError,
  });

  final Group group;
  final List<ActivityLogModel> activities;
  final bool activityError;
  final List<PinwallPost> pinwallPosts;
  final bool pinwallError;
  final List<HomeMeal> todayMeals;
  final bool todayMealError;

  factory HomeSnapshot.fromJson(Map<String, dynamic> json) => HomeSnapshot(
    group: Group.fromJson((json['group'] as Map).cast<String, dynamic>()),
    activities: _list(json['activities'], ActivityLogModel.fromJson),
    activityError: json['activity_error'] as bool? ?? false,
    pinwallPosts: _list(json['pinwall_posts'], PinwallPost.fromJson),
    pinwallError: json['pinwall_error'] as bool? ?? false,
    todayMeals: _list(json['today_meals'], HomeMeal.fromJson),
    todayMealError: json['today_meal_error'] as bool? ?? false,
  );
}

List<T> _list<T>(dynamic value, T Function(Map<String, dynamic>) decode) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((entry) => decode(entry.cast<String, dynamic>()))
      .toList();
}
