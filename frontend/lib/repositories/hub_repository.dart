import 'dart:convert';

import '../models/activity_models.dart';
import '../models/group_models.dart';
import '../services/activity_service.dart';
import '../services/group_service.dart';
import '../storage/app_database.dart';

class HubRepository {
  final AppDatabase _db;
  final GroupService _groups;
  final ActivityService _activity;

  HubRepository({
    required AppDatabase db,
    required GroupService groups,
    required ActivityService activity,
  })  : _db = db,
        _groups = groups,
        _activity = activity;

  Stream<Group?> watchGroup(String groupId) {
    return _db
        .watchHubGroup(groupId)
        .map((row) => _decodeGroup(row?.groupJson));
  }

  Future<Group?> getGroupOnce(String groupId) async {
    final row = await _db.getHubGroupOnce(groupId);
    return _decodeGroup(row?.groupJson);
  }

  Stream<(List<ActivityLogModel> activities, bool hadError)> watchActivities(
      String groupId) {
    return _db.watchHubActivities(groupId).map((row) {
      if (row == null) return (const <ActivityLogModel>[], false);
      return (_decodeActivities(row.activitiesJson), row.hadError);
    });
  }

  Future<(List<ActivityLogModel> activities, bool hadError)> getActivitiesOnce(
      String groupId) async {
    final row = await _db.getHubActivitiesOnce(groupId);
    if (row == null) return (const <ActivityLogModel>[], false);
    return (_decodeActivities(row.activitiesJson), row.hadError);
  }

  Future<void> refresh(String groupId, {int activityLimit = 10}) async {
    var activityError = false;
    final results = await Future.wait<Object>([
      _groups.getGroup(groupId),
      _activity
          .listActivityLogs(groupId, limit: activityLimit, offset: 0)
          .catchError((_) {
        activityError = true;
        return <ActivityLogModel>[];
      }),
    ]);
    final group = results[0] as Group;
    final activities = results[1] as List<ActivityLogModel>;
    await _db.upsertHubGroup(
        groupId: groupId, groupJson: jsonEncode(group.toJson()));
    await _db.upsertHubActivities(
      groupId: groupId,
      activitiesJson: jsonEncode(activities
          .map((a) => {
                'id': a.id,
                'group_id': a.groupId,
                'user_id': a.userId,
                'user_name': a.userName,
                'action': a.action,
                'entity_type': a.entityType,
                'entity_id': a.entityId,
                'title': a.title,
                'context': a.context,
                'metadata': a.metadata,
                'created_at': a.createdAt.toIso8601String(),
              })
          .toList()),
      hadError: activityError,
    );
  }

  Group? _decodeGroup(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return Group.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  List<ActivityLogModel> _decodeActivities(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => ActivityLogModel.fromJson(m.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
