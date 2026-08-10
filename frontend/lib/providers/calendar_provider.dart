import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/calendar_models.dart';
import '../repositories/calendar_repository.dart';
import '../services/calendar_service.dart';
import 'list_provider.dart' show appDatabaseProvider;

final calendarServiceProviderAsync =
    FutureProvider<CalendarService>((ref) async {
  return await CalendarService.create(ref);
});

/// Key for a cached calendar fetch. A record so it has value equality —
/// revisiting the same (group, range) reuses the cached provider instead of
/// refetching, and the screen keeps showing the last data while a new range
/// loads (no skeleton flash on navigation).
typedef CalendarRange = ({String groupId, DateTime from, DateTime to});

/// Cached, keep-alive calendar events for a (group, from, to) window. Kept
/// alive so paging back and forth is instant; a stale range self-disposes
/// after a few minutes to bound memory.
final calendarRepositoryProvider =
    FutureProvider<CalendarRepository>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final service = await ref.read(calendarServiceProviderAsync.future);
  return CalendarRepository(db: db, remote: service);
});

final calendarEventsProvider =
    FutureProvider.family<List<CalendarEvent>, CalendarRange>(
        (ref, range) async {
  final link = ref.keepAlive();
  final expiry = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(expiry.cancel);

  // Cache-backed: persists each window and falls back to it when the network
  // fails, so the calendar shows the last known month offline instead of an
  // error. The in-memory keepAlive above still handles same-session paging.
  final repo = await ref.read(calendarRepositoryProvider.future);
  return repo.load(range.groupId, range.from, range.to);
});
