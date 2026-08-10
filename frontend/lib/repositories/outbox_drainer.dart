import 'dart:convert';

import 'package:dio/dio.dart';

import '../services/api_error_mapper.dart';
import '../storage/app_database.dart';
import 'outbox_error_classifier.dart';

typedef OutboxOpHandler = Future<void> Function(
    OutboxOp op, Map<String, dynamic> payload);

class OutboxDrainer {
  final AppDatabase _db;
  const OutboxDrainer(this._db);

  Future<void> drain({
    required List<String> types,
    required Map<String, OutboxOpHandler> handlers,
    int limit = 25,
    Duration minBackoff = const Duration(seconds: 5),
  }) async {
    final batch = await _db.getOutboxBatchByTypes(types,
        limit: limit, minBackoff: minBackoff);
    if (batch.isEmpty) return;
    for (final op in batch) {
      final fresh = await _db.getOutboxOpById(op.id);
      if (fresh == null) continue;
      Map<String, dynamic> payload;
      try {
        payload =
            (jsonDecode(fresh.payloadJson) as Map).cast<String, dynamic>();
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
        final message =
            e is DioException ? ApiErrorMapper.fromDio(e) : 'Sync failed.';
        switch (classifyOutboxError(e)) {
          case OutboxErrorDisposition.transient:
            await _db.markOutboxAttempt(op.id, error: message);
            return;
          case OutboxErrorDisposition.unreachable:
            // Stamp the backoff but spend no attempt: the server never saw
            // this op, so it has earned no evidence of being bad. Stop the
            // pass either way — if one op can't reach the server, neither can
            // the rest, and per-entity ordering must hold.
            await _db.markOutboxAttempt(
              op.id,
              error: message,
              countsTowardFailure: false,
            );
            return;
          case OutboxErrorDisposition.permanent:
            await _db.markOutboxPermanentFailure(op.id,
                error: message, threshold: kOutboxMaxAttempts);
            continue;
          case OutboxErrorDisposition.conflict:
            // The server rejected the write because the row changed under us
            // (409-with-current-state). Record a conflict for the user to
            // resolve, drop the op so it stops retrying, and keep draining.
            await _recordConflict(fresh, e);
            await _db.deleteOutboxOp(op.id);
            continue;
        }
      }
    }
  }

  /// Persists a conflict from a failed op so the resolution UI can offer
  /// "keep mine" / "use theirs". [entityType] holds the op type (so keep-mine
  /// re-enqueues a valid op) and the server's current state comes from the
  /// 409 response body's `current` field.
  Future<void> _recordConflict(OutboxOp op, Object error) async {
    String serverJson = '{}';
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['current'] != null) {
        serverJson = jsonEncode(data['current']);
      }
    }
    await _db.insertConflict(
      ConflictsCompanion.insert(
        id: op.id,
        entityType: op.type,
        entityId: op.entityId ?? op.id,
        localPayloadJson: op.payloadJson,
        serverPayloadJson: serverJson,
        createdAt: DateTime.now(),
      ),
    );
  }
}
