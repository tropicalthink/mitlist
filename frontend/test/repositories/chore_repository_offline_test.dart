import 'dart:convert';

import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/repositories/chore_repository.dart';
import 'package:mitlist/storage/app_database.dart';

import '../support/fakes.dart';

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

/// Seeds the current-chores cache with one chore that has a pending assignment.
Future<void> _seedChore(
  AppDatabase db,
  String groupId,
  String choreId, {
  required String status,
  String? dueDate,
  String dueStatus = 'overdue',
}) async {
  final blob = [
    {
      'chore': {'id': choreId, 'name': 'Dishes', 'is_active': true},
      'pending_assignment': {
        'id': 'a1',
        'chore_id': choreId,
        'status': status,
        'due_date': dueDate,
      },
      'due_status': dueStatus,
    }
  ];
  await db.upsertCurrentChores(groupId: groupId, choresJson: jsonEncode(blob));
}

Map<String, dynamic> _firstAssignment(String choresJson) {
  final list = jsonDecode(choresJson) as List;
  return (list.first as Map)['pending_assignment'] as Map<String, dynamic>;
}

String _firstDueStatus(String choresJson) {
  final list = jsonDecode(choresJson) as List;
  return (list.first as Map)['due_status'] as String;
}

void main() {
  group('ChoreRepository offline optimistic patches —', () {
    late AppDatabase db;
    late ChoreRepository repo;
    const groupId = 'g1';
    const choreId = 'c1';

    setUp(() {
      db = _memoryDb();
      repo = ChoreRepository(db: db, remote: FakeChoreService());
    });

    tearDown(() => db.close());

    test('skip patches cached assignment status to skipped', () async {
      await _seedChore(db, groupId, choreId, status: 'pending');

      await repo.skipOfflineFirst(choreId, groupId: groupId);

      final row = await db.getCurrentChoresOnce(groupId);
      expect(_firstAssignment(row!.choresJson)['status'], 'skipped');
      // The op was queued for the eventual drain.
      expect(await db.outboxCount(), greaterThan(0));
    });

    test('reschedule patches due date and re-derives due_status', () async {
      await _seedChore(
        db,
        groupId,
        choreId,
        status: 'pending',
        dueDate: '2020-01-01T00:00:00.000',
        dueStatus: 'overdue',
      );

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await repo.rescheduleOfflineFirst(choreId, tomorrow, groupId: groupId);

      final row = await db.getCurrentChoresOnce(groupId);
      final assignment = _firstAssignment(row!.choresJson);
      expect(DateTime.parse(assignment['due_date'] as String).day, tomorrow.day);
      // Tomorrow is no longer overdue.
      expect(_firstDueStatus(row.choresJson), isNot('overdue'));
    });
  });
}
