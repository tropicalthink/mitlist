import 'dart:convert';

import '../models/calendar_models.dart';
import '../services/calendar_service.dart';
import '../services/response_cache_interceptor.dart';
import '../storage/app_database.dart';
import 'meal_plan_repository.dart';

/// Read-through cache for the household calendar.
///
/// Calendar is a range query, so the cache is keyed by window as well as
/// household — a single row per group would be overwritten every time the user
/// paged to another month, which is exactly when a cache is most useful.
///
/// Read-only by design: the calendar is a projection of chores, meal plans and
/// expenses, all of which have their own write paths. Caching it makes the
/// screen render offline; it does not make the calendar itself editable. Meals
/// planned, moved or removed offline are laid over every read (see
/// [MealPlanRepository.applyPendingToCalendar]) so the calendar agrees with
/// the planner before the server has seen the change.
class CalendarRepository {
  final AppDatabase _db;
  final CalendarService _remote;

  CalendarRepository({
    required AppDatabase db,
    required CalendarService remote,
  })  : _db = db,
        _remote = remote;

  /// Stable cache key for a window. Dates only — the calendar API is
  /// day-granular, so two requests for the same days must share a row.
  static String rangeKey(DateTime from, DateTime to) =>
      '${_day(from)}_${_day(to)}';

  static String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Events for [from]..[to], refreshed from the network and persisted.
  ///
  /// Returns the cached window instead of throwing when the network fails, so
  /// a calendar opened offline shows the last thing we knew rather than an
  /// error. Rethrows only when there is nothing cached to fall back to —
  /// mirroring `GroupRepository.loadGroups`.
  Future<List<CalendarEvent>> load(
    String groupId,
    DateTime from,
    DateTime to,
  ) async {
    final key = rangeKey(from, to);
    try {
      // Live only: the answer is persisted below, and a stale HTTP body
      // served offline would overwrite a newer cached window.
      final raw = await ResponseCacheInterceptor.liveOnly(
          () => _remote.getCalendarRaw(groupId, from, to));
      await _db.upsertCalendarRange(
        groupId: groupId,
        rangeKey: key,
        eventsJson: jsonEncode(raw),
      );
      return await _withPendingMeals(
          CalendarService.parseCalendarEvents(raw), groupId, from, to);
    } catch (_) {
      final cached = await getCached(groupId, from, to);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// The cached window, or null when this range was never fetched.
  ///
  /// Null and empty are deliberately different: "we have never loaded this
  /// month" must not render as "nothing is scheduled".
  Future<List<CalendarEvent>?> getCached(
    String groupId,
    DateTime from,
    DateTime to,
  ) async {
    final row = await _db.getCalendarRange(groupId, rangeKey(from, to));
    if (row == null) return null;
    try {
      final decoded = jsonDecode(row.eventsJson);
      if (decoded is! List) return null;
      return await _withPendingMeals(
          CalendarService.parseCalendarEvents(decoded), groupId, from, to);
    } catch (_) {
      return null;
    }
  }

  Future<List<CalendarEvent>> _withPendingMeals(
    List<CalendarEvent> events,
    String groupId,
    DateTime from,
    DateTime to,
  ) async {
    final withMeals = MealPlanRepository.applyPendingToCalendar(
      events,
      await MealPlanRepository.pendingChanges(_db),
      groupId: groupId,
      from: from,
      to: to,
    );
    // A chore deleted here (calendar or chores tab) is gone for the user even
    // while its delete waits in the outbox; the server would still list it.
    final deletedChores = <String>{};
    for (final op in await _db.getOutboxOpsByType('deleteChore')) {
      try {
        final payload = jsonDecode(op.payloadJson);
        final id = payload is Map ? payload['choreId'] : null;
        if (id is String) deletedChores.add(id);
      } catch (_) {
        // Malformed ops are the drainer's problem.
      }
    }
    if (deletedChores.isEmpty) return withMeals;
    return withMeals
        .where((e) => !(e.type == CalendarEventType.chore &&
            deletedChores.contains(e.chore?.choreId)))
        .toList();
  }
}
