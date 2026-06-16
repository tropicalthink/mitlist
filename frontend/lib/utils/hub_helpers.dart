import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/activity_models.dart';

String formatActivityLine(ActivityLogModel a, AppLocalizations l10n) {
  final when = relativeDay(a.createdAt);

  String? name = a.title;
  if (name == null && a.metadata is Map) {
    final m = a.metadata as Map;
    name = (m['name'] ?? m['title'] ?? m['item_name']) as String?;
  }
  final list = a.context;

  switch (a.action) {
    case 'list_item_added':
      if (name != null && list != null) {
        return l10n.activityAddedToNamedList(name, list, when);
      }
      return name != null
          ? l10n.activityAddedToList(name, when)
          : l10n.activityAddedItemToList(when);
    case 'expense_created':
      return name != null
          ? l10n.activityLoggedExpense(name, when)
          : l10n.activityLoggedExpenseGeneric(when);
    case 'chore_completed':
      return name != null
          ? l10n.activityCompletedChore(name, when)
          : l10n.activityCompletedChoreGeneric(when);
    case 'recipe_added':
      return name != null
          ? l10n.activitySavedRecipe(name, when)
          : l10n.activitySavedRecipeGeneric(when);
    case 'meal_plan_created':
      return name != null
          ? l10n.activityPlannedMeal(name, when)
          : l10n.activityUpdatedMealPlan(when);
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

String formatUserLabel(String id, String? currentUserId, AppLocalizations l10n,
    {String? name}) {
  if (id.isNotEmpty && id == currentUserId) return l10n.activityYou;
  if (name != null && name.trim().isNotEmpty) return name.trim();
  return l10n.activityMember;
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
