class MealPlan {
  final String id;
  final String groupId;
  final DateTime date;
  final String slot;
  final String recipeId;
  final int servings;
  final String? cookUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MealPlan({
    required this.id,
    required this.groupId,
    required this.date,
    required this.slot,
    required this.recipeId,
    required this.servings,
    this.cookUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) => MealPlan(
        id: json['id'] as String,
        groupId: json['group_id'] as String,
        date: DateTime.parse(json['date'] as String),
        slot: json['slot'] as String? ?? 'dinner',
        recipeId: json['recipe_id'] as String,
        servings: json['servings'] as int? ?? 1,
        cookUserId: json['cook_user_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'group_id': groupId,
        'date': date.toIso8601String().split('T')[0],
        'slot': slot,
        'recipe_id': recipeId,
        'servings': servings,
        if (cookUserId != null) 'cook_user_id': cookUserId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class CreateMealPlanRequest {
  final String groupId;
  final String date;
  final String slot;
  final String recipeId;
  final int servings;
  final String? cookUserId;

  const CreateMealPlanRequest({
    required this.groupId,
    required this.date,
    this.slot = 'dinner',
    required this.recipeId,
    this.servings = 1,
    this.cookUserId,
  });

  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'date': date,
        'slot': slot,
        'recipe_id': recipeId,
        'servings': servings,
        if (cookUserId != null) 'cook_user_id': cookUserId,
      };
}

class UpdateMealPlanRequest {
  final String? date;
  final String? slot;
  final String? recipeId;
  final int? servings;
  final String? cookUserId;

  const UpdateMealPlanRequest({
    this.date,
    this.slot,
    this.recipeId,
    this.servings,
    this.cookUserId,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (date != null) m['date'] = date;
    if (slot != null) m['slot'] = slot;
    if (recipeId != null) m['recipe_id'] = recipeId;
    if (servings != null) m['servings'] = servings;
    if (cookUserId != null) m['cook_user_id'] = cookUserId;
    return m;
  }
}
