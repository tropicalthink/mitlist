import 'package:flutter/foundation.dart';

import '../../models/list_models.dart';

/// The editable values of one list item, as a step saw them before or after
/// a change. Data only: undo and redo compare these against the live row and
/// write the other side back.
@immutable
class ListItemFields {
  const ListItemFields({
    required this.name,
    required this.quantity,
    required this.unit,
    this.note = '',
    this.priceCents,
    required this.checked,
    required this.position,
    this.canonicalItemId,
  });

  factory ListItemFields.of(ListItem item) => ListItemFields(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        note: item.note,
        priceCents: item.priceCents,
        checked: item.checked,
        position: item.position,
        canonicalItemId: item.canonicalItemId,
      );

  final String name;
  final double quantity;
  final String unit;
  final String note;

  /// Null and 0 both mean "no price" (the API clears a price with 0).
  final int? priceCents;
  final bool checked;
  final int position;

  /// On-device grocery link. Not something a person edits, but a rename
  /// drops it, so undoing the rename has to put it back.
  final String? canonicalItemId;

  int get _price => priceCents ?? 0;

  /// True when everything a person can see or edit matches [other]. Position
  /// and the canonical link are left out: a housemate's reorder or the
  /// background linker moving them is not an edit that undo would lose.
  bool sameContentAs(ListItemFields other) =>
      name == other.name &&
      quantity == other.quantity &&
      unit == other.unit &&
      note == other.note &&
      _price == other._price &&
      checked == other.checked;

  @override
  bool operator ==(Object other) =>
      other is ListItemFields &&
      sameContentAs(other) &&
      position == other.position &&
      canonicalItemId == other.canonicalItemId;

  @override
  int get hashCode => Object.hash(
      name, quantity, unit, note, _price, checked, position, canonicalItemId);

  @override
  String toString() => 'ListItemFields($name, $quantity $unit, '
      'checked: $checked, position: $position)';
}

/// One change made on the list screen that can be undone and redone. Each
/// step records only data: the controller applies it through the
/// offline-first repository and checks first that nobody else has moved the
/// target on since.
@immutable
sealed class ListUndoStep {
  const ListUndoStep();

  /// Every item id the step refers to.
  Iterable<String> get itemIds;

  /// This step with [from] replaced by [to] wherever it names an item: an
  /// item created on this device moves to the server's id once it syncs.
  ListUndoStep remapItemId(String from, String to);
}

/// Name, quantity, unit, price, note (one inline edit session or one sheet
/// save), or a ticked item brought back by re-adding it.
final class ItemFieldsChangedStep extends ListUndoStep {
  const ItemFieldsChangedStep({
    required this.itemId,
    required this.before,
    required this.after,
  });

  final String itemId;
  final ListItemFields before;
  final ListItemFields after;

  @override
  Iterable<String> get itemIds => [itemId];

  @override
  ItemFieldsChangedStep remapItemId(String from, String to) => itemId == from
      ? ItemFieldsChangedStep(itemId: to, before: before, after: after)
      : this;
}

/// An add that landed on a row already on the list and raised its quantity
/// ("2 milk" onto "Milk"), unticking it if it was ticked.
final class QuantityMergedStep extends ListUndoStep {
  const QuantityMergedStep({
    required this.itemId,
    required this.before,
    required this.after,
  });

  final String itemId;
  final ListItemFields before;
  final ListItemFields after;

  @override
  Iterable<String> get itemIds => [itemId];

  @override
  QuantityMergedStep remapItemId(String from, String to) => itemId == from
      ? QuantityMergedStep(itemId: to, before: before, after: after)
      : this;
}

/// One tick or untick, or "check all" / "uncheck all": [itemIds] all went to
/// [checked] at [at].
final class ItemsCheckedStep extends ListUndoStep {
  const ItemsCheckedStep({
    required this.itemIds,
    required this.checked,
    required this.at,
  });

  @override
  final List<String> itemIds;
  final bool checked;

  /// When the change was made: undoing a tick withdraws the purchase that
  /// tick recorded, which is the one recorded since then.
  final DateTime at;

  @override
  ItemsCheckedStep remapItemId(String from, String to) => itemIds.contains(from)
      ? ItemsCheckedStep(
          itemIds: [for (final id in itemIds) id == from ? to : id],
          checked: checked,
          at: at,
        )
      : this;
}

/// A new row. [item] is the row as the add left it, so redo can put it back
/// exactly (same id, position, canonical link).
final class ItemAddedStep extends ListUndoStep {
  const ItemAddedStep({required this.item});

  final ListItem item;

  @override
  Iterable<String> get itemIds => [item.id];

  @override
  ItemAddedStep remapItemId(String from, String to) =>
      item.id == from ? ItemAddedStep(item: listItemWithId(item, to)) : this;
}

/// One row removed (swipe, emptied name, remove button). [item] is the row
/// just before it went.
final class ItemDeletedStep extends ListUndoStep {
  const ItemDeletedStep({required this.item});

  final ListItem item;

  @override
  Iterable<String> get itemIds => [item.id];

  @override
  ItemDeletedStep remapItemId(String from, String to) =>
      item.id == from ? ItemDeletedStep(item: listItemWithId(item, to)) : this;
}

/// "Clear checked" or "Clear all". [items] are the rows removed; [clearOpId]
/// the queued clear op that will tell the server, so an undo made before it
/// syncs can simply withdraw it.
final class ItemsClearedStep extends ListUndoStep {
  const ItemsClearedStep({
    required this.items,
    required this.onlyChecked,
    this.clearOpId,
  });

  final List<ListItem> items;
  final bool onlyChecked;
  final String? clearOpId;

  @override
  Iterable<String> get itemIds => items.map((item) => item.id);

  @override
  ItemsClearedStep remapItemId(String from, String to) =>
      items.any((item) => item.id == from)
          ? ItemsClearedStep(
              items: [
                for (final item in items)
                  item.id == from ? listItemWithId(item, to) : item,
              ],
              onlyChecked: onlyChecked,
              clearOpId: clearOpId,
            )
          : this;
}

/// A drag in the open section: the whole list's order before and after.
final class ItemsReorderedStep extends ListUndoStep {
  const ItemsReorderedStep({required this.before, required this.after});

  final List<String> before;
  final List<String> after;

  @override
  Iterable<String> get itemIds => {...before, ...after};

  @override
  ItemsReorderedStep remapItemId(String from, String to) =>
      before.contains(from) || after.contains(from)
          ? ItemsReorderedStep(
              before: [for (final id in before) id == from ? to : id],
              after: [for (final id in after) id == from ? to : id],
            )
          : this;
}

final class ListRenamedStep extends ListUndoStep {
  const ListRenamedStep({required this.before, required this.after});

  final String before;
  final String after;

  @override
  Iterable<String> get itemIds => const [];

  @override
  ListRenamedStep remapItemId(String from, String to) => this;
}

/// A reminder set, moved or cleared. Null means no reminder.
final class ReminderChangedStep extends ListUndoStep {
  const ReminderChangedStep({required this.before, required this.after});

  final DateTime? before;
  final DateTime? after;

  @override
  Iterable<String> get itemIds => const [];

  @override
  ReminderChangedStep remapItemId(String from, String to) => this;
}

/// [item] under another id, everything else kept.
ListItem listItemWithId(ListItem item, String id) => ListItem(
      id: id,
      listId: item.listId,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      note: item.note,
      priceCents: item.priceCents,
      canonicalItemId: item.canonicalItemId,
      checked: item.checked,
      position: item.position,
      claimedBy: item.claimedBy,
      addedBy: item.addedBy,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );

/// Undo and redo history of one visit to a list ("like Google Keep"). In
/// memory only: the screen creates one per visit and drops it on leaving.
///
/// The controller drives it: [push] after each change it makes, then for an
/// undo [takeUndo], apply, and [pushRedo] (or [returnUndo] when applying
/// failed and should be tried again; a step skipped because someone else
/// changed the target is simply dropped). Redo mirrors that with [takeRedo],
/// [pushUndo] and [returnRedo].
class ListUndoStack extends ChangeNotifier {
  ListUndoStack({this.capacity = defaultCapacity}) : assert(capacity > 0);

  /// Generous: a long shopping session stays undoable to its start.
  static const int defaultCapacity = 200;

  final int capacity;
  final List<ListUndoStep> _undo = [];
  final List<ListUndoStep> _redo = [];
  bool _hasHistory = false;
  bool _disposed = false;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// True once the visit made its first change, even if it has since all
  /// been undone: the arrows stay in place instead of popping in and out.
  bool get hasHistory => _hasHistory;

  int get undoDepth => _undo.length;
  int get redoDepth => _redo.length;

  /// The step the next undo would apply, if any.
  ListUndoStep? get nextUndo => _undo.isEmpty ? null : _undo.last;

  /// The step the next redo would apply, if any.
  ListUndoStep? get nextRedo => _redo.isEmpty ? null : _redo.last;

  /// Records a new change. A new change ends the redo history.
  void push(ListUndoStep step) {
    _add(_undo, step);
    _redo.clear();
    _hasHistory = true;
    _changed();
  }

  /// Removes and returns the newest undoable step.
  ListUndoStep? takeUndo() {
    if (_undo.isEmpty) return null;
    final step = _undo.removeLast();
    _changed();
    return step;
  }

  /// Removes and returns the newest redoable step.
  ListUndoStep? takeRedo() {
    if (_redo.isEmpty) return null;
    final step = _redo.removeLast();
    _changed();
    return step;
  }

  /// [step] was undone: it can be redone.
  void pushRedo(ListUndoStep step) {
    _add(_redo, step);
    _changed();
  }

  /// [step] was redone: it can be undone again. Unlike [push], the rest of
  /// the redo history stays.
  void pushUndo(ListUndoStep step) {
    _add(_undo, step);
    _hasHistory = true;
    _changed();
  }

  /// Applying [step] (taken by [takeUndo]) failed: it goes back on top.
  void returnUndo(ListUndoStep step) => pushUndo(step);

  /// Applying [step] (taken by [takeRedo]) failed: it goes back on top.
  void returnRedo(ListUndoStep step) => pushRedo(step);

  /// Points every step at [to] where it named [from].
  void remapItemId(String from, String to) {
    if (from == to) return;
    for (final stack in [_undo, _redo]) {
      for (var i = 0; i < stack.length; i++) {
        stack[i] = stack[i].remapItemId(from, to);
      }
    }
  }

  void clear() {
    if (_undo.isEmpty && _redo.isEmpty && !_hasHistory) return;
    _undo.clear();
    _redo.clear();
    _hasHistory = false;
    _changed();
  }

  void _add(List<ListUndoStep> stack, ListUndoStep step) {
    stack.add(step);
    if (stack.length > capacity) stack.removeRange(0, stack.length - capacity);
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
