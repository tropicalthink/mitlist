import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/models/home_models.dart';
import 'package:mitlist/models/pinwall_models.dart';
import 'package:mitlist/repositories/hub_repository.dart';
import 'package:mitlist/repositories/pinwall_repository.dart';
import 'package:mitlist/repositories/recipe_repository.dart';
import 'package:mitlist/services/activity_service.dart';
import 'package:mitlist/services/api_error_mapper.dart';
import 'package:mitlist/services/group_service.dart';
import 'package:mitlist/services/home_service.dart';
import 'package:mitlist/services/pinwall_service.dart';
import 'package:mitlist/services/recipe_service.dart';
import 'package:mitlist/storage/app_database.dart';

const _groupId = '11111111-1111-1111-1111-111111111111';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

Group _group(String name) => Group(
      id: _groupId,
      name: name,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

class _HomeService implements HomeService {
  Object? error;
  HomeSnapshot? snapshot;

  @override
  Future<HomeSnapshot> getSnapshot(String groupId,
      {required String date}) async {
    final e = error;
    if (e != null) Error.throwWithStackTrace(e, StackTrace.current);
    return snapshot!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Records whether the pre-aggregate fallback was tried at all.
class _GroupService implements GroupService {
  int getGroupCalls = 0;

  @override
  Future<Group> getGroup(String groupId) async {
    getGroupCalls++;
    return _group('Stale');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Unused implements ActivityService, RecipeService, PinwallService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late AppDatabase db;
  late _HomeService home;
  late _GroupService groups;
  late HubRepository hub;

  setUp(() async {
    db = _memoryDb();
    home = _HomeService();
    groups = _GroupService();
    hub = HubRepository(
      db: db,
      groups: groups,
      activity: _Unused(),
      home: home,
      recipes: RecipeRepository(db: db, remote: _Unused()),
    );
    await db.upsertHubGroup(
      groupId: _groupId,
      groupJson: jsonEncode(_group('Home').toJson()),
    );
  });

  tearDown(() => db.close());

  test('offline, a refresh fails without touching the cache or the fallback',
      () async {
    home.error = ApiException(
      'offline',
      cause: DioException(
        requestOptions: RequestOptions(path: '/groups/$_groupId/home'),
        type: DioExceptionType.connectionError,
      ),
    );

    await expectLater(hub.refresh(_groupId), throwsA(isA<ApiException>()));

    expect(groups.getGroupCalls, 0,
        reason: 'the fallback would only be answered from a stale cache');
    expect((await hub.getGroupOnce(_groupId))?.name, 'Home');
  });

  test('a snapshot keeps notes pinned offline that have not synced yet',
      () async {
    final pinwall =
        PinwallRepository(db: db, remote: _Unused(), onLocalWrite: () {});
    final tempId = await pinwall.createPostOfflineFirst(_groupId,
        content: 'offline note', userId: 'u1');
    home.snapshot = HomeSnapshot(
      group: _group('Home'),
      activities: const [],
      activityError: false,
      pinwallPosts: [
        PinwallPost(
          id: 'server-1',
          groupId: _groupId,
          userId: 'u2',
          content: 'from the server',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      ],
      pinwallError: false,
      todayMeals: const [],
      todayMealError: true,
    );

    await hub.refresh(_groupId);

    final posts = await pinwall.getPostsOnce(_groupId);
    expect(posts.map((p) => p.id), [tempId, 'server-1']);
  });
}
