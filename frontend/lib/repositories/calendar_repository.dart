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
      // Other cached windows overlapping this one must not keep showing a
      // housemate's event the server no longer returns (unshared, hidden,
      // deleted). Best effort: the fresh window is already saved.
      try {
        await _dropStaleExternal(groupId, key, from, to, raw);
      } catch (_) {}
      return await _withPendingMeals(
          CalendarService.parseCalendarEvents(raw), groupId, from, to);
    } catch (_) {
      final cached = await getCached(groupId, from, to);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Forgets every housemate's shared-calendar event in [groupId]'s cached
  /// windows (sent `calendar:external_changed`): what they share has
  /// changed, so nothing cached about it may be shown any more. The next
  /// fetch of each window brings back what is still shared.
  Future<void> forgetExternal(String groupId) async {
    for (final row in await _db.getCalendarRanges(groupId)) {
      final decoded = _decode(row.eventsJson);
      if (decoded == null) continue;
      final kept = decoded.where((e) => !_isExternal(e)).toList();
      if (kept.length == decoded.length) continue;
      await _db.upsertCalendarRange(
        groupId: groupId,
        rangeKey: row.rangeKey,
        eventsJson: jsonEncode(kept),
      );
    }
  }

  Future<void> _dropStaleExternal(
    String groupId,
    String freshKey,
    DateTime from,
    DateTime to,
    List<dynamic> fresh,
  ) async {
    final freshIds = <String>{
      for (final e in fresh)
        if (_isExternal(e) && (e as Map)['id'] is String) e['id'] as String,
    };
    // The server returns events overlapping [from, to + 1 day).
    final windowStart = DateTime(from.year, from.month, from.day);
    final windowEnd = DateTime(to.year, to.month, to.day + 1);
    for (final row in await _db.getCalendarRanges(groupId)) {
      if (row.rangeKey == freshKey) continue;
      final decoded = _decode(row.eventsJson);
      if (decoded == null) continue;
      final kept = decoded.where((e) {
        if (!_isExternal(e)) return true;
        final id = (e as Map)['id'];
        if (id is String && freshIds.contains(id)) return true;
        // Outside the fresh window the server said nothing about it.
        return !_overlaps(e, windowStart, windowEnd);
      }).toList();
      if (kept.length == decoded.length) continue;
      await _db.upsertCalendarRange(
        groupId: groupId,
        rangeKey: row.rangeKey,
        eventsJson: jsonEncode(kept),
      );
    }
  }

  static List<dynamic>? _decode(String json) {
    try {
      final decoded = jsonDecode(json);
      return decoded is List ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static bool _isExternal(Object? e) =>
      e is Map && e['type'] == 'external_event';

  /// Whether a raw external event overlaps [start, end) (local days). An
  /// event whose times cannot be read counts as overlapping, so it goes.
  static bool _overlaps(Object? e, DateTime start, DateTime end) {
    try {
      final parsed = CalendarEvent.fromJson((e as Map).cast<String, dynamic>());
      final x = parsed.external;
      if (x == null) return true;
      final s = x.startDay;
      final en = x.endDayExclusive;
      return s.isBefore(end) && en.isAfter(start);
    } catch (_) {
      return true;
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
