import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

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

/// Serves one canned payload, then fails — so a second call exercises the
/// offline path against a cache the first call populated.
class _FakeCalendarService implements CalendarService {
  List<dynamic>? payload;
  int calls = 0;

  @override
  Future<List<dynamic>> getCalendarRaw(
      String groupId, DateTime from, DateTime to) async {
    calls++;
    final p = payload;
    if (p == null) throw StateError('offline: getCalendarRaw');
    return p;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('offline: ${i.memberName}');
}

class _FakeMealPlanService implements MealPlanService {
  List<dynamic>? payload;

  @override
  Future<List<dynamic>> listMealPlansRaw(
    String groupId, {
    required String from,
    required String to,
  }) async {
    final p = payload;
    if (p == null) throw StateError('offline: listMealPlansRaw');
    return p;
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw StateError('offline: ${i.memberName}');
}

Map<String, dynamic> _event(String id, String date) => {
      'id': id,
      'type': 'chore',
      'title': 'Take out bins',
      'date': date,
      'group_id': 'g1',
    };

void main() {
  group('CalendarRepository —', () {
    late AppDatabase db;
    late _FakeCalendarService remote;
    late CalendarRepository repo;

    final from = DateTime.utc(2026, 8, 1);
    final to = DateTime.utc(2026, 8, 31);

    setUp(() {
      db = _memoryDb();
      remote = _FakeCalendarService();
      repo = CalendarRepository(db: db, remote: remote);
    });

    tearDown(() => db.close());

    test('serves the cached window when the network fails', () async {
      remote.payload = [_event('e1', '2026-08-04T00:00:00Z')];
      await repo.load('g1', from, to);

      // Now offline.
      remote.payload = null;
      final events = await repo.load('g1', from, to);

      expect(events, hasLength(1));
      expect(events.single.id, 'e1',
          reason: 'the calendar must render the last known month offline');
    });

    test('rethrows when offline with nothing cached for that window', () async {
      expect(() => repo.load('g1', from, to), throwsA(isA<StateError>()),
          reason: 'an unseen month has no stale data to honestly show');
    });

    test('windows are cached independently', () async {
      remote.payload = [_event('aug', '2026-08-04T00:00:00Z')];
      await repo.load('g1', from, to);

      final sepFrom = DateTime.utc(2026, 9, 1);
      final sepTo = DateTime.utc(2026, 9, 30);
      remote.payload = [_event('sep', '2026-09-04T00:00:00Z')];
      await repo.load('g1', sepFrom, sepTo);

      remote.payload = null;
      final aug = await repo.load('g1', from, to);
      final sep = await repo.load('g1', sepFrom, sepTo);

      expect(aug.single.id, 'aug',
          reason: 'paging to another month must not evict the previous one');
      expect(sep.single.id, 'sep');
    });

    test('an unfetched window is null, not empty', () async {
      expect(await repo.getCached('g1', from, to), isNull,
          reason: '"never loaded" must not render as "nothing scheduled"');
    });

    test('prunes to the retention limit as windows accumulate', () async {
      remote.payload = [_event('e', '2026-01-01T00:00:00Z')];
      final extra = AppDatabase.kRangeCacheRetained + 5;
      for (var i = 0; i < extra; i++) {
        final start = DateTime.utc(2026, 1, 1).add(Duration(days: i * 31));
        await repo.load('g1', start, start.add(const Duration(days: 30)));
      }

      final rows = await db.select(db.calendarCaches).get();
      expect(rows.length, lessThanOrEqualTo(AppDatabase.kRangeCacheRetained),
          reason: 'browsing months must not grow the database without bound');
    });
  });

  group('MealPlanRepository —', () {
    late AppDatabase db;
    late _FakeMealPlanService remote;
    late MealPlanRepository repo;

    setUp(() {
      db = _memoryDb();
      remote = _FakeMealPlanService();
      repo = MealPlanRepository(db: db, remote: remote);
    });

    tearDown(() => db.close());

    test('serves the cached window when the network fails', () async {
      remote.payload = [
        {
          'id': 'mp1',
          'group_id': 'g1',
          'recipe_id': 'r1',
          'date': '2026-08-04T00:00:00Z',
          'slot': 'dinner',
          'created_at': '2026-08-01T00:00:00Z',
          'updated_at': '2026-08-01T00:00:00Z',
        }
      ];
      await repo.load('g1', from: '2026-08-04', to: '2026-08-04');

      remote.payload = null;
      final plans = await repo.load('g1', from: '2026-08-04', to: '2026-08-04');

      expect(plans, hasLength(1));
      expect(plans.single.id, 'mp1');
    });

    test('rethrows when offline with nothing cached', () async {
      expect(
        () => repo.load('g1', from: '2026-01-01', to: '2026-01-07'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
