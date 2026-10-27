import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../models/group_models.dart';
import '../services/group_service.dart';
import '../services/response_cache_interceptor.dart';
import '../storage/app_database.dart';
import 'outbox_drainer.dart';
import 'outbox_error_classifier.dart';

/// Offline-first access to the current user's household list.
///
/// The list is cached as a single JSON row in Drift so every screen can resolve
/// its active group without a network round-trip. Reads come from the cache;
/// [loadGroups] refreshes from the network and falls back to the cache when
/// offline instead of throwing.
///
/// Household *details* (name, description, currency, chore zones) are
/// offline-first too: [updateGroupOfflineFirst] patches every cached copy and
/// queues the server write. Membership changes (create, join, leave, remove,
/// delete) stay server-only: they decide what the account may see at all, so
/// they are never faked locally.
class GroupRepository {
  final AppDatabase _db;
  final GroupService _groups;
  final Uuid _uuid;

  /// Production hook for the sync session; see [PinwallRepository].
  final void Function()? _onLocalWrite;

  /// Whether the device is known to have no network right now. Lets a write
  /// skip straight to the queue instead of waiting out a connect timeout.
  final bool Function() _isKnownOffline;

  static const updateGroupOp = 'updateGroup';

  GroupRepository({
    required AppDatabase db,
    required GroupService groups,
    Uuid? uuid,
    void Function()? onLocalWrite,
    bool Function()? isKnownOffline,
  })  : _db = db,
        _groups = groups,
        _uuid = uuid ?? const Uuid(),
        _onLocalWrite = onLocalWrite,
        _isKnownOffline = isKnownOffline ?? (() => false);

  /// Live stream of the cached household list.
  Stream<List<Group>> watchGroups() {
    return _db.watchGroupsList().map((row) => _decode(row?.groupsJson));
  }

  /// One-shot read of the cached household list.
  Future<List<Group>> getGroupsOnce() async {
    final row = await _db.getGroupsListOnce();
    return _decode(row?.groupsJson);
  }

  /// Genuinely cache-first: returns the cached households immediately and
  /// refreshes in the background, so no screen waits on the network to resolve
  /// its active group.
  ///
  /// Every screen's `_resolveGroupId()` awaits this, so awaiting the network
  /// here stalled the entire app behind one request — 30s before the connect
  /// timeout was split out, and still a full round-trip after. The cached list
  /// is almost always correct (households change rarely), and the background
  /// refresh repaints anything watching [watchGroups] when it lands.
  ///
  /// [forceRefresh] restores the blocking behaviour and is **required** after
  /// creating or joining a household: those flows need the new group present in
  /// the returned list, and a stale cache would not have it. It also rethrows,
  /// because "you just joined but we can't confirm it" must not read as success.
  ///
  /// With no cache there is nothing to be first with, so the network is awaited
  /// and errors propagate.
  Future<List<Group>> loadGroups({
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    final cached = await getGroupsOnce();

    if (forceRefresh || cached.isEmpty) {
      try {
        // With nothing cached, a stale HTTP-cache answer beats none at all;
        // a forced refresh must hear from the server.
        final fresh = forceRefresh
            ? await _fetchLive(limit)
            : await _groups.listGroups(limit: limit);
        await _persist(fresh);
        return fresh;
      } catch (_) {
        if (!forceRefresh && cached.isNotEmpty) return cached;
        rethrow;
      }
    }

    // Fire-and-forget refresh. Failures are swallowed: we already have an
    // answer, and the outbox/connectivity layer owns retrying.
    unawaited(() async {
      try {
        await _persist(await _fetchLive(limit));
      } catch (_) {}
    }());

    return cached;
  }

  /// Inserts (or replaces) [group] in the cached list.
  ///
  /// Used right after creating or joining a household: the server already
  /// accepted it and handed us the row, so the cache can be made correct
  /// without a round-trip. That matters because the alternative — relying on a
  /// refetch — fails exactly when the network is flaky, leaving the user
  /// looking at an error for a household that genuinely exists.
  Future<void> cacheGroup(Group group) async {
    final current = await getGroupsOnce();
    final merged = [
      for (final g in current)
        if (g.id != group.id) g,
      group,
    ];
    await _persist(merged);
  }

  /// Forces a network refresh and updates the cache. Returns the fresh list.
  Future<List<Group>> refreshGroups({int limit = 50}) async {
    final fresh = await _fetchLive(limit);
    await _persist(fresh);
    return fresh;
  }

  /// The server's household list, never a stale HTTP-cache body: this one
  /// replaces the cached list wholesale, so a stale answer would drop a
  /// household created or joined since (see [ResponseCacheInterceptor]).
  Future<List<Group>> _fetchLive(int limit) =>
      ResponseCacheInterceptor.liveOnly(() => _groups.listGroups(limit: limit));

  Future<void> _persist(List<Group> groups) async {
    // A rename still queued offline goes back on top of the server's list;
    // otherwise every background refresh would undo it until the drain.
    final patched = [
      for (final g in groups) await withPendingEdits(_db, g),
    ];
    await _db.upsertGroupsList(
      jsonEncode(patched.map((g) => g.toJson()).toList()),
    );
  }

  /// Saves household details, online when possible and queued otherwise.
  ///
  /// Online, the server answers first, so a refusal (only admins may rename
  /// a household) reaches the person who just pressed Save instead of
  /// surfacing later as a failed sync. When the server cannot be reached —
  /// known offline, or the request fails on the way — every cached copy of
  /// the household is patched and the write is queued; the returned group is
  /// the patched one. Server refusals are rethrown untouched.
  ///
  /// Returns the household as it now stands, and whether it was queued.
  Future<({Group? group, bool queued})> updateGroupOfflineFirst(
    String groupId,
    UpdateGroupRequest request,
  ) async {
    if (!_isKnownOffline()) {
      try {
        final updated = await _groups.updateGroup(groupId, request);
        await _cacheServerGroup(updated);
        return (group: await withPendingEdits(_db, updated), queued: false);
      } catch (e) {
        if (classifyOutboxError(e) != OutboxErrorDisposition.unreachable) {
          rethrow;
        }
      }
    }
    final group = await queueGroupUpdate(groupId, request);
    return (group: group, queued: true);
  }

  /// Patches every cached copy of the household and queues the server write,
  /// without trying the network first. Returns the patched household, or
  /// null when no copy of it is cached.
  ///
  /// Writes coalesce: a queued edit of the same kind is folded into the new
  /// one (newer fields win), so only one request per household is sent. Chore
  /// zones are kept apart from the other details because the server lets any
  /// member edit zones but only admins edit the rest, and a merged request
  /// would fail a member's zone edit.
  Future<Group?> queueGroupUpdate(
    String groupId,
    UpdateGroupRequest request,
  ) async {
    final patch = _patchOf(request);
    if (patch.isEmpty) return _cachedGroup(groupId);
    final zonesOnly = _isZonesOnly(patch);
    Group? result;
    await _db.transaction(() async {
      final merged = <String, dynamic>{};
      for (final op in await _db.getOutboxOpsByType(updateGroupOp)) {
        if (op.entityId != groupId) continue;
        final older = _payloadPatch(op);
        if (older == null || _isZonesOnly(older) != zonesOnly) continue;
        // Never fold into an op the drain may be sending right now; a
        // second, newer request is harmless (the patch is absolute).
        if (op.lastAttemptAt != null) continue;
        merged.addAll(older);
        await _db.deleteOutboxOp(op.id);
      }
      merged.addAll(patch);
      final opId = _uuid.v4();
      await _db.enqueueOutbox(
        id: opId,
        type: updateGroupOp,
        payload: {'groupId': groupId, 'patch': merged},
        // Unique per write: the server remembers a key with its body hash,
        // and a later rename with a reused key would be refused.
        idempotencyKey: '$updateGroupOp:$groupId:$opId',
        entityType: 'group',
        entityId: groupId,
      );
      result = await _patchCaches(groupId, (g) => _applyPatch(g, patch));
    });
    // Outside the transaction: a drain started inside it would bind its
    // bookkeeping to a transaction that has already committed.
    final onLocalWrite = _onLocalWrite;
    if (onLocalWrite != null) {
      onLocalWrite();
    } else {
      unawaited(drainOutboxOnce().catchError((_) {}));
    }
    return result;
  }

  Future<void> drainOutboxOnce() async {
    await OutboxDrainer(_db).drain(
      types: const [updateGroupOp],
      handlers: {
        updateGroupOp: (op, payload) async {
          final groupId = payload['groupId'] as String;
          final patch = (payload['patch'] as Map).cast<String, dynamic>();
          final updated = await _groups.updateGroup(
            groupId,
            UpdateGroupRequest(
              name: patch['name'] as String?,
              description: patch['description'] as String?,
              currency: patch['currency'] as String?,
              choreZones: (patch['chore_zones'] as List?)?.cast<String>(),
            ),
          );
          await _db.deleteOutboxOp(op.id);
          await _cacheServerGroup(updated);
        },
      },
    );
  }

  /// Lays every still-queued detail edit for [group] on top of it, oldest
  /// first. Used wherever a server copy of a household is cached (this
  /// repository, the Home aggregate), so a refresh that lands before the
  /// drain does not undo an offline rename.
  static Future<Group> withPendingEdits(AppDatabase db, Group group) async {
    var patched = group;
    for (final op in await db.getOutboxOpsByType(updateGroupOp)) {
      if (op.entityId != group.id) continue;
      final patch = _payloadPatch(op);
      if (patch != null) patched = _applyPatch(patched, patch);
    }
    return patched;
  }

  /// Writes a server copy of a household into the list and Home caches.
  Future<void> _cacheServerGroup(Group group) async {
    await _patchCaches(group.id, (_) => group);
  }

  /// Applies [change] to the household in the list cache and in its Home
  /// cache row, re-laying queued edits on top. Returns the patched household
  /// (from the list cache, else the Home cache), or null when neither holds
  /// it.
  Future<Group?> _patchCaches(
    String groupId,
    Group Function(Group current) change,
  ) async {
    Group? result;
    final groups = await getGroupsOnce();
    if (groups.any((g) => g.id == groupId)) {
      final next = [
        for (final g in groups)
          if (g.id == groupId) change(g) else g,
      ];
      await _persist(next);
      result =
          await withPendingEdits(_db, next.firstWhere((g) => g.id == groupId));
    }
    final hubRow = await _db.getHubGroupOnce(groupId);
    final hubGroup = _decodeGroup(hubRow?.groupJson);
    if (hubGroup != null) {
      final patched = await withPendingEdits(_db, change(hubGroup));
      await _db.upsertHubGroup(
        groupId: groupId,
        groupJson: jsonEncode(patched.toJson()),
      );
      result ??= patched;
    }
    return result;
  }

  Future<Group?> _cachedGroup(String groupId) async {
    final groups = await getGroupsOnce();
    for (final g in groups) {
      if (g.id == groupId) return g;
    }
    final hubRow = await _db.getHubGroupOnce(groupId);
    return _decodeGroup(hubRow?.groupJson);
  }

  /// The household as last cached on this device, or null. For screens that
  /// must paint a household's details offline (its settings sheet).
  Future<Group?> getCachedGroup(String groupId) => _cachedGroup(groupId);

  /// [group] with its still-queued detail edits applied; see
  /// [withPendingEdits].
  Future<Group> applyPendingEdits(Group group) => withPendingEdits(_db, group);

  static Map<String, dynamic> _patchOf(UpdateGroupRequest request) => {
        if (request.name != null) 'name': request.name,
        if (request.description != null) 'description': request.description,
        if (request.currency != null) 'currency': request.currency,
        if (request.choreZones != null) 'chore_zones': request.choreZones,
      };

  static bool _isZonesOnly(Map<String, dynamic> patch) =>
      patch.length == 1 && patch.containsKey('chore_zones');

  static Map<String, dynamic>? _payloadPatch(OutboxOp op) {
    try {
      final payload = jsonDecode(op.payloadJson);
      if (payload is! Map || payload['patch'] is! Map) return null;
      return (payload['patch'] as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  static Group _applyPatch(Group g, Map<String, dynamic> patch) => Group(
        id: g.id,
        name: patch['name'] as String? ?? g.name,
        description: patch.containsKey('description')
            ? patch['description'] as String?
            : g.description,
        isPersonal: g.isPersonal,
        memberCount: g.memberCount,
        currency: patch['currency'] as String? ?? g.currency,
        choreZones:
            (patch['chore_zones'] as List?)?.cast<String>() ?? g.choreZones,
        createdAt: g.createdAt,
        updatedAt: g.updatedAt,
      );

  static Group? _decodeGroup(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return Group.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  List<Group> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => Group.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
