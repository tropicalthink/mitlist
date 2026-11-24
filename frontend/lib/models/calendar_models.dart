enum CalendarEventType {
  mealPlan,
  chore,
  recurringExpense,
  pinwallReminder,
  listReminder,
  expense,

  /// A housemate's own calendar event, shared with the household (server
  /// `external_event`, only sent with `include=external`).
  externalEvent
}

class CalendarEvent {
  final String id;
  final CalendarEventType type;
  final String title;
  final DateTime date;
  final String groupId;
  final CalendarMealPlan? mealPlan;
  final CalendarChore? chore;
  final CalendarRecurringExpense? recurringExpense;
  final CalendarExpense? expense;
  final CalendarPinwallReminder? pinwallReminder;
  final CalendarListReminder? listReminder;
  final CalendarExternalEvent? external;

  const CalendarEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.groupId,
    this.mealPlan,
    this.chore,
    this.recurringExpense,
    this.expense,
    this.pinwallReminder,
    this.listReminder,
    this.external,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String;
    // Server types are snake_case ("list_reminder"); enum names are camelCase
    // ("listReminder"). Compare with underscores stripped, case-insensitively.
    final wanted = typeStr.replaceAll('_', '').toLowerCase();
    final type = CalendarEventType.values.firstWhere(
      (e) => e.name.toLowerCase() == wanted,
      orElse: () => CalendarEventType.mealPlan,
    );
    final external = json['external'] is Map
        ? CalendarExternalEvent.fromJson(
            (json['external'] as Map).cast<String, dynamic>())
        : null;
    // A busy-only block never carries a title, whatever the payload says.
    final rawTitle = json['title'] as String? ?? '';
    final title = type == CalendarEventType.externalEvent &&
            (external == null || external.busyOnly)
        ? ''
        : rawTitle;
    return CalendarEvent(
      id: json['id'] as String,
      type: type,
      title: title,
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
      expense: json['expense'] != null
          ? CalendarExpense.fromJson(
              (json['expense'] as Map).cast<String, dynamic>())
          : null,
      pinwallReminder: json['pinwall_reminder'] != null
          ? CalendarPinwallReminder.fromJson(
              (json['pinwall_reminder'] as Map).cast<String, dynamic>())
          : null,
      listReminder: json['list_reminder'] != null
          ? CalendarListReminder.fromJson(
              (json['list_reminder'] as Map).cast<String, dynamic>())
          : null,
      external: external,
    );
  }
}

/// What a housemate's shared calendar says about one event. All-day events
/// carry UTC midnights of their local dates, [endsAt] exclusive; use
/// [startDay] and [endDayExclusive] rather than converting them.
class CalendarExternalEvent {
  final String userId;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool allDay;

  /// True when the household may see only that the person is busy.
  final bool busyOnly;

  /// Marked "free" (transparent) in the source calendar.
  final bool free;

  const CalendarExternalEvent({
    required this.userId,
    required this.startsAt,
    required this.endsAt,
    required this.allDay,
    required this.busyOnly,
    required this.free,
  });

  factory CalendarExternalEvent.fromJson(Map<String, dynamic> json) {
    final starts = DateTime.parse(json['starts_at'] as String);
    final ends = DateTime.tryParse(json['ends_at'] as String? ?? '') ?? starts;
    return CalendarExternalEvent(
      userId: json['user_id'] as String? ?? '',
      startsAt: starts,
      endsAt: ends.isBefore(starts) ? starts : ends,
      allDay: json['all_day'] as bool? ?? false,
      // Missing means the server did not say titles are allowed: busy.
      busyOnly: json['busy_only'] as bool? ?? true,
      free: json['free'] as bool? ?? false,
    );
  }

  /// First local calendar day the event covers.
  DateTime get startDay {
    if (allDay) {
      final u = startsAt.toUtc();
      return DateTime(u.year, u.month, u.day);
    }
    final l = startsAt.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  /// The local day after the last day the event covers.
  DateTime get endDayExclusive {
    if (allDay) {
      final u = endsAt.toUtc();
      final end = DateTime(u.year, u.month, u.day);
      return end.isAfter(startDay) ? end : _nextDay(startDay);
    }
    final l = endsAt.toLocal();
    final endDay = DateTime(l.year, l.month, l.day);
    // A timed event ending exactly at midnight does not cover that day.
    final endsAtMidnight = l.hour == 0 &&
        l.minute == 0 &&
        l.second == 0 &&
        l.millisecond == 0 &&
        l.microsecond == 0;
    final last =
        endsAtMidnight && endDay.isAfter(startDay) ? endDay : _nextDay(endDay);
    return last.isAfter(startDay) ? last : _nextDay(startDay);
  }

  /// Every local day the event covers, in order (capped at a year so a bad
  /// payload cannot spin).
  List<DateTime> get days {
    final out = <DateTime>[];
    var d = startDay;
    final end = endDayExclusive;
    while (d.isBefore(end) && out.length < 366) {
      out.add(d);
      d = _nextDay(d);
    }
    return out;
  }

  static DateTime _nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);
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

class CalendarPinwallReminder {
  final String postId;
  final String userId;
  final String content;
  final bool sent;

  const CalendarPinwallReminder({
    required this.postId,
    required this.userId,
    required this.content,
    required this.sent,
  });

  factory CalendarPinwallReminder.fromJson(Map<String, dynamic> json) =>
      CalendarPinwallReminder(
        postId: json['post_id'] as String,
        userId: json['user_id'] as String,
        content: json['content'] as String,
        sent: json['sent'] as bool? ?? false,
      );
}

/// The one-time household reminder scheduled on a list (server
/// `list_reminder`). [sent] flips once the reminder job delivered it.
class CalendarListReminder {
  final String listId;
  final String listName;
  final String listType;
  final bool sent;

  const CalendarListReminder({
    required this.listId,
    required this.listName,
    required this.listType,
    required this.sent,
  });

  factory CalendarListReminder.fromJson(Map<String, dynamic> json) =>
      CalendarListReminder(
        listId: json['list_id'] as String,
        listName: json['list_name'] as String? ?? '',
        listType: json['list_type'] as String? ?? '',
        sent: json['sent'] as bool? ?? false,
      );
}

class CalendarExpense {
  final String expenseId;
  final String payerId;
  final int amount;
  final String currency;
  final String category;

  const CalendarExpense({
    required this.expenseId,
    required this.payerId,
    required this.amount,
    required this.currency,
    required this.category,
  });

  factory CalendarExpense.fromJson(Map<String, dynamic> json) =>
      CalendarExpense(
        expenseId: json['expense_id'] as String,
        payerId: json['payer_id'] as String,
        amount: json['amount'] as int,
        currency: json['currency'] as String? ?? 'EUR',
        category: json['category'] as String? ?? '',
      );
}
