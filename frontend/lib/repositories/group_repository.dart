import 'dart:async' show unawaited;
import 'dart:convert';

import '../models/group_models.dart';
import '../services/group_service.dart';
import '../storage/app_database.dart';

/// Offline-first access to the current user's household list.
///
/// The list is cached as a single JSON row in Drift so every screen can resolve
/// its active group without a network round-trip. Reads come from the cache;
/// [loadGroups] refreshes from the network and falls back to the cache when
/// offline instead of throwing.
class GroupRepository {
  final AppDatabase _db;
  final GroupService _groups;

  GroupRepository({
    required AppDatabase db,
    required GroupService groups,
  })  : _db = db,
        _groups = groups;

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
        final fresh = await _groups.listGroups(limit: limit);
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
        await _persist(await _groups.listGroups(limit: limit));
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
    final fresh = await _groups.listGroups(limit: limit);
    await _persist(fresh);
    return fresh;
  }

  Future<void> _persist(List<Group> groups) {
    return _db.upsertGroupsList(
      jsonEncode(groups.map((g) => g.toJson()).toList()),
    );
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
