import 'dart:convert';

import '../l10n/app_localizations.dart';

class NotificationText {
  const NotificationText({required this.title, required this.body});

  final String title;
  final String body;
}

NotificationText resolveNotificationText({
  required AppLocalizations l10n,
  required String fallbackTitle,
  required String fallbackBody,
  required dynamic data,
}) {
  final payload = _asMap(data);
  final copy = _asMap(payload?['copy']);
  if (copy == null || copy['version'] != 1) {
    return NotificationText(title: fallbackTitle, body: fallbackBody);
  }
  final template = copy['template'];
  final params = _stringMap(copy['params']);
  if (template is! String || params == null) {
    return NotificationText(title: fallbackTitle, body: fallbackBody);
  }

  String? value(String key) {
    final result = params[key]?.trim();
    return result == null || result.isEmpty ? null : result;
  }

  final actor = value('actor_name');
  final group = value('group_name');
  final amount = value('amount');
  switch (template) {
    case 'chore_due_soon':
      final chore = value('chore_name');
      if (chore != null) {
        return NotificationText(
          title: l10n.notificationChoreDueSoonTitle,
          body: l10n.notificationChoreDueSoonBody(chore),
        );
      }
      break;
    case 'chore_due_today':
      final chore = value('chore_name');
      if (chore != null) {
        return NotificationText(
          title: l10n.notificationChoreDueTodayTitle,
          body: l10n.notificationChoreDueTodayBody(chore),
        );
      }
      break;
    case 'list_items_added':
      final list = value('list_name');
      final item = value('last_item_name');
      final itemNames = value('item_names');
      final count = int.tryParse(value('item_count') ?? '');
      if (actor != null &&
          list != null &&
          item != null &&
          group != null &&
          count != null &&
          count > 0) {
        final String body;
        if (count == 1) {
          body = l10n.notificationListUpdatedOneBody(actor, item, list, group);
        } else if (itemNames != null) {
          body = l10n.notificationListUpdatedManyNamesBody(
              actor, count, list, group, itemNames);
        } else {
          body = l10n.notificationListUpdatedManyBody(actor, count, list, group);
        }
        return NotificationText(
          title: l10n.notificationListUpdatedTitle(list),
          body: body,
        );
      }
      break;
    case 'expense_created':
      final expense = value('expense_name');
      if (actor != null && expense != null && group != null) {
        return NotificationText(
          title: l10n.notificationExpenseCreatedTitle,
          body: l10n.notificationExpenseCreatedBody(actor, expense, group),
        );
      }
      break;
    case 'recurring_expense_created':
      final expense = value('expense_name');
      if (expense != null) {
        return NotificationText(
          title: l10n.notificationRecurringExpenseTitle,
          body: l10n.notificationRecurringExpenseBody(expense),
        );
      }
      break;
    case 'settlement_requested_paid_you':
      if (actor != null && amount != null && group != null) {
        return NotificationText(
          title: l10n.notificationSettlementRequestTitle,
          body: l10n.notificationSettlementPaidYouBody(actor, amount, group),
        );
      }
      break;
    case 'settlement_requested_you_paid':
      if (actor != null && amount != null && group != null) {
        return NotificationText(
          title: l10n.notificationSettlementRequestTitle,
          body: l10n.notificationSettlementYouPaidBody(actor, amount, group),
        );
      }
      break;
    case 'settlement_confirmed':
      if (actor != null && amount != null && group != null) {
        return NotificationText(
          title: l10n.notificationSettlementConfirmedTitle,
          body: l10n.notificationSettlementConfirmedBody(actor, amount, group),
        );
      }
      break;
    case 'settlement_declined':
      if (actor != null && amount != null && group != null) {
        return NotificationText(
          title: l10n.notificationSettlementDeclinedTitle,
          body: l10n.notificationSettlementDeclinedBody(actor, amount, group),
        );
      }
      break;
    case 'meal_plan_changed':
      if (actor != null && group != null) {
        return NotificationText(
          title: l10n.notificationMealPlanTitle,
          body: l10n.notificationMealPlanBody(actor, group),
        );
      }
      break;
    case 'weekly_digest':
      final count = int.tryParse(value('activity_count') ?? '');
      if (count != null && count >= 0) {
        return NotificationText(
          title: l10n.notificationWeeklyDigestTitle,
          body: l10n.notificationWeeklyDigestBody(count),
        );
      }
      break;
    case 'pinwall_reminder':
      final content = value('content');
      if (content != null) {
        return NotificationText(
          title: l10n.notificationPinwallReminderTitle,
          body: content,
        );
      }
      break;
  }
  return NotificationText(title: fallbackTitle, body: fallbackBody);
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }
  return null;
}

Map<String, String>? _stringMap(dynamic value) {
  final map = _asMap(value);
  if (map == null) return null;
  final result = <String, String>{};
  for (final entry in map.entries) {
    if (entry.value is! String) return null;
    result[entry.key] = entry.value as String;
  }
  return result;
}
