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

  /// Cache-first load with background-style refresh semantics: fetches from the
  /// network, persists the result, and returns it. If the network call fails
  /// but a cache exists, returns the cache (no throw) so the app keeps working
  /// offline. Rethrows only when there is nothing cached to fall back to.
  Future<List<Group>> loadGroups({int limit = 50}) async {
    final cached = await getGroupsOnce();
    try {
      final fresh = await _groups.listGroups(limit: limit);
      await _persist(fresh);
      return fresh;
    } catch (_) {
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
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
