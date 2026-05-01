enum CalendarEventType { mealPlan, chore, recurringExpense }

class CalendarEvent {
  final String id;
  final CalendarEventType type;
  final String title;
  final DateTime date;
  final String groupId;
  final CalendarMealPlan? mealPlan;
  final CalendarChore? chore;
  final CalendarRecurringExpense? recurringExpense;

  const CalendarEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.groupId,
    this.mealPlan,
    this.chore,
    this.recurringExpense,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    final type = CalendarEventType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => CalendarEventType.mealPlan,
    );
    return CalendarEvent(
      id: json['id'] as String,
      type: type,
      title: json['title'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      groupId: json['group_id'] as String,
      mealPlan: json['meal_plan'] != null
          ? CalendarMealPlan.fromJson(
              (json['meal_plan'] as Map).cast<String, dynamic>())
          : null,
      chore: json['chore'] != null
          ? CalendarChore.fromJson(
              (json['chore'] as Map).cast<String, dynamic>())
          : null,
      recurringExpense: json['recurring_expense'] != null
          ? CalendarRecurringExpense.fromJson(
              (json['recurring_expense'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}

class CalendarMealPlan {
  final String mealPlanId;
  final String slot;
  final String recipeId;
  final int servings;
  final String? cookUserId;

  const CalendarMealPlan({
    required this.mealPlanId,
    required this.slot,
    required this.recipeId,
    required this.servings,
    this.cookUserId,
  });

  factory CalendarMealPlan.fromJson(Map<String, dynamic> json) =>
      CalendarMealPlan(
        mealPlanId: json['meal_plan_id'] as String,
        slot: json['slot'] as String,
        recipeId: json['recipe_id'] as String,
        servings: json['servings'] as int? ?? 1,
        cookUserId: json['cook_user_id'] as String?,
      );
}

class CalendarChore {
  final String choreId;
  final String assignmentId;
  final String userId;
  final String status;

  const CalendarChore({
    required this.choreId,
    required this.assignmentId,
    required this.userId,
    required this.status,
  });

  factory CalendarChore.fromJson(Map<String, dynamic> json) => CalendarChore(
        choreId: json['chore_id'] as String,
        assignmentId: json['assignment_id'] as String,
        userId: json['user_id'] as String,
        status: json['status'] as String,
      );
}

class CalendarRecurringExpense {
  final String recurringExpenseId;
  final String payerId;
  final int amount;
  final String currency;
  final String frequency;

  const CalendarRecurringExpense({
    required this.recurringExpenseId,
    required this.payerId,
    required this.amount,
    required this.currency,
    required this.frequency,
  });

  factory CalendarRecurringExpense.fromJson(Map<String, dynamic> json) =>
      CalendarRecurringExpense(
        recurringExpenseId: json['recurring_expense_id'] as String,
        payerId: json['payer_id'] as String,
        amount: json['amount'] as int,
        currency: json['currency'] as String? ?? 'EUR',
        frequency: json['frequency'] as String,
      );
}
