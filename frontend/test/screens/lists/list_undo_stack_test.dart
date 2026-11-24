import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/screens/lists/list_undo_stack.dart';

ListItem _item(String id, {int position = 0, bool checked = false}) => ListItem(
      id: id,
      listId: 'list-1',
      name: 'Item $id',
      quantity: 1,
      unit: '',
      checked: checked,
      position: position,
      canonicalItemId: 'canon-$id',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

ListUndoStep _renamed(String to) =>
    ListRenamedStep(before: 'before $to', after: to);

void main() {
  group('ListUndoStack', () {
    test('starts empty and hidden', () {
      final stack = ListUndoStack();
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isFalse);
      expect(stack.hasHistory, isFalse);
      expect(stack.takeUndo(), isNull);
      expect(stack.takeRedo(), isNull);
    });

    test('undo then redo walks the steps in order', () {
      final stack = ListUndoStack();
      final a = _renamed('a');
      final b = _renamed('b');
      stack
        ..push(a)
        ..push(b);
      expect(stack.undoDepth, 2);

      final first = stack.takeUndo();
      expect(first, same(b));
      stack.pushRedo(first!);
      final second = stack.takeUndo();
      expect(second, same(a));
      stack.pushRedo(second!);
      expect(stack.canUndo, isFalse);
      expect(stack.redoDepth, 2);
      expect(stack.hasHistory, isTrue,
          reason: 'the arrows stay once the visit changed something');

      final redone = stack.takeRedo();
      expect(redone, same(a));
      stack.pushUndo(redone!);
      expect(stack.canRedo, isTrue,
          reason: 'redo keeps the rest of its history');
      expect(stack.nextRedo, same(b));
    });

    test('a new change clears redo', () {
      final stack = ListUndoStack();
      stack.push(_renamed('a'));
      stack.pushRedo(stack.takeUndo()!);
      expect(stack.canRedo, isTrue);

      stack.push(_renamed('c'));
      expect(stack.canRedo, isFalse);
      expect(stack.undoDepth, 1);
    });

    test('a failed apply puts the step back on top', () {
      final stack = ListUndoStack();
      final a = _renamed('a');
      stack.push(a);
      final taken = stack.takeUndo()!;
      stack.returnUndo(taken);
      expect(stack.nextUndo, same(a));
      expect(stack.canRedo, isFalse);
    });

    test('drops the oldest steps past its capacity', () {
      final stack = ListUndoStack(capacity: 3);
      for (var i = 0; i < 5; i++) {
        stack.push(_renamed('$i'));
      }
      expect(stack.undoDepth, 3);
      final names = <String>[];
      while (stack.canUndo) {
        names.add((stack.takeUndo()! as ListRenamedStep).after);
      }
      expect(names, ['4', '3', '2']);
    });

    test('defaults to a generous cap', () {
      final stack = ListUndoStack();
      for (var i = 0; i < 250; i++) {
        stack.push(_renamed('$i'));
      }
      expect(stack.undoDepth, ListUndoStack.defaultCapacity);
    });

    test('notifies listeners on every change', () {
      final stack = ListUndoStack();
      var calls = 0;
      stack.addListener(() => calls++);
      stack.push(_renamed('a'));
      stack.pushRedo(stack.takeUndo()!);
      stack.clear();
      expect(calls, 4);
      expect(stack.hasHistory, isFalse);
    });

    test('remaps a temporary item id in both histories', () {
      final stack = ListUndoStack();
      final temp = _item('temp');
      stack
        ..push(ItemAddedStep(item: temp))
        ..push(ItemsCheckedStep(
            itemIds: const ['temp', 'other'],
            checked: true,
            at: DateTime.utc(2026)))
        ..push(ItemsReorderedStep(
            before: const ['other', 'temp'], after: const ['temp', 'other']))
        ..push(ItemsClearedStep(
            items: [temp, _item('other')], onlyChecked: true, clearOpId: 'op'));
      stack.pushRedo(stack.takeUndo()!);

      stack.remapItemId('temp', 'server-1');

      final cleared = stack.takeRedo()! as ItemsClearedStep;
      expect(cleared.items.map((i) => i.id), ['server-1', 'other']);
      expect(cleared.items.first.canonicalItemId, 'canon-temp',
          reason: 'only the id moves');
      expect(cleared.clearOpId, 'op');
      final reordered = stack.takeUndo()! as ItemsReorderedStep;
      expect(reordered.before, ['other', 'server-1']);
      expect(reordered.after, ['server-1', 'other']);
      final checked = stack.takeUndo()! as ItemsCheckedStep;
      expect(checked.itemIds, ['server-1', 'other']);
      final added = stack.takeUndo()! as ItemAddedStep;
      expect(added.item.id, 'server-1');
      expect(added.item.name, 'Item temp');
    });

    test('remapping leaves unrelated steps as they are', () {
      final step = ItemDeletedStep(item: _item('x'));
      expect(step.remapItemId('y', 'z'), same(step));
      final rename = _renamed('a');
      expect(rename.remapItemId('x', 'y'), same(rename));
    });
  });

  group('ListItemFields', () {
    test('a missing price and a zero price are the same', () {
      const a = ListItemFields(
          name: 'Milk', quantity: 1, unit: '', checked: false, position: 0);
      const b = ListItemFields(
          name: 'Milk',
          quantity: 1,
          unit: '',
          priceCents: 0,
          checked: false,
          position: 0);
      expect(a.sameContentAs(b), isTrue);
      expect(a, b);
    });

    test('content ignores position and canonical link', () {
      final a = ListItemFields.of(_item('a', position: 1));
      final moved = ListItemFields.of(_item('a', position: 7));
      expect(a.sameContentAs(moved), isTrue);
      expect(a == moved, isFalse);
    });
  });
}
