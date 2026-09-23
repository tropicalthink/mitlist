import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations_en.dart';
import 'package:mitlist/storage/app_database.dart';
import 'package:mitlist/utils/outbox_op_label.dart';

OutboxOp _op(
  String type,
  Map<String, dynamic> payload, {
  String? entityType,
  String? entityId,
}) {
  return OutboxOp(
    id: 'op-1',
    type: type,
    payloadJson: jsonEncode(payload),
    createdAt: DateTime(2026, 9, 23),
    attemptCount: 0,
    entityType: entityType,
    entityId: entityId,
  );
}

void main() {
  final l10n = AppLocalizationsEn();

  test('createItem uses the payload name', () {
    final op = _op('createItem', {'listId': 'l1', 'name': ' Milk '},
        entityType: 'listItem', entityId: 'tmp-1');
    expect(outboxOpLabel(l10n, op), 'Add item — Milk');
    expect(outboxOpDomain(op), OutboxOpDomain.list);
    expect(outboxOpItemIdForNameLookup(op), isNull);
  });

  test('updateItem with only a checked patch reads as check off / uncheck', () {
    final check = _op(
      'updateItem',
      {
        'listId': 'l1',
        'itemId': 'item-1',
        'patch': {'checked': true},
      },
      entityType: 'listItem',
      entityId: 'item-1',
    );
    expect(outboxOpItemIdForNameLookup(check), 'item-1');
    expect(outboxOpLabel(l10n, check, itemName: 'Milk'), 'Check off — Milk');
    expect(outboxOpLabel(l10n, check), 'Check off');

    final uncheck = _op('updateItem', {
      'itemId': 'item-1',
      'patch': {'checked': false},
    });
    expect(outboxOpLabel(l10n, uncheck, itemName: 'Milk'), 'Uncheck — Milk');
  });

  test('updateItem with a broader patch falls back to "Update item"', () {
    final op = _op('updateItem', {
      'itemId': 'item-1',
      'patch': {'checked': true, 'quantity': 2},
    });
    expect(outboxOpLabel(l10n, op, itemName: 'Milk'), 'Update item — Milk');
  });

  test('create ops read the name from the wrapped request', () {
    final op = _op('createChore', {
      'localId': 'local-1',
      'request': {'name': 'Take out bins'},
    });
    expect(outboxOpLabel(l10n, op), 'Add chore — Take out bins');
    expect(outboxOpDomain(op), OutboxOpDomain.chores);
  });

  test('database watches pending ops oldest first and resolves item names',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.upsertListItemsRows([
      ListItemsTableCompanion.insert(
        id: 'item-1',
        listId: 'l1',
        name: 'Milk',
        quantity: 1,
        unit: '',
        checked: false,
        position: 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ]);
    expect(await db.getListItemNameById('item-1'), 'Milk');
    expect(await db.getListItemNameById('missing'), isNull);

    // Enqueue newest first so the assertion proves the ordering.
    await db.enqueueOutbox(id: 'b', type: 'deleteItem', payload: {});
    await db.enqueueOutbox(id: 'a', type: 'createItem', payload: {});
    await db.enqueueOutbox(id: 'dead', type: 'deleteItem', payload: {});
    await (db.update(db.outboxOps)..where((t) => t.id.equals('a')))
        .write(OutboxOpsCompanion(createdAt: Value(DateTime(2026, 1, 1))));
    await (db.update(db.outboxOps)..where((t) => t.id.equals('b')))
        .write(OutboxOpsCompanion(createdAt: Value(DateTime(2026, 1, 2))));
    await (db.update(db.outboxOps)..where((t) => t.id.equals('dead')))
        .write(const OutboxOpsCompanion(attemptCount: Value(10)));

    final pending = await db.watchPendingOutboxOps().first;
    expect(pending.map((o) => o.id), ['a', 'b']);
  });
}
