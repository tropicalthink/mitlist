import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/repositories/group_repository.dart';
import 'package:mitlist/services/response_cache_interceptor.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/fakes.dart';

/// Answers `GET /groups` with [groups], or fails like a dead network.
class _GroupsAdapter implements HttpClientAdapter {
  List<Map<String, dynamic>>? groups;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = groups;
    if (body == null) {
      throw DioException.connectionError(
          requestOptions: options, reason: 'offline');
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

Group _group(String id) => Group(
      id: id,
      name: id,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  late AppDatabase db;
  late _GroupsAdapter adapter;
  late GroupRepository repo;

  setUp(() {
    db = AppDatabase(drift.DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ));
    adapter = _GroupsAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api'))
      ..httpClientAdapter = adapter
      ..interceptors.add(ResponseCacheInterceptor(
        store: () => DriftResponseCacheStore(db),
      ));
    // The real interceptor between the repository and a scripted transport,
    // so the HTTP cache is in play exactly as in the app.
    final service = FakeGroupService()
      ..listOverride = () async {
        final r = await dio.get('/groups');
        return (r.data as List)
            .map((g) => Group.fromJson((g as Map).cast<String, dynamic>()))
            .toList();
      };
    repo = GroupRepository(db: db, groups: service);
  });

  tearDown(() => db.close());

  test(
      'an offline refresh keeps a household the stale HTTP cache '
      'does not know about', () async {
    adapter.groups = [_group('g1').toJson()];
    await repo.refreshGroups();
    // Let the interceptor's fire-and-forget cache write land.
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // Created online a moment later; the server's answer seeded the cache.
    await repo.cacheGroup(_group('g2'));

    adapter.groups = null; // offline
    await expectLater(repo.refreshGroups(), throwsA(isA<Exception>()));
    expect((await repo.getGroupsOnce()).map((g) => g.id), ['g1', 'g2']);

    // The cache-first read's background refresh must not roll it back either.
    await repo.loadGroups();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect((await repo.getGroupsOnce()).map((g) => g.id), ['g1', 'g2']);
  });

  test('with nothing in Drift, the HTTP cache still answers offline', () async {
    adapter.groups = [_group('g1').toJson()];
    await repo.refreshGroups();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await db.upsertGroupsList('[]');

    adapter.groups = null;
    final groups = await repo.loadGroups();
    expect(groups.map((g) => g.id), ['g1']);
  });
}
