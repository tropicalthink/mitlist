import 'dart:convert';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/calendar_models.dart';
import 'package:mitlist/repositories/calendar_repository.dart';
import 'package:mitlist/services/calendar_service.dart';
import 'package:mitlist/storage/app_database.dart';

class _FakeCalendarService implements CalendarService {
  List<dynamic> next = [];
  Object? failWith;

  @override
  Future<List<dynamic>> getCalendarRaw(
      String groupId, DateTime from, DateTime to) async {
    final f = failWith;
    if (f != null) Error.throwWithStackTrace(f, StackTrace.current);
    return next;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> ext(String id, DateTime day, {String title = ''}) => {
      'id': id,
      'type': 'external_event',
      'title': title,
      'date': DateTime.utc(day.year, day.month, day.day).toIso8601String(),
      'group_id': 'g1',
      'external': {
        'user_id': 'sam',
        'starts_at':
            DateTime.utc(day.year, day.month, day.day).toIso8601String(),
        'ends_at':
            DateTime.utc(day.year, day.month, day.day + 1).toIso8601String(),
        'all_day': true,
        'busy_only': title.isEmpty,
        'free': false,
      },
    };

Map<String, dynamic> chore(String id, DateTime day) => {
      'id': id,
      'type': 'chore',
      'title': 'Bins',
      'date': day.toUtc().toIso8601String(),
      'group_id': 'g1',
    };

void main() {
  late AppDatabase db;
  late _FakeCalendarService remote;
  late CalendarRepository repo;

  setUp(() {
    db = AppDatabase(DatabaseConnection(NativeDatabase.memory(),
        closeStreamsSynchronously: true));
    remote = _FakeCalendarService();
    repo = CalendarRepository(db: db, remote: remote);
  });
  tearDown(() => db.close());

  List<String> ids(List<CalendarEvent>? events) =>
      [for (final e in events ?? const <CalendarEvent>[]) e.id];

  // A month and a week inside it, cached separately.
  final monthFrom = DateTime(2026, 12, 1);
  final monthTo = DateTime(2026, 12, 31);
  final weekFrom = DateTime(2026, 12, 6);
  final weekTo = DateTime(2026, 12, 12);

  test('a fresh window removes unshared events from overlapping cached ones',
      () async {
    remote.next = [
      ext('ext:trip', DateTime(2026, 12, 8), title: 'Lisbon'),
      ext('ext:later', DateTime(2026, 12, 20)),
      chore('c1', DateTime(2026, 12, 8)),
    ];
    await repo.load('g1', monthFrom, monthTo);

    // Sam stops sharing the trip: the week no longer returns it.
    remote.next = [chore('c1', DateTime(2026, 12, 8))];
    await repo.load('g1', weekFrom, weekTo);

    // Offline: the month comes from the cache.
    remote.failWith = StateError('offline');
    final month = await repo.load('g1', monthFrom, monthTo);
    expect(ids(month), containsAll(['c1', 'ext:later']));
    expect(ids(month), isNot(contains('ext:trip')));
  });

  test('events still returned stay in the other cached windows', () async {
    remote.next = [ext('ext:trip', DateTime(2026, 12, 8))];
    await repo.load('g1', monthFrom, monthTo);
    await repo.load('g1', weekFrom, weekTo);
    remote.failWith = StateError('offline');
    expect(ids(await repo.load('g1', monthFrom, monthTo)), ['ext:trip']);
  });

  test('calendar:external_changed forgets every cached shared event', () async {
    remote.next = [
      ext('ext:trip', DateTime(2026, 12, 8), title: 'Lisbon'),
      chore('c1', DateTime(2026, 12, 8)),
    ];
    await repo.load('g1', monthFrom, monthTo);
    await repo.load('g1', weekFrom, weekTo);

    await repo.forgetExternal('g1');

    expect(ids(await repo.getCached('g1', monthFrom, monthTo)), ['c1']);
    expect(ids(await repo.getCached('g1', weekFrom, weekTo)), ['c1']);
    final raw = await db.getCalendarRange(
        'g1', CalendarRepository.rangeKey(monthFrom, monthTo));
    expect(jsonEncode(raw!.eventsJson), isNot(contains('Lisbon')));
  });
}
