class NotificationModel {
  final String id;
  final String userId;
  final String? groupId;
  final String type;
  final String title;
  final String body;
  final dynamic data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    this.groupId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.readAt,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      groupId: json['group_id'] as String?,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      data: json['data'],
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class NotificationPreferenceModel {
  final String id;
  final String userId;
  final String groupId;
  final bool choreDue;
  final bool choreDueDayOf;
  final bool listItemAdded;
  final bool expenseCreated;
  final bool mealPlanChanged;
  final bool weeklyDigest;
  final bool pinwallReminder;
  final bool pushEnabled;
  final bool emailEnabled;

  const NotificationPreferenceModel({
    required this.id,
    required this.userId,
    required this.groupId,
    this.choreDue = true,
    this.choreDueDayOf = true,
    this.listItemAdded = true,
    this.expenseCreated = true,
    this.mealPlanChanged = true,
    this.weeklyDigest = true,
    this.pinwallReminder = true,
    this.pushEnabled = true,
    this.emailEnabled = false,
  });

  factory NotificationPreferenceModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferenceModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      groupId: json['group_id'] as String,
      choreDue: json['chore_due'] as bool? ?? true,
      choreDueDayOf: json['chore_due_day_of'] as bool? ?? true,
      listItemAdded: json['list_item_added'] as bool? ?? true,
      expenseCreated: json['expense_created'] as bool? ?? true,
      mealPlanChanged: json['meal_plan_changed'] as bool? ?? true,
      weeklyDigest: json['weekly_digest'] as bool? ?? true,
      pinwallReminder: json['pinwall_reminder'] as bool? ?? true,
      pushEnabled: json['push_enabled'] as bool? ?? true,
      emailEnabled: json['email_enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'group_id': groupId,
        'chore_due': choreDue,
        'chore_due_day_of': choreDueDayOf,
        'list_item_added': listItemAdded,
        'expense_created': expenseCreated,
        'meal_plan_changed': mealPlanChanged,
        'weekly_digest': weeklyDigest,
        'pinwall_reminder': pinwallReminder,
        'push_enabled': pushEnabled,
        'email_enabled': emailEnabled,
      };
}
