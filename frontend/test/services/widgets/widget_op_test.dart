import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/widgets/widget_op.dart';

/// The queue format is shared with the Kotlin and Swift code through the
/// golden fixture in contracts/widgets (plans/047, C2).
void main() {
  final lines = File('../contracts/widgets/pending_ops_v1.jsonl')
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .toList();

  test('parses every op of the golden queue', () {
    final ops = lines.map(WidgetOp.tryParse).toList();
    expect(ops, everyElement(isNotNull));
    expect(ops.map((o) => o!.type), [
      WidgetOp.checkItem,
      WidgetOp.addItem,
      WidgetOp.addItem,
      WidgetOp.completeChore,
      WidgetOp.checkItem,
    ]);
    expect(ops.map((o) => o!.state), [
      WidgetOpState.pending,
      WidgetOpState.pending,
      WidgetOpState.delivered,
      WidgetOpState.pending,
      WidgetOpState.failed,
    ]);

    final check = ops.first!;
    expect(check.method, 'PATCH');
    expect(check.path,
        '/lists/22222222-2222-4222-8222-222222222222/items/33333333-3333-4333-8333-333333333331');
    expect(check.body, '{"checked":true}');
    expect(check.householdId, '11111111-1111-4111-8111-111111111111');
    expect(check.itemId, '33333333-3333-4333-8333-333333333331');
    expect(check.source, 'ios_widget');

    final delivered = ops[2]!;
    expect(delivered.deliveredAt, DateTime.utc(2026, 10, 2, 9, 3, 1));
    expect(
        delivered.responseJson?['id'], '88888888-8888-4888-8888-888888888888');

    expect(ops[3]!.body, '{}', reason: 'chore.complete sends an empty object');
  });

  test('rejects lines that cannot be replayed', () {
    expect(WidgetOp.tryParse('not json'), isNull);
    expect(WidgetOp.tryParse('{"op_id":"x","type":"list_item.check"}'), isNull);
    expect(
      WidgetOp.tryParse(
          '{"op_id":"x","type":"list_item.check","household_id":"h","method":"PATCH","path":"lists/1","body":"{}"}'),
      isNull,
      reason: 'paths are relative to the API base and start with /',
    );
    expect(WidgetOp.opIdOf('{"op_id":"x","type":"broken"}'), 'x');
    expect(WidgetOp.opIdOf('garbage'), isNull);
  });
}
