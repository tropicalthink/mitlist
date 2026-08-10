import 'dart:convert';

import '../models/meal_plan_models.dart';
import '../services/meal_plan_service.dart';
import '../storage/app_database.dart';

/// Read-through cache for meal plans over a date window.
///
/// Same shape and reasoning as [CalendarRepository]: range-keyed so paging
/// weeks does not evict the previous one, cache-fallback so the screen renders
/// offline, and read-only — meal-plan writes still take the online path.
class MealPlanRepository {
  final AppDatabase _db;
  final MealPlanService _remote;

  MealPlanRepository({
    required AppDatabase db,
    required MealPlanService remote,
  })  : _db = db,
        _remote = remote;

  /// The meal-plan API takes `from`/`to` as pre-formatted day strings, so they
  /// are already a stable key.
  static String rangeKey(String from, String to) => '${from}_$to';

  Future<List<MealPlan>> load(
    String groupId, {
    required String from,
    required String to,
  }) async {
    final key = rangeKey(from, to);
    try {
      final raw = await _remote.listMealPlansRaw(groupId, from: from, to: to);
      await _db.upsertMealPlanRange(
        groupId: groupId,
        rangeKey: key,
        plansJson: jsonEncode(raw),
      );
      return MealPlanService.parseMealPlans(raw);
    } catch (_) {
      final cached = await getCached(groupId, from: from, to: to);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// The cached window, or null when it was never fetched — see
  /// `CalendarRepository.getCached` on why that differs from empty.
  Future<List<MealPlan>?> getCached(
    String groupId, {
    required String from,
    required String to,
  }) async {
    final row = await _db.getMealPlanRange(groupId, rangeKey(from, to));
    if (row == null) return null;
    try {
      final decoded = jsonDecode(row.plansJson);
      if (decoded is! List) return null;
      return MealPlanService.parseMealPlans(decoded);
    } catch (_) {
      return null;
    }
  }
}
