import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chore_service.dart';
import '../models/chore_models.dart';
import '../providers/list_provider.dart';
import '../repositories/chore_repository.dart';

final choreServiceProviderAsync = FutureProvider<ChoreService>((ref) async {
  return await ChoreService.create(ref);
});

final choreRepositoryProvider = FutureProvider<ChoreRepository>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final service = await ref.read(choreServiceProviderAsync.future);
  return ChoreRepository(db: db, remote: service);
});

final cachedCurrentChoresByGroupProvider =
    StreamProvider.family<List<CurrentChore>, String>((ref, groupId) async* {
  ref.keepAlive();
  final repo = await ref.watch(choreRepositoryProvider.future);
  yield* repo.watchCurrentChores(groupId);
});

final choresByGroupProvider = FutureProvider.family<List<Chore>, String>((ref, groupId) async {
  final service = await ref.read(choreServiceProviderAsync.future);
  return service.listChores(groupId);
});

class WeeklyChoresProgress {
  final int dueCount;
  final int completedCount;
  final DateTime weekStart;
  final DateTime weekEnd;

  const WeeklyChoresProgress({
    required this.dueCount,
    required this.completedCount,
    required this.weekStart,
    required this.weekEnd,
  });

  double get progress {
    if (dueCount <= 0) return 0;
    return completedCount / dueCount;
  }
}

final weeklyChoresProgressByGroupProvider =
    FutureProvider.family<WeeklyChoresProgress, String>((ref, groupId) async {
  final choreService = await ref.read(choreServiceProviderAsync.future);
  final chores = await ref.read(choresByGroupProvider(groupId).future);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - DateTime.monday));
  final weekEnd = weekStart.add(const Duration(days: 7));

  final active = chores.where((c) => c.isActive).toList();
  if (active.isEmpty) {
    return WeeklyChoresProgress(
      dueCount: 0,
      completedCount: 0,
      weekStart: weekStart,
      weekEnd: weekEnd,
    );
  }

  final assignmentsByChore = await Future.wait(
    active.map((c) async {
      try {
        final assignments = await choreService.listAssignments(c.id, limit: 200, offset: 0);
        return assignments;
      } catch (_) {
        return <ChoreAssignment>[];
      }
    }),
  );

  var dueCount = 0;
  var completedCount = 0;
  for (final assignments in assignmentsByChore) {
    for (final a in assignments) {
      final due = a.dueDate;
      if (due == null) continue;
      if (due.isBefore(weekStart) || !due.isBefore(weekEnd)) continue;

      dueCount += 1;
      final completedAt = a.completedAt;
      final completedInWindow = completedAt != null &&
          !completedAt.isBefore(weekStart) &&
          completedAt.isBefore(weekEnd);
      final completedByStatus = a.status.toLowerCase() == 'completed';
      if (completedInWindow || completedByStatus) {
        completedCount += 1;
      }
    }
  }

  return WeeklyChoresProgress(
    dueCount: dueCount,
    completedCount: completedCount,
    weekStart: weekStart,
    weekEnd: weekEnd,
  );
});
