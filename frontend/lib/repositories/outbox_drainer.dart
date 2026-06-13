import 'dart:convert';

import '../storage/app_database.dart';

typedef OutboxOpHandler = Future<void> Function(
    OutboxOp op, Map<String, dynamic> payload);

class OutboxDrainer {
  final AppDatabase _db;
  const OutboxDrainer(this._db);

  Future<void> drain({
    required List<String> types,
    required Map<String, OutboxOpHandler> handlers,
    int limit = 25,
  }) async {
    final batch = await _db.getOutboxBatchByTypes(types, limit: limit);
    if (batch.isEmpty) return;
    for (final op in batch) {
      final fresh = await _db.getOutboxOpById(op.id);
      if (fresh == null) continue;
      Map<String, dynamic> payload;
      try {
        payload = (jsonDecode(fresh.payloadJson) as Map).cast<String, dynamic>();
      } catch (_) {
        await _db.deleteOutboxOp(op.id);
        continue;
      }
      final handler = handlers[fresh.type];
      if (handler == null) {
        await _db.deleteOutboxOp(op.id);
        continue;
      }
      try {
        await handler(fresh, payload);
      } catch (e) {
        // PLAN 003 will replace this block with error classification.
        await _db.markOutboxAttempt(op.id, error: 'Something went wrong.');
        return;
      }
    }
  }
}
