import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/models/calendar_models.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/models/meal_plan_models.dart';
import 'package:mitlist/models/recipe_models.dart';
import 'package:mitlist/repositories/calendar_repository.dart';
import 'package:mitlist/repositories/meal_plan_repository.dart';
import 'package:mitlist/services/calendar_service.dart';
import 'package:mitlist/services/meal_plan_service.dart';
import 'package:mitlist/storage/app_database.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

DioException _offline() => DioException(
      requestOptions: RequestOptions(path: '/meal-plans'),
      type: DioExceptionType.connectionError,
    );

const _groupId = 'g1';
const _recipeId = '11111111-1111-1111-1111-111111111111';

Map<String, dynamic> _planJson(String id, String date,
        {String slot = 'dinner', int servings = 2}) =>
    {
      'id': id,
      'group_id': _groupId,
      'date': date,
      'slot': slot,
      'recipe_id': _recipeId,
      'servings': servings,
      'created_at': '2026-10-01T00:00:00Z',
      'updated_at': '2026-10-01T00:00:00Z',
    };

/// Answers like the API while [offline] is false; throws a connection error
/// for every call once it is true.
class _FakeMealPlanService implements MealPlanService {
  bool offline = false;
  List<dynamic> plans = [];
  final List<({Map<String, dynamic> body, String? key})> creates = [];
  final List<({String id, Map<String, dynamic> body})> updates = [];
  final List<String> deletes = [];
  final List<String> flushes = [];
  int _next = 0;

  @override
  Future<List<dynamic>> listMealPlansRaw(
    String groupId, {
    required String from,
    required String to,
  }) async {
    if (offline) throw _offline();
    return plans;
  }

  @override
  Future<MealPlan> createMealPlanRaw(Map<String, dynamic> body,
      {String? idempotencyKey}) async {
    if (offline) throw _offline();
    creates.add((body: body, key: idempotencyKey));
    final id = '00000000-0000-0000-0000-00000000000${_next++}';
    return MealPlan.fromJson(_planJson(id, body['date'] as String,
        slot: body['slot'] as String, servings: body['servings'] as int));
  }

  @override
  Future<MealPlan> updateMealPlanRaw(String id, Map<String, dynamic> body,
      {String? idempotencyKey}) async {
    if (offline) throw _offline();
    updates.add((id: id, body: body));
    return MealPlan.fromJson(
        _planJson(id, '2026-10-14', servings: body['servings'] as int? ?? 2));
  }

  @override
  Future<void> deleteMealPlanRaw(String id, {String? idempotencyKey}) async {
    if (offline) throw _offline();
    deletes.add(id);
  }

  @override
  Future<void> flushMealPlanNotifications(String groupId) async {
    flushes.add(groupId);
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('unexpected: ${i.memberName}');
}

class _FakeCalendarService implements CalendarService {
  bool offline = false;
  List<dynamic> events = [];

  @override
  Future<List<dynamic>> getCalendarRaw(
      String groupId, DateTime from, DateTime to) async {
    if (offline) throw _offline();
    return events;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('unexpected: ${i.memberName}');
}

void main() {
  late AppDatabase db;
  late _FakeMealPlanService remote;
  late MealPlanRepository repo;

  const from = '2026-10-12';
  const to = '2026-10-18';

  setUp(() {
    db = _memoryDb();
    remote = _FakeMealPlanService();
    // autoSync off: each test drains explicitly, like the coordinator would.
    repo = MealPlanRepository(db: db, remote: remote, autoSync: false);
  });

  tearDown(() => db.close());

  group('MealPlanRepository offline writes —', () {
    test('a meal planned offline shows in a week that was never fetched',
        () async {
      remote.offline = true;
      final plan = await repo.createOfflineFirst(
        const CreateMealPlanRequest(
          groupId: _groupId,
          date: '2026-10-14',
          recipeId: _recipeId,
          servings: 3,
        ),
        recipeTitle: 'Lasagna',
      );

      expect(plan.id, startsWith(MealPlanRepository.localIdPrefix));
      final week = await repo.load(_groupId, from: from, to: to);
      expect(week.map((p) => p.id), [plan.id]);
      expect(week.single.servings, 3);
      // Another week does not get it.
      expect(
        () => repo.load(_groupId, from: '2026-10-19', to: '2026-10-25'),
        throwsA(isA<DioException>()),
      );
    });

    test('a refresh before the drain keeps the queued meal on screen',
        () async {
      remote.plans = [_planJson('server-a', '2026-10-13')];
      await repo.load(_groupId, from: from, to: to);

      final local = await repo.createOfflineFirst(const CreateMealPlanRequest(
        groupId: _groupId,
        date: '2026-10-15',
        recipeId: _recipeId,
      ));

      // Online refresh: the server does not know the new meal yet.
      final online = await repo.load(_groupId, from: from, to: to);
      expect(online.map((p) => p.id), containsAll(['server-a', local.id]));

      // Offline: the cached week plus the queued meal.
      remote.offline = true;
      final offline = await repo.load(_groupId, from: from, to: to);
      expect(offline.map((p) => p.id), containsAll(['server-a', local.id]));
    });

    test('queued remove and move are applied to every read', () async {
      remote.plans = [
        _planJson('server-a', '2026-10-13'),
        _planJson('server-b', '2026-10-14'),
      ];
      final week = await repo.load(_groupId, from: from, to: to);
      final a = week.firstWhere((p) => p.id == 'server-a');
      final b = week.firstWhere((p) => p.id == 'server-b');

      await repo.deleteOfflineFirst(a);
      // Moved into next week: leaves this one, shows in that one.
      await repo.updateOfflineFirst(
          b, const UpdateMealPlanRequest(date: '2026-10-20'));

      remote.offline = true;
      expect(await repo.load(_groupId, from: from, to: to), isEmpty);
      final next =
          await repo.load(_groupId, from: '2026-10-19', to: '2026-10-25');
      expect(next.map((p) => p.id), ['server-b']);
      expect(MealPlanRepository.day(next.single.date), '2026-10-20');
    });

    test('drain replays in order and points later ops at the server id',
        () async {
      remote.plans = [];
      await repo.load(_groupId, from: from, to: to);
      final local = await repo.createOfflineFirst(const CreateMealPlanRequest(
        groupId: _groupId,
        date: '2026-10-14',
        recipeId: _recipeId,
      ));
      await repo.updateOfflineFirst(
          local, const UpdateMealPlanRequest(servings: 5));

      // Offline: nothing is lost and no attempt is burnt.
      remote.offline = true;
      await repo.drainOutboxOnce();
      expect(await db.outboxCount(), 2);
      final ops = await db.getOutboxOpsByType(MealPlanRepository.createType);
      expect(ops.single.attemptCount, 0);

      // Back online. The backoff stamped above would hold the op for 5s.
      remote.offline = false;
      await db.customStatement('UPDATE outbox_ops SET last_attempt_at = NULL');
      await repo.drainOutboxOnce();

      expect(await db.outboxCount(), 0);
      expect(remote.creates.single.key, 'createMealPlan:${local.id}');
      expect(remote.creates.single.body['recipe_id'], _recipeId);
      final serverId = remote.updates.single.id;
      expect(serverId, isNot(startsWith('local-')));
      expect(remote.updates.single.body, {'servings': 5});
      expect(MealPlanRepository.resolveId(local.id), serverId);

      // The synced meal stays in the cached week for the next offline read.
      remote.offline = true;
      final cached = await repo.load(_groupId, from: from, to: to);
      expect(cached.map((p) => p.id), [serverId]);
    });

    test('notification digest waits for queued edits to sync', () async {
      remote.offline = true;
      await repo.createOfflineFirst(const CreateMealPlanRequest(
        groupId: _groupId,
        date: '2026-10-14',
        recipeId: _recipeId,
      ));
      await repo.releaseNotifications(_groupId);
      expect(remote.flushes, isEmpty);

      remote.offline = false;
      await db.customStatement('UPDATE outbox_ops SET last_attempt_at = NULL');
      await repo.drainOutboxOnce();
      expect(remote.flushes, [_groupId]);
    });
  });

  group('MealPlanRepository shopping list —', () {
    test('builds an aggregated, scaled list through the list outbox', () async {
      remote.offline = true;
      // Two dinners of the same recipe, 4 and 2 servings of a 2-serving one.
      await repo.createOfflineFirst(const CreateMealPlanRequest(
          groupId: _groupId,
          date: '2026-10-13',
          recipeId: _recipeId,
          servings: 4));
      await repo.createOfflineFirst(const CreateMealPlanRequest(
          groupId: _groupId,
          date: '2026-10-14',
          recipeId: _recipeId,
          servings: 2));

      final createdLists = <CreateListRequest>[];
      final createdItems = <CreateListItemRequest>[];
      final result = await repo.generateShoppingListOfflineFirst(
        groupId: _groupId,
        from: from,
        to: to,
        recipeOf: (_) async => Recipe(
          id: _recipeId,
          title: 'Pasta',
          description: '',
          prepTime: 0,
          cookTime: 0,
          servings: 2,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        ingredientsOf: (_) async => const [
          RecipeIngredient(
              id: 'i1',
              recipeId: _recipeId,
              name: 'Pasta',
              quantity: 200,
              unit: 'g'),
          RecipeIngredient(id: 'i2', recipeId: _recipeId, name: 'Basil'),
        ],
        createList: (req) async {
          createdLists.add(req);
          return ItemList(
            id: 'local-list',
            groupId: req.groupId,
            name: req.name,
            type: req.type,
            itemCount: 0,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          );
        },
        createItem: (listId, req) async => createdItems.add(req),
      );

      expect(result.listId, 'local-list');
      expect(result.itemCount, 2);
      expect(createdLists.single.name, 'Shopping $from');
      final pasta = createdItems.firstWhere((i) => i.name == 'Pasta');
      // 200g × (4/2) + 200g × (2/2)
      expect(pasta.quantity, 600);
      expect(pasta.unit, 'g');
      // No amount: one portion per scaled serving, as on the server.
      expect(createdItems.firstWhere((i) => i.name == 'Basil').quantity, 3);
    });

    test('reports missing ingredients instead of an empty list', () async {
      remote.offline = true;
      await repo.createOfflineFirst(const CreateMealPlanRequest(
          groupId: _groupId, date: '2026-10-13', recipeId: _recipeId));

      expect(
        () => repo.generateShoppingListOfflineFirst(
          groupId: _groupId,
          from: from,
          to: to,
          recipeOf: (_) async => null,
          ingredientsOf: (_) async => throw _offline(),
          createList: (_) async => throw StateError('no list expected'),
          createItem: (_, __) async {},
        ),
        throwsA(isA<MealPlanShoppingListException>().having((e) => e.reason,
            'reason', MealPlanShoppingListFailure.ingredientsUnavailable)),
      );
    });
  });

  group('CalendarRepository —', () {
    test('shows meals planned offline on top of the cached month', () async {
      final calendarRemote = _FakeCalendarService()
        ..events = [
          {
            'id': 'chore-1',
            'type': 'chore',
            'title': 'Bins',
            'date': '2026-10-13T00:00:00Z',
            'group_id': _groupId,
          },
        ];
      final calendar = CalendarRepository(db: db, remote: calendarRemote);
      final monthFrom = DateTime(2026, 10, 1);
      final monthTo = DateTime(2026, 10, 31);
      await calendar.load(_groupId, monthFrom, monthTo);

      remote.offline = true;
      await repo.createOfflineFirst(
        const CreateMealPlanRequest(
            groupId: _groupId, date: '2026-10-14', recipeId: _recipeId),
        recipeTitle: 'Lasagna',
      );

      calendarRemote.offline = true;
      final events = await calendar.load(_groupId, monthFrom, monthTo);
      final meal =
          events.singleWhere((e) => e.type == CalendarEventType.mealPlan);
      expect(meal.title, 'Lasagna');
      expect(meal.date, DateTime(2026, 10, 14));
      expect(
          events.where((e) => e.type == CalendarEventType.chore), hasLength(1));
    });

    test('hides a chore whose delete is still queued', () async {
      final calendarRemote = _FakeCalendarService()
        ..events = [
          {
            'id': 'a1',
            'type': 'chore',
            'title': 'Bins',
            'date': '2026-10-13T00:00:00Z',
            'group_id': _groupId,
            'chore': {
              'chore_id': 'chore-1',
              'assignment_id': 'a1',
              'user_id': 'u1',
              'status': 'pending',
            },
          },
        ];
      final calendar = CalendarRepository(db: db, remote: calendarRemote);
      await db.enqueueOutbox(
        id: 'op1',
        type: 'deleteChore',
        payload: {'choreId': 'chore-1', 'groupId': _groupId},
      );
      final events = await calendar.load(
          _groupId, DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      expect(events, isEmpty);
      // Sanity: the payload helper used above matches what the chores
      // repository queues.
      expect(
          jsonDecode((await db.getOutboxOpById('op1'))!.payloadJson)['choreId'],
          'chore-1');
    });
  });
}
