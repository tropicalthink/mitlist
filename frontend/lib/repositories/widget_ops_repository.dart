import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/list_models.dart';
import '../services/response_cache_interceptor.dart';
import '../services/widgets/widget_bridge.dart';
import '../services/widgets/widget_op.dart';
import '../storage/app_database.dart';
import 'chore_repository.dart';
import 'list_repository.dart';
import 'outbox_drainer.dart';

/// Takes over the changes people make outside the app — home screen
/// widgets, Siri, Controls, the Android quick add — which native code queues
/// in its own file (plans/047, contract C2).
///
/// [importPending] runs when the app starts or resumes. For each queued op:
/// - **delivered**: the widget's request already reached the server; its
///   stored response updates the cache. Nothing is sent again.
/// - **pending**: the cache shows the change at once, and a `widgetRequest`
///   outbox op replays the widget's exact request (method, path, body) with
///   `Idempotency-Key = op_id`. If the widget's request did get through and
///   only its response was lost, the server answers with the stored result
///   instead of applying it twice.
/// - **failed**: dropped; the server refused it.
///
/// The native queue line is removed only after the op is in the outbox.
class WidgetOpsRepository {
  WidgetOpsRepository({
    required AppDatabase db,
    required WidgetBridge bridge,
    required Dio dio,
    required ListRepository listRepo,
    required ChoreRepository choreRepo,
    void Function()? onLocalWrite,
  })  : _db = db,
        _bridge = bridge,
        _dio = dio,
        _listRepo = listRepo,
        _choreRepo = choreRepo,
        _onLocalWrite = onLocalWrite;

  /// The outbox op type that replays a native op's request.
  static const outboxType = 'widgetRequest';

  final AppDatabase _db;
  final WidgetBridge _bridge;
  final Dio _dio;
  final ListRepository _listRepo;
  final ChoreRepository _choreRepo;
  final void Function()? _onLocalWrite;

  Future<int>? _import;
  bool _isDraining = false;

  /// Moves the native queue into the app. Concurrent calls share one run.
  /// Returns how many queue lines were taken over.
  Future<int> importPending() {
    return _import ??= _importPending().whenComplete(() => _import = null);
  }

  Future<int> _importPending() async {
    final lines = await _bridge.readPendingOps();
    if (lines.isEmpty) return 0;
    final taken = <String>[];
    var queued = false;
    for (final line in lines) {
      final op = WidgetOp.tryParse(line);
      if (op == null) {
        final opId = WidgetOp.opIdOf(line);
        if (opId != null) taken.add(opId);
        continue;
      }
      if (!op.isKnownType) {
        taken.add(op.opId);
        continue;
      }
      switch (op.state) {
        case WidgetOpState.failed:
          break;
        case WidgetOpState.delivered:
          await _applyDelivered(op);
        case WidgetOpState.pending:
          await _applyOptimistic(op);
          // The op id doubles as the outbox id, so importing the same line
          // twice (the app died before the ack) still queues it once.
          await _db.enqueueOutbox(
            id: op.opId,
            type: outboxType,
            payload: _payload(op),
            idempotencyKey: op.opId,
            entityType:
                op.type == WidgetOp.completeChore ? 'chore' : 'listItem',
            entityId: switch (op.type) {
              WidgetOp.checkItem => op.itemId,
              WidgetOp.completeChore => op.choreId,
              _ => op.opId,
            },
          );
          queued = true;
      }
      taken.add(op.opId);
    }
    await _bridge.ackPendingOps(taken);
    if (queued) _onLocalWrite?.call();
    return taken.length;
  }

  Map<String, dynamic> _payload(WidgetOp op) => {
        'type': op.type,
        'method': op.method,
        'path': op.path,
        'body': op.body,
        'householdId': op.householdId,
        if (op.listId != null) 'listId': op.listId,
        if (op.itemId != null) 'itemId': op.itemId,
        if (op.choreId != null) 'choreId': op.choreId,
        if (op.name != null) 'name': op.name,
        if (op.source != null) 'source': op.source,
      };

  Future<void> _applyOptimistic(WidgetOp op) async {
    final listId = op.listId;
    switch (op.type) {
      case WidgetOp.checkItem:
        final itemId = op.itemId;
        if (listId != null && itemId != null) {
          await _listRepo.applyExternalCheck(listId, itemId);
        }
      case WidgetOp.addItem:
        final name = op.name;
        if (listId != null && name != null) {
          await _listRepo.applyExternalAdd(listId, tempId: op.opId, name: name);
        }
      case WidgetOp.completeChore:
        final choreId = op.choreId;
        if (choreId != null) {
          await _choreRepo.applyExternalCompletion(op.householdId, choreId);
        }
    }
  }

  Future<void> _applyDelivered(WidgetOp op) async {
    final item = _serverItem(op.responseJson);
    switch (op.type) {
      case WidgetOp.checkItem || WidgetOp.addItem:
        if (item != null) {
          await _listRepo.applyServerItem(item);
        } else if (op.listId != null) {
          await _bestEffort(() => _listRepo.refreshItems(op.listId!));
        }
      case WidgetOp.completeChore:
        final choreId = op.choreId;
        if (choreId != null) {
          await _choreRepo.applyExternalCompletion(op.householdId, choreId);
        }
        await _bestEffort(
            () => _choreRepo.refreshCurrentChores(op.householdId));
    }
  }

  // ---------------------------------------------------------------------------
  // Outbox
  // ---------------------------------------------------------------------------

  Future<void> drainOutboxOnce() async {
    if (_isDraining) return;
    _isDraining = true;
    try {
      await OutboxDrainer(_db).drain(
        types: const [outboxType],
        handlers: {outboxType: _send},
      );
    } finally {
      _isDraining = false;
    }
  }

  Future<void> _send(OutboxOp op, Map<String, dynamic> payload) async {
    final method = payload['method'];
    final path = payload['path'];
    final body = payload['body'];
    final type = payload['type'];
    final householdId = payload['householdId'];
    if (method is! String ||
        path is! String ||
        body is! String ||
        type is! String ||
        householdId is! String) {
      await _db.deleteOutboxOp(op.id);
      return;
    }

    Response<Object?> response;
    try {
      response = await _dio.request<Object?>(
        path,
        // A String body goes out byte for byte (see C2).
        data: body,
        options: Options(
          method: method,
          contentType: Headers.jsonContentType,
          headers: {
            'Idempotency-Key': op.idempotencyKey ?? op.id,
            'X-Mitlist-Group-ID': householdId,
          },
          extra: {ResponseCacheInterceptor.noCacheExtra: true},
        ),
      );
    } on DioException catch (e) {
      if (!_isRefusal(e)) rethrow;
      // The server will never accept this one (the item or chore is gone,
      // the person left the household): undo the optimistic change.
      await _db.deleteOutboxOp(op.id);
      await _rollBack(type, payload, op.id);
      return;
    }

    await _db.deleteOutboxOp(op.id);
    final item = _serverItem(response.data);
    switch (type) {
      case WidgetOp.checkItem:
        if (item != null) await _listRepo.applyServerItem(item);
      case WidgetOp.addItem:
        if (item != null) await _listRepo.applyServerItem(item, tempId: op.id);
      case WidgetOp.completeChore:
        await _bestEffort(() => _choreRepo.refreshCurrentChores(householdId));
    }
  }

  /// 4xx answers that retrying cannot change. A 409 is one too, unless it is
  /// the idempotency middleware asking to retry a request still in flight.
  static bool _isRefusal(DioException e) {
    final status = e.response?.statusCode;
    if (status == null) return false;
    if (status == 409) return e.response?.headers.value('retry-after') == null;
    return status == 400 ||
        status == 403 ||
        status == 404 ||
        status == 410 ||
        status == 422;
  }

  Future<void> _rollBack(
      String type, Map<String, dynamic> payload, String opId) async {
    final listId = payload['listId'];
    switch (type) {
      case WidgetOp.addItem:
        if (listId is String) await _listRepo.discardExternalAdd(listId, opId);
      case WidgetOp.checkItem:
        if (listId is String) {
          await _bestEffort(() => _listRepo.refreshItems(listId));
        }
      case WidgetOp.completeChore:
        final householdId = payload['householdId'];
        if (householdId is String) {
          await _bestEffort(() => _choreRepo.refreshCurrentChores(householdId));
        }
    }
  }

  static ListItem? _serverItem(Object? data) {
    Object? json = data;
    if (json is String) {
      try {
        json = jsonDecode(json);
      } catch (_) {
        return null;
      }
    }
    if (json is! Map<String, dynamic>) return null;
    try {
      return ListItem.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _bestEffort(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Offline or refused: the next refresh reconciles.
    }
  }
}
