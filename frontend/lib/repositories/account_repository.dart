import 'dart:async';

import 'package:uuid/uuid.dart';

import '../models/auth_models.dart';
import '../storage/app_database.dart';
import 'outbox_drainer.dart';

/// Offline-first writes to the signed-in account itself, as opposed to a
/// household's data. Today that is the UI language the server writes email
/// in; it goes through the outbox like every other change, so switching the
/// language on a plane still reaches the server once the phone is back
/// online.
class AccountRepository {
  final AppDatabase _db;

  /// Sends the queued patch to `PATCH /auth/me`.
  final Future<void> Function(UpdateUserRequest request) _updateMe;
  final Uuid _uuid;

  /// Production hook for the sync session; see [PinwallRepository].
  final void Function()? _onLocalWrite;

  static const setLanguageOp = 'setLanguage';

  /// Account ops target the one signed-in account, so they share a fixed
  /// entity id; sign-out wipes the outbox, so it never outlives the account.
  static const _accountEntityId = 'me';

  AccountRepository({
    required AppDatabase db,
    required Future<void> Function(UpdateUserRequest request) updateMe,
    Uuid? uuid,
    void Function()? onLocalWrite,
  })  : _db = db,
        _updateMe = updateMe,
        _uuid = uuid ?? const Uuid(),
        _onLocalWrite = onLocalWrite;

  /// Queues the app's UI language for the server. Last write wins: a change
  /// still waiting to sync is replaced, so only the newest language is sent.
  Future<void> queueLanguage(String language) async {
    await _db.transaction(() async {
      await _db.deleteOutboxOpsByTypeAndEntity(setLanguageOp, _accountEntityId);
      final id = _uuid.v4();
      await _db.enqueueOutbox(
        id: id,
        type: setLanguageOp,
        payload: {'language': language},
        idempotencyKey: '$setLanguageOp:$id',
        entityType: 'account',
        entityId: _accountEntityId,
      );
    });
    // Outside the transaction: a drain started inside it would bind its
    // bookkeeping to a transaction that has already committed.
    final onLocalWrite = _onLocalWrite;
    if (onLocalWrite != null) {
      onLocalWrite();
    } else {
      unawaited(drainOutboxOnce().catchError((_) {}));
    }
  }

  Future<void> drainOutboxOnce() async {
    await OutboxDrainer(_db).drain(
      types: const [setLanguageOp],
      handlers: {
        setLanguageOp: (op, payload) async {
          await _updateMe(
            UpdateUserRequest(language: payload['language'] as String),
          );
          await _db.deleteOutboxOp(op.id);
        },
      },
    );
  }
}
