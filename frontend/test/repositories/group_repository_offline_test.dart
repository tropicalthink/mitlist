import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/repositories/group_repository.dart';
import 'package:mitlist/services/api_error_mapper.dart';
import 'package:mitlist/services/group_service.dart';
import 'package:mitlist/storage/app_database.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

Group _group(String id, String name, {String currency = 'EUR'}) => Group(
      id: id,
      name: name,
      currency: currency,
      memberCount: 2,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );

DioException _offline() => DioException(
      requestOptions: RequestOptions(path: '/groups'),
      type: DioExceptionType.connectionError,
    );

class _GroupService implements GroupService {
  List<Group> groups = [];
  Object? updateError;
  final updates = <(String, UpdateGroupRequest)>[];

  @override
  Future<List<Group>> listGroups({int limit = 50, int offset = 0}) async =>
      List.of(groups);

  @override
  Future<Group> updateGroup(String groupId, UpdateGroupRequest request) async {
    final error = updateError;
    if (error != null) Error.throwWithStackTrace(error, StackTrace.current);
    updates.add((groupId, request));
    final current = groups.firstWhere((g) => g.id == groupId);
    final updated = Group(
      id: current.id,
      name: request.name ?? current.name,
      description: request.description ?? current.description,
      currency: request.currency ?? current.currency,
      memberCount: current.memberCount,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
    );
    groups = [
      for (final g in groups)
        if (g.id == groupId) updated else g,
    ];
    return updated;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late AppDatabase db;
  late _GroupService service;
  late bool offline;
  late int localWrites;
  late GroupRepository repo;

  setUp(() async {
    db = _memoryDb();
    service = _GroupService()..groups = [_group('g1', 'Home')];
    offline = false;
    localWrites = 0;
    repo = GroupRepository(
      db: db,
      groups: service,
      onLocalWrite: () => localWrites++,
      isKnownOffline: () => offline,
    );
    await repo.refreshGroups();
    await db.upsertHubGroup(
      groupId: 'g1',
      groupJson: jsonEncode(_group('g1', 'Home').toJson()),
    );
  });

  tearDown(() => db.close());

  Future<Group> hubGroup() async => Group.fromJson(
      (jsonDecode((await db.getHubGroupOnce('g1'))!.groupJson) as Map)
          .cast<String, dynamic>());

  test('offline, a rename is applied to every cached copy and queued',
      () async {
    offline = true;

    final result = await repo.updateGroupOfflineFirst(
        'g1', const UpdateGroupRequest(name: 'Flat'));

    expect(result.queued, isTrue);
    expect(result.group?.name, 'Flat');
    expect(service.updates, isEmpty);
    expect((await repo.getGroupsOnce()).single.name, 'Flat');
    expect((await hubGroup()).name, 'Flat');
    expect(localWrites, 1);
    expect(await db.getOutboxOpsByType(GroupRepository.updateGroupOp),
        hasLength(1));
  });

  test('a request that cannot reach the server is queued too', () async {
    service.updateError = ApiException('offline', cause: _offline());

    final result = await repo.updateGroupOfflineFirst(
        'g1', const UpdateGroupRequest(name: 'Flat'));

    expect(result.queued, isTrue);
    expect((await repo.getGroupsOnce()).single.name, 'Flat');
  });

  test('a server refusal is rethrown and nothing is queued', () async {
    service.updateError = ApiException('forbidden',
        cause: DioException(
          requestOptions: RequestOptions(path: '/groups/g1'),
          response: Response(
            requestOptions: RequestOptions(path: '/groups/g1'),
            statusCode: 403,
          ),
          type: DioExceptionType.badResponse,
        ));

    await expectLater(
      repo.updateGroupOfflineFirst(
          'g1', const UpdateGroupRequest(name: 'Flat')),
      throwsA(isA<ApiException>()),
    );
    expect(await db.outboxCount(), 0);
    expect((await repo.getGroupsOnce()).single.name, 'Home');
  });

  test('queued edits coalesce, and a refresh keeps them on top', () async {
    offline = true;
    await repo.updateGroupOfflineFirst(
        'g1', const UpdateGroupRequest(name: 'Flat'));
    await repo.updateGroupOfflineFirst(
        'g1', const UpdateGroupRequest(currency: 'GBP'));

    final ops = await db.getOutboxOpsByType(GroupRepository.updateGroupOp);
    expect(ops, hasLength(1));
    expect(jsonDecode(ops.single.payloadJson)['patch'],
        {'name': 'Flat', 'currency': 'GBP'});

    // The server still has the old details.
    await repo.refreshGroups();
    final cached = (await repo.getGroupsOnce()).single;
    expect(cached.name, 'Flat');
    expect(cached.currency, 'GBP');
    expect(
        (await GroupRepository.withPendingEdits(db, _group('g1', 'Home'))).name,
        'Flat');
  });

  test('chore zone edits are not folded into admin-only detail edits',
      () async {
    offline = true;
    await repo.updateGroupOfflineFirst(
        'g1', const UpdateGroupRequest(name: 'Flat'));
    await repo.queueGroupUpdate(
        'g1', const UpdateGroupRequest(choreZones: ['Kitchen']));

    expect(await db.getOutboxOpsByType(GroupRepository.updateGroupOp),
        hasLength(2));
    expect((await repo.getGroupsOnce()).single.choreZones, ['Kitchen']);
  });

  test('the drain sends the queued patch and caches the answer', () async {
    offline = true;
    await repo.updateGroupOfflineFirst(
        'g1', const UpdateGroupRequest(name: 'Flat', currency: 'GBP'));

    await repo.drainOutboxOnce();

    expect(service.updates.single.$2.name, 'Flat');
    expect(service.updates.single.$2.currency, 'GBP');
    expect(service.updates.single.$2.description, isNull);
    expect(await db.outboxCount(), 0);
    expect((await repo.getGroupsOnce()).single.name, 'Flat');
    expect((await hubGroup()).name, 'Flat');
  });
}
