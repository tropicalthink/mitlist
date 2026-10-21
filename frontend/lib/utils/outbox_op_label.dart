import 'dart:convert';

import '../l10n/app_localizations.dart';
import '../storage/app_database.dart';

/// Product area an outbox op belongs to, for picking a leading icon.
enum OutboxOpDomain { list, money, chores, recipes, pinboard, telemetry, other }

/// Maps an outbox op type to its product area.
OutboxOpDomain outboxOpDomain(OutboxOp op) {
  switch (op.type) {
    case 'createItem':
    case 'updateItem':
    case 'deleteItem':
    case 'reorderItems':
    case 'addItemAmount':
    case 'clearItems':
    case 'createList':
    case 'updateList':
    case 'archiveList':
    case 'deleteList':
    case 'setListReminder':
    case 'createProduct':
    case 'createShoppingLocation':
      return OutboxOpDomain.list;
    case 'createExpense':
    case 'updateExpense':
    case 'deleteExpense':
    case 'createSettlement':
    case 'cancelSettlement':
    case 'createRecurringExpense':
    case 'updateRecurringExpense':
    case 'deleteRecurringExpense':
      return OutboxOpDomain.money;
    case 'createChore':
    case 'completeChore':
    case 'skipChore':
    case 'rescheduleChore':
    case 'undoChore':
    case 'updateChore':
    case 'deleteChore':
    case 'createChoreSubtask':
    case 'updateChoreSubtask':
    case 'deleteChoreSubtask':
      return OutboxOpDomain.chores;
    case 'createRecipe':
    case 'updateRecipe':
    case 'deleteRecipe':
    case 'createMealPlan':
    case 'updateMealPlan':
    case 'deleteMealPlan':
    case 'createCollection':
    case 'updateCollection':
    case 'deleteCollection':
    case 'addRecipeToCollection':
    case 'removeRecipeFromCollection':
      return OutboxOpDomain.recipes;
    case 'createPinwallPost':
    case 'updatePinwallPost':
    case 'deletePinwallPost':
    case 'updatePinwallPostPosition':
      return OutboxOpDomain.pinboard;
    case 'recordPurchase':
      return OutboxOpDomain.telemetry;
  }
  return switch (op.entityType) {
    'listItem' ||
    'list' ||
    'product' ||
    'shoppingLocation' =>
      OutboxOpDomain.list,
    'expense' || 'settlement' || 'recurringExpense' => OutboxOpDomain.money,
    'chore' || 'choreSubtask' => OutboxOpDomain.chores,
    'recipe' || 'mealPlan' || 'cookbook' => OutboxOpDomain.recipes,
    'pinwallPost' => OutboxOpDomain.pinboard,
    'groceryPurchase' => OutboxOpDomain.telemetry,
    _ => OutboxOpDomain.other,
  };
}

/// The list item id an `updateItem` op targets, for looking up its name in
/// the local cache (the op payload carries only the patch, not the name).
/// Null for every other op type.
String? outboxOpItemIdForNameLookup(OutboxOp op) {
  if (op.type == 'widgetRequest') {
    final payload = _decode(op.payloadJson);
    final itemId = payload?['itemId'];
    return payload?['type'] == 'list_item.check' && itemId is String
        ? itemId
        : null;
  }
  if (op.type != 'updateItem') return null;
  if (op.entityId != null && op.entityId!.isNotEmpty) return op.entityId;
  final itemId = _decode(op.payloadJson)?['itemId'];
  return itemId is String && itemId.isNotEmpty ? itemId : null;
}

/// Human-readable summary of what an outbox op is doing, e.g.
/// "Add item — Milk" or "Check off — Milk".
///
/// The entity name comes from the payload when present; pass [itemName]
/// (resolved from the local cache via [outboxOpItemIdForNameLookup]) for ops
/// whose payload does not carry one, such as `updateItem`.
String outboxOpLabel(
  AppLocalizations l10n,
  OutboxOp op, {
  String? itemName,
}) {
  final payload = _decode(op.payloadJson);
  final verb = switch (op.type) {
    'createItem' => l10n.sheetFailedChangesOpAddItem,
    'updateItem' => _updateItemVerb(l10n, payload),
    'deleteItem' => l10n.sheetFailedChangesOpDeleteItem,
    'reorderItems' => l10n.sheetFailedChangesOpReorderItems,
    'addItemAmount' => l10n.outboxOpAddItemAmount,
    'clearItems' => payload?['onlyChecked'] == true
        ? l10n.outboxOpClearCheckedItems
        : l10n.outboxOpClearItems,
    'recordPurchase' => l10n.outboxOpRecordPurchase,
    'createList' => l10n.outboxOpCreateList,
    'updateList' => l10n.outboxOpUpdateList,
    'archiveList' => l10n.outboxOpArchiveList,
    'deleteList' => l10n.outboxOpDeleteList,
    'setListReminder' => l10n.outboxOpSetListReminder,
    'createProduct' => l10n.outboxOpAddProduct,
    'createShoppingLocation' => l10n.outboxOpAddShoppingLocation,
    'createExpense' => l10n.sheetFailedChangesOpCreateExpense,
    'updateExpense' => l10n.sheetFailedChangesOpUpdateExpense,
    'deleteExpense' => l10n.sheetFailedChangesOpDeleteExpense,
    'createSettlement' => l10n.outboxOpCreateSettlement,
    'cancelSettlement' => l10n.outboxOpCancelSettlement,
    'createRecurringExpense' => l10n.outboxOpCreateRecurringExpense,
    'updateRecurringExpense' => l10n.outboxOpUpdateRecurringExpense,
    'deleteRecurringExpense' => l10n.outboxOpDeleteRecurringExpense,
    'createRecipe' => l10n.sheetFailedChangesOpCreateRecipe,
    'updateRecipe' => l10n.sheetFailedChangesOpUpdateRecipe,
    'deleteRecipe' => l10n.sheetFailedChangesOpDeleteRecipe,
    'createMealPlan' => l10n.outboxOpAddMeal,
    'updateMealPlan' => l10n.outboxOpUpdateMeal,
    'deleteMealPlan' => l10n.outboxOpRemoveMeal,
    'createCollection' => l10n.outboxOpCreateCookbook,
    'updateCollection' => l10n.outboxOpUpdateCookbook,
    'deleteCollection' => l10n.outboxOpDeleteCookbook,
    'addRecipeToCollection' => l10n.outboxOpAddToCookbook,
    'removeRecipeFromCollection' => l10n.outboxOpRemoveFromCookbook,
    'createChore' => l10n.outboxOpCreateChore,
    'completeChore' => l10n.sheetFailedChangesOpCompleteChore,
    'skipChore' => l10n.sheetFailedChangesOpSkipChore,
    'rescheduleChore' => l10n.sheetFailedChangesOpRescheduleChore,
    'undoChore' => l10n.sheetFailedChangesOpUndoChore,
    'updateChore' => l10n.outboxOpUpdateChore,
    'deleteChore' => l10n.outboxOpDeleteChore,
    'createChoreSubtask' => l10n.outboxOpAddSubtask,
    'updateChoreSubtask' => l10n.outboxOpUpdateSubtask,
    'deleteChoreSubtask' => l10n.outboxOpDeleteSubtask,
    'createPinwallPost' => l10n.sheetFailedChangesOpCreatePinwallPost,
    'deletePinwallPost' => l10n.sheetFailedChangesOpDeletePinwallPost,
    'updatePinwallPost' => l10n.sheetFailedChangesOpUpdatePinwallPost,
    'updatePinwallPostPosition' => l10n.outboxOpMovePinwallPost,
    'setLanguage' => l10n.outboxOpSetLanguage,
    'updateGroup' => l10n.outboxOpUpdateHousehold,
    'updateProfile' => l10n.outboxOpUpdateProfile,
    'markNotificationRead' => l10n.outboxOpMarkNotificationRead,
    'markAllNotificationsRead' => l10n.outboxOpMarkAllNotificationsRead,
    'deleteNotification' => l10n.outboxOpDeleteNotification,
    'updateNotificationPreference' => l10n.outboxOpUpdateNotificationPreference,
    // Replayed from a home screen widget, Siri or the quick add (plans/047).
    'widgetRequest' => switch (payload?['type']) {
        'list_item.check' => l10n.outboxOpCheckItem,
        'list_item.add' => l10n.sheetFailedChangesOpAddItem,
        'chore.complete' => l10n.sheetFailedChangesOpCompleteChore,
        _ => l10n.sheetFailedChangesOpChange,
      },
    _ => l10n.sheetFailedChangesOpChange,
  };
  final name = _payloadName(payload) ?? _clean(itemName);
  return name == null ? verb : '$verb — $name';
}

String _updateItemVerb(AppLocalizations l10n, Map<String, dynamic>? payload) {
  final patch = payload?['patch'];
  if (patch is Map) {
    final keys = patch.keys.where((k) => patch[k] != null).toSet();
    if (keys.length == 1 && keys.first == 'checked') {
      return patch['checked'] == true
          ? l10n.outboxOpCheckItem
          : l10n.outboxOpUncheckItem;
    }
  }
  return l10n.sheetFailedChangesOpUpdateItem;
}

Map<String, dynamic>? _decode(String payloadJson) {
  try {
    final decoded = jsonDecode(payloadJson);
    if (decoded is Map) return decoded.cast<String, dynamic>();
  } catch (_) {
    // Best-effort label only.
  }
  return null;
}

String? _payloadName(Map<String, dynamic>? payload) {
  if (payload == null) return null;
  final direct = _nameIn(payload, const ['name', 'content', 'title']);
  if (direct != null) return direct;
  // Create ops wrap the API request (`{'tempId': …, 'request': {...}}`).
  final request = payload['request'];
  if (request is Map) {
    return _nameIn(request.cast<String, dynamic>(),
        const ['name', 'title', 'description', 'content']);
  }
  return null;
}

String? _nameIn(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final name = _clean(map[key]);
    if (name != null) return name;
  }
  return null;
}

String? _clean(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}
