import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/api_config.dart';
import '../models/auth_models.dart';
import '../models/notification_models.dart';
import '../services/notification_service.dart';
import '../services/server_language_sync.dart' show kQueuedServerLanguageKey;
import '../storage/app_database.dart';
import 'outbox_drainer.dart';

/// Offline-first writes to the signed-in account itself, as opposed to a
/// household's data: the UI language the server writes email in, the
/// profile (name, tips emails), the notification inbox (read, read all,
/// delete) and the notification preferences. They go through the outbox like
/// every other change, so a rename or "mark all read" on a plane still
/// reaches the server once the phone is back online.
///
/// Reads stay with the services (and their offline response cache); the
/// `withPending*` helpers lay still-queued writes over whatever they return,
/// so a stale or refreshed answer never undoes a change the user can see.
class AccountRepository {
  final AppDatabase _db;

  /// Sends the queued patch to `PATCH /auth/me`.
  final Future<void> Function(UpdateUserRequest request) _updateMe;

  /// Sends queued inbox and preference writes. Optional so callers that only
  /// queue the language need not build one; without it those ops stay queued.
  final NotificationService? _notifications;
  final Uuid _uuid;

  /// Production hook for the sync session; see [PinwallRepository].
  final void Function()? _onLocalWrite;

  static const setLanguageOp = 'setLanguage';
  static const updateProfileOp = 'updateProfile';
  static const markNotificationReadOp = 'markNotificationRead';
  static const markAllNotificationsReadOp = 'markAllNotificationsRead';
  static const deleteNotificationOp = 'deleteNotification';
  static const updateNotificationPreferenceOp = 'updateNotificationPreference';

  static const _notificationOps = [
    markNotificationReadOp,
    markAllNotificationsReadOp,
    deleteNotificationOp,
    updateNotificationPreferenceOp,
  ];

  /// Every op type this repository queues and drains.
  static const opTypes = [
    setLanguageOp,
    updateProfileOp,
    ..._notificationOps,
  ];

  /// Entity id of the one "mark all read" op.
  static const _inboxEntityId = 'inbox';

  /// Account ops target the one signed-in account, so they share a fixed
  /// entity id; sign-out discards them ([discardQueued]), so they never
  /// outlive the account.
  static const _accountEntityId = 'me';

  /// Sign-out: drops queued account ops. They belong to the account being
  /// signed out and cannot be sent without its session; left behind, they
  /// would also keep the outbox non-empty, which stops the local data wipe,
  /// and a profile patch would be applied to whoever signs in next. Also
  /// forgets that the language was queued, so it is reported again with the
  /// next session.
  static Future<void> discardQueued(AppDatabase db) async {
    for (final type in opTypes) {
      for (final op in await db.getOutboxOpsByType(type)) {
        await db.deleteOutboxOp(op.id);
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kQueuedServerLanguageKey);
  }

  AccountRepository({
    required AppDatabase db,
    required Future<void> Function(UpdateUserRequest request) updateMe,
    NotificationService? notifications,
    Uuid? uuid,
    void Function()? onLocalWrite,
  })  : _db = db,
        _updateMe = updateMe,
        _notifications = notifications,
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
    _afterLocalWrite();
  }

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  /// Queues a profile change (name, tips emails) and applies it to the saved
  /// profile at once, so every screen that paints from it shows the change
  /// offline. Fields merge with a change still waiting to sync; newer win.
  Future<void> queueProfileUpdate({
    String? firstName,
    String? lastName,
    bool? tipsEmailsEnabled,
  }) async {
    final patch = UpdateUserRequest(
      firstName: firstName,
      lastName: lastName,
      tipsEmailsEnabled: tipsEmailsEnabled,
    ).toJson();
    if (patch.isEmpty) return;
    await _db.transaction(() async {
      final merged = <String, dynamic>{};
      for (final op in await _db.getOutboxOpsByType(updateProfileOp)) {
        // Never fold into an op the drain may be sending right now; a second
        // request with the newer values is harmless.
        if (op.lastAttemptAt != null) continue;
        merged.addAll(_patchOf(op) ?? const {});
        await _db.deleteOutboxOp(op.id);
      }
      merged.addAll(patch);
      final id = _uuid.v4();
      await _db.enqueueOutbox(
        id: id,
        type: updateProfileOp,
        payload: {'patch': merged},
        idempotencyKey: '$updateProfileOp:$id',
        entityType: 'account',
        entityId: _accountEntityId,
      );
    });
    await _patchSavedProfile(patch);
    _afterLocalWrite();
  }

  /// [user] with every still-queued profile change applied. For a fresh (or
  /// offline-cached) `GET /auth/me` that may predate them.
  Future<User> withPendingProfile(User user) async {
    final ops = await _db.getOutboxOpsByType(updateProfileOp);
    if (ops.isEmpty) return user;
    final json = user.toJson();
    for (final op in ops) {
      json.addAll(_patchOf(op) ?? const {});
    }
    try {
      return User.fromJson(json);
    } catch (_) {
      return user;
    }
  }

  /// Writes [patch] into the profile saved for offline launches (the one
  /// `AuthService.cachedMe` reads), best-effort.
  Future<void> _patchSavedProfile(Map<String, dynamic> patch) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(ApiConfig.userDataKey);
      if (raw == null) return;
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>()
        ..addAll(patch);
      await prefs.setString(ApiConfig.userDataKey, jsonEncode(json));
    } catch (_) {
      // The queued op is what matters; the next getMe repaints the cache.
    }
  }

  static Map<String, dynamic>? _patchOf(OutboxOp op) {
    try {
      final payload = jsonDecode(op.payloadJson);
      if (payload is! Map || payload['patch'] is! Map) return null;
      return (payload['patch'] as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Notification inbox
  // ---------------------------------------------------------------------------

  /// Queues marking one notification read.
  Future<void> markNotificationRead(String notificationId) async {
    await _enqueueOnce(
      type: markNotificationReadOp,
      entityId: notificationId,
      payload: {'id': notificationId},
    );
  }

  /// Queues marking the whole inbox read. Notifications arriving after this
  /// call stay unread locally; the server marks what it holds when the op
  /// lands.
  Future<void> markAllNotificationsRead() async {
    await _db.transaction(() async {
      // Single reads are covered by the read-all.
      for (final op in await _db.getOutboxOpsByType(markNotificationReadOp)) {
        if (op.lastAttemptAt == null) await _db.deleteOutboxOp(op.id);
      }
      await _db.deleteOutboxOpsByTypeAndEntity(
          markAllNotificationsReadOp, _inboxEntityId);
      final id = _uuid.v4();
      await _db.enqueueOutbox(
        id: id,
        type: markAllNotificationsReadOp,
        payload: {'before': DateTime.now().toUtc().toIso8601String()},
        idempotencyKey: '$markAllNotificationsReadOp:$id',
        entityType: 'notification',
        entityId: _inboxEntityId,
      );
    });
    _afterLocalWrite();
  }

  /// Queues deleting one notification. [wasUnread] keeps the unread badge
  /// right until the delete syncs.
  Future<void> deleteNotification(
    String notificationId, {
    required bool wasUnread,
  }) async {
    await _db.transaction(() async {
      await _db.deleteOutboxOpsByTypeAndEntity(
          markNotificationReadOp, notificationId);
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: deleteNotificationOp,
        payload: {'id': notificationId, 'wasUnread': wasUnread},
        idempotencyKey: '$deleteNotificationOp:$notificationId',
        entityType: 'notification',
        entityId: notificationId,
      );
    });
    _afterLocalWrite();
  }

  /// [items] with still-queued inbox writes applied: deleted ones removed,
  /// read ones (singly, or by a read-all made after they arrived) marked read.
  Future<List<NotificationModel>> withPendingNotificationWrites(
    List<NotificationModel> items,
  ) async {
    final pending = await _pendingInbox();
    if (pending.isEmpty) return items;
    return [
      for (final n in items)
        if (!pending.deleted.contains(n.id))
          pending.isRead(n) && !n.isRead ? _asRead(n) : n,
    ];
  }

  /// The server's unread count less what is still queued as read or deleted.
  /// Exact for a count fetched before the writes; a count fetched after some
  /// of them synced is briefly low, never high, until those ops leave.
  Future<int> unreadCountWithPending(int serverCount) async {
    final pending = await _pendingInbox();
    if (pending.isEmpty) return serverCount;
    if (pending.readAllBefore != null) return 0;
    final adjusted =
        serverCount - pending.read.length - pending.deletedUnread.length;
    return adjusted < 0 ? 0 : adjusted;
  }

  Future<_PendingInbox> _pendingInbox() async {
    final read = <String>{};
    final deleted = <String>{};
    final deletedUnread = <String>{};
    DateTime? readAllBefore;
    for (final op in await _db.getOutboxOpsByType(markNotificationReadOp)) {
      if (op.entityId != null) read.add(op.entityId!);
    }
    for (final op in await _db.getOutboxOpsByType(deleteNotificationOp)) {
      if (op.entityId == null) continue;
      deleted.add(op.entityId!);
      if (_payload(op)?['wasUnread'] == true) deletedUnread.add(op.entityId!);
    }
    for (final op in await _db.getOutboxOpsByType(markAllNotificationsReadOp)) {
      final before =
          DateTime.tryParse(_payload(op)?['before'] as String? ?? '') ??
              op.createdAt;
      if (readAllBefore == null || before.isAfter(readAllBefore)) {
        readAllBefore = before;
      }
    }
    return _PendingInbox(
      read: read,
      deleted: deleted,
      deletedUnread: deletedUnread,
      readAllBefore: readAllBefore,
    );
  }

  static NotificationModel _asRead(NotificationModel n) => NotificationModel(
        id: n.id,
        userId: n.userId,
        groupId: n.groupId,
        type: n.type,
        title: n.title,
        body: n.body,
        data: n.data,
        isRead: true,
        readAt: n.readAt ?? DateTime.now(),
        createdAt: n.createdAt,
      );

  // ---------------------------------------------------------------------------
  // Notification preferences
  // ---------------------------------------------------------------------------

  /// Queues a household's notification preferences. The screen always sends
  /// the complete set of toggles, so the newest queued set simply replaces an
  /// older one.
  Future<void> queueNotificationPreference(
    NotificationPreferenceModel pref,
  ) async {
    await _db.transaction(() async {
      for (final op
          in await _db.getOutboxOpsByType(updateNotificationPreferenceOp)) {
        if (op.entityId == pref.groupId && op.lastAttemptAt == null) {
          await _db.deleteOutboxOp(op.id);
        }
      }
      final id = _uuid.v4();
      await _db.enqueueOutbox(
        id: id,
        type: updateNotificationPreferenceOp,
        payload: {'pref': pref.toPatchJson()},
        idempotencyKey: '$updateNotificationPreferenceOp:$id',
        entityType: 'notificationPreference',
        entityId: pref.groupId,
      );
    });
    _afterLocalWrite();
  }

  /// [prefs] with every still-queued preference change applied.
  Future<List<NotificationPreferenceModel>> withPendingPreferences(
    List<NotificationPreferenceModel> prefs,
  ) async {
    final ops = await _db.getOutboxOpsByType(updateNotificationPreferenceOp);
    if (ops.isEmpty) return prefs;
    final latest = <String, Map<String, dynamic>>{};
    for (final op in ops) {
      final pref = _payload(op)?['pref'];
      if (op.entityId != null && pref is Map) {
        latest[op.entityId!] = pref.cast<String, dynamic>();
      }
    }
    return [
      for (final p in prefs)
        if (latest[p.groupId] case final patch?)
          NotificationPreferenceModel.fromJson({
            ...patch,
            'id': p.id,
            'user_id': p.userId,
            'group_id': p.groupId,
          })
        else
          p,
    ];
  }

  // ---------------------------------------------------------------------------
  // Queue plumbing
  // ---------------------------------------------------------------------------

  /// Enqueues an op unless one of [type] for [entityId] is already queued.
  Future<void> _enqueueOnce({
    required String type,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    await _db.transaction(() async {
      if (await _db.pendingOpCountForEntity(type, entityId) > 0) return;
      await _db.enqueueOutbox(
        id: _uuid.v4(),
        type: type,
        payload: payload,
        idempotencyKey: '$type:$entityId',
        entityType: 'notification',
        entityId: entityId,
      );
    });
    _afterLocalWrite();
  }

  /// Hands the write to the sync session. Always called outside the
  /// transaction: a drain started inside it would bind its bookkeeping to a
  /// transaction that has already committed.
  void _afterLocalWrite() {
    final onLocalWrite = _onLocalWrite;
    if (onLocalWrite != null) {
      onLocalWrite();
    } else {
      unawaited(drainOutboxOnce().catchError((_) {}));
    }
  }

  static Map<String, dynamic>? _payload(OutboxOp op) {
    try {
      final payload = jsonDecode(op.payloadJson);
      return payload is Map ? payload.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> drainOutboxOnce() async {
    final notifications = _notifications;
    await OutboxDrainer(_db).drain(
      // Without the notification service those ops are left for a
      // repository that has one, instead of being dropped as unhandled.
      types: notifications == null
          ? const [setLanguageOp, updateProfileOp]
          : opTypes,
      handlers: {
        setLanguageOp: (op, payload) async {
          await _updateMe(
            UpdateUserRequest(language: payload['language'] as String),
          );
          await _db.deleteOutboxOp(op.id);
        },
        updateProfileOp: (op, payload) async {
          final patch = (payload['patch'] as Map).cast<String, dynamic>();
          await _updateMe(UpdateUserRequest.fromJson(patch));
          await _db.deleteOutboxOp(op.id);
        },
        if (notifications != null) ...{
          markNotificationReadOp: (op, payload) async {
            await _ignoringNotFound(
                () => notifications.markAsRead(payload['id'] as String));
            await _db.deleteOutboxOp(op.id);
          },
          markAllNotificationsReadOp: (op, payload) async {
            await notifications.markAllAsRead();
            await _db.deleteOutboxOp(op.id);
          },
          deleteNotificationOp: (op, payload) async {
            await _ignoringNotFound(() =>
                notifications.deleteNotification(payload['id'] as String));
            await _db.deleteOutboxOp(op.id);
          },
          updateNotificationPreferenceOp: (op, payload) async {
            final pref = (payload['pref'] as Map).cast<String, dynamic>();
            await notifications.updatePreference(
              NotificationPreferenceModel.fromJson(
                  {...pref, 'id': '', 'user_id': ''}),
            );
            await _db.deleteOutboxOp(op.id);
          },
        },
      },
    );
  }

  /// A notification that is already gone (deleted on another device, or
  /// expired) needs neither reading nor deleting: the goal is met.
  static Future<void> _ignoringNotFound(Future<void> Function() call) async {
    try {
      await call();
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
    }
  }
}

class _PendingInbox {
  final Set<String> read;
  final Set<String> deleted;
  final Set<String> deletedUnread;
  final DateTime? readAllBefore;

  const _PendingInbox({
    required this.read,
    required this.deleted,
    required this.deletedUnread,
    required this.readAllBefore,
  });

  bool get isEmpty => read.isEmpty && deleted.isEmpty && readAllBefore == null;

  bool isRead(NotificationModel n) =>
      read.contains(n.id) ||
      (readAllBefore != null && !n.createdAt.isAfter(readAllBefore!));
}
