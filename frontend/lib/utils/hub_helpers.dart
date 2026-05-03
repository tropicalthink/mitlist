import 'package:intl/intl.dart';

import '../models/activity_models.dart';

String formatActivityLine(ActivityLogModel a) {
  final when = relativeDay(a.createdAt);
  switch (a.action) {
    case 'list_item_added':
      return 'Added an item to a list \u00b7 $when';
    case 'expense_created':
      return 'Logged an expense \u00b7 $when';
    case 'chore_completed':
      return 'Completed a chore \u00b7 $when';
    case 'recipe_added':
      return 'Saved a recipe \u00b7 $when';
    case 'meal_plan_created':
      return 'Updated meal plan \u00b7 $when';
    default:
      return '${a.action} \u00b7 $when';
  }
}

String relativeDay(DateTime t) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(t.year, t.month, t.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return 'yesterday';
  if (diff < 7) return '$diff days ago';
  return DateFormat.MMMd().format(t);
}

String formatUserLabel(String id, String? currentUserId) {
  if (id == currentUserId) return 'You';
  return 'Member';
}

String avatarInitials(String label) {
  final parts = label.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return label.isNotEmpty ? label[0].toUpperCase() : '?';
}

bool isNavigableAction(String entityType) {
  return const {
    'list',
    'expense',
    'chore',
    'recipe',
    'meal_plan',
  }.contains(entityType);
}
