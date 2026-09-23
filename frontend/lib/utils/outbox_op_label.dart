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
      return OutboxOpDomain.list;
    case 'createExpense':
    case 'updateExpense':
    case 'deleteExpense':
    case 'createSettlement':
      return OutboxOpDomain.money;
    case 'createChore':
    case 'completeChore':
    case 'skipChore':
    case 'rescheduleChore':
    case 'undoChore':
      return OutboxOpDomain.chores;
    case 'createRecipe':
    case 'updateRecipe':
    case 'deleteRecipe':
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
    'listItem' || 'list' => OutboxOpDomain.list,
    'expense' || 'settlement' => OutboxOpDomain.money,
    'chore' => OutboxOpDomain.chores,
    'recipe' => OutboxOpDomain.recipes,
    'pinwallPost' => OutboxOpDomain.pinboard,
    'groceryPurchase' => OutboxOpDomain.telemetry,
    _ => OutboxOpDomain.other,
  };
}

/// The list item id an `updateItem` op targets, for looking up its name in
/// the local cache (the op payload carries only the patch, not the name).
/// Null for every other op type.
String? outboxOpItemIdForNameLookup(OutboxOp op) {
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
    'createExpense' => l10n.sheetFailedChangesOpCreateExpense,
    'updateExpense' => l10n.sheetFailedChangesOpUpdateExpense,
    'deleteExpense' => l10n.sheetFailedChangesOpDeleteExpense,
    'createSettlement' => l10n.outboxOpCreateSettlement,
    'createRecipe' => l10n.sheetFailedChangesOpCreateRecipe,
    'updateRecipe' => l10n.sheetFailedChangesOpUpdateRecipe,
    'deleteRecipe' => l10n.sheetFailedChangesOpDeleteRecipe,
    'createChore' => l10n.outboxOpCreateChore,
    'completeChore' => l10n.sheetFailedChangesOpCompleteChore,
    'skipChore' => l10n.sheetFailedChangesOpSkipChore,
    'rescheduleChore' => l10n.sheetFailedChangesOpRescheduleChore,
    'undoChore' => l10n.sheetFailedChangesOpUndoChore,
    'createPinwallPost' => l10n.sheetFailedChangesOpCreatePinwallPost,
    'deletePinwallPost' => l10n.sheetFailedChangesOpDeletePinwallPost,
    'updatePinwallPost' => l10n.sheetFailedChangesOpUpdatePinwallPost,
    'updatePinwallPostPosition' => l10n.outboxOpMovePinwallPost,
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
