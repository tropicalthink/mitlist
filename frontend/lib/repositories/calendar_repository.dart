import 'dart:convert';

import '../models/calendar_models.dart';
import '../services/calendar_service.dart';
import '../storage/app_database.dart';

/// Read-through cache for the household calendar.
///
/// Calendar is a range query, so the cache is keyed by window as well as
/// household — a single row per group would be overwritten every time the user
/// paged to another month, which is exactly when a cache is most useful.
///
/// Read-only by design: the calendar is a projection of chores, meal plans and
/// expenses, all of which have their own write paths. Caching it makes the
/// screen render offline; it does not make the calendar itself editable.
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
      final raw = await _remote.getCalendarRaw(groupId, from, to);
      await _db.upsertCalendarRange(
        groupId: groupId,
        rangeKey: key,
        eventsJson: jsonEncode(raw),
      );
      return CalendarService.parseCalendarEvents(raw);
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
      return CalendarService.parseCalendarEvents(decoded);
    } catch (_) {
      return null;
    }
  }
}
