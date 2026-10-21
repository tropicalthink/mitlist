import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:dio/dio.dart' show DioException;
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:intl/intl.dart' show DateFormat;
import 'package:uuid/uuid.dart';

import '../models/calendar_models.dart';
import '../models/list_models.dart';
import '../models/meal_plan_models.dart';
import '../models/recipe_models.dart';
import '../services/api_error_mapper.dart';
import '../services/meal_plan_service.dart';
import '../services/response_cache_interceptor.dart';
import '../storage/app_database.dart';
import 'outbox_drainer.dart';

/// A queued meal-plan change, decoded once so every overlay agrees on it.
class PendingMealPlanChange {
  final String type;
  final String planId;
  final String? groupId;

  /// The plan as it will be once this change lands; null for a delete.
  final MealPlan? plan;

  /// The planned recipe's title, for surfaces (calendar, sync sheet) that
  /// show a meal without loading its recipe.
  final String? title;

  const PendingMealPlanChange({
    required this.type,
    required this.planId,
    this.groupId,
    this.plan,
    this.title,
  });

  bool get isDelete => type == MealPlanRepository.deleteType;
}

/// Why [MealPlanRepository.generateShoppingListOfflineFirst] produced nothing.
enum MealPlanShoppingListFailure {
  /// No meals are planned in the window.
  noPlans,

  /// Meals are planned, but their recipes have no ingredients.
  noIngredients,

  /// Some recipes' ingredients were never loaded on this device and the
  /// server cannot be reached to fetch them.
  ingredientsUnavailable,
}

class MealPlanShoppingListException implements Exception {
  final MealPlanShoppingListFailure reason;
  const MealPlanShoppingListException(this.reason);

  @override
  String toString() => 'MealPlanShoppingListException($reason)';
}

/// The list [MealPlanRepository.generateShoppingListOfflineFirst] created.
class MealPlanShoppingListResult {
  final String listId;
  final int itemCount;

  /// Planned recipes whose ingredients could not be read on this device and
  /// were left out.
  final int skippedRecipes;

  const MealPlanShoppingListResult({
    required this.listId,
    required this.itemCount,
    this.skippedRecipes = 0,
  });
}

/// Meal plans over a date window: a read-through cache plus an offline
/// outbox for adding, changing and removing meals.
///
/// Reads are range-keyed so paging weeks does not evict the previous one and
/// fall back to the cache offline. Writes queue an op and show at once; the
/// cached windows are never edited for a pending change. Instead every read
/// lays the still-queued changes over what it returns ([applyPending]), so a
/// refresh landing before the drain cannot erase a meal the user just planned,
/// and a change drops out of the overlay exactly when it syncs. The calendar
/// does the same with [applyPendingToCalendar].
class MealPlanRepository {
  final AppDatabase _db;
  final MealPlanService _remote;
  final Uuid _uuid;
  final bool _autoSync;

  /// Production hook for the sync session; see [_afterLocalWrite].
  final void Function()? _onLocalWrite;

  bool _isDraining = false;

  /// Households whose notification digest should be released once their
  /// queued edits have reached the server. See [releaseNotifications].
  final Set<String> _flushAfterDrain = {};

  static const createType = 'createMealPlan';
  static const updateType = 'updateMealPlan';
  static const deleteType = 'deleteMealPlan';
  static const opTypes = [createType, updateType, deleteType];

  /// Prefix of a meal planned on this device that has not synced yet.
  static const localIdPrefix = 'local-';

  /// Local id → server id for meals whose create synced this session. The
  /// planner keeps showing a meal under its local id until it reloads; an
  /// edit or removal made in between must name the server id, which the
  /// outbox rewrite can no longer supply once the create op is gone. Static
  /// because the repository is rebuilt with its provider.
  static final Map<String, String> _syncedIds = {};

  static String resolveId(String planId) => _syncedIds[planId] ?? planId;

  MealPlanRepository({
    required AppDatabase db,
    required MealPlanService remote,
    Uuid? uuid,
    bool autoSync = true,
    void Function()? onLocalWrite,
  })  : _db = db,
        _remote = remote,
        _uuid = uuid ?? const Uuid(),
        _autoSync = autoSync,
        _onLocalWrite = onLocalWrite;

  static bool isLocalId(String id) => id.startsWith(localIdPrefix);

  /// The meal-plan API takes `from`/`to` as pre-formatted day strings, so they
  /// are already a stable key.
  static String rangeKey(String from, String to) => '${from}_$to';

  static String day(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static bool _inRange(String day, String from, String to) =>
      day.compareTo(from) >= 0 && day.compareTo(to) <= 0;

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  Future<List<MealPlan>> load(
    String groupId, {
    required String from,
    required String to,
  }) async {
    final key = rangeKey(from, to);
    try {
      // Live only: the answer is written into the range cache, and a stale
      // HTTP body served offline would overwrite a newer window.
      final raw = await ResponseCacheInterceptor.liveOnly(
          () => _remote.listMealPlansRaw(groupId, from: from, to: to));
      await _db.upsertMealPlanRange(
        groupId: groupId,
        rangeKey: key,
        plansJson: jsonEncode(raw),
      );
      return applyPending(
        MealPlanService.parseMealPlans(raw),
        await pendingChanges(_db),
        groupId: groupId,
        from: from,
        to: to,
      );
    } catch (_) {
      final cached = await getCached(groupId, from: from, to: to);
      if (cached != null) return cached;
      // A week never fetched still shows what was planned here offline.
      final local = applyPending(const [], await pendingChanges(_db),
          groupId: groupId, from: from, to: to);
      if (local.isNotEmpty) return local;
      rethrow;
    }
  }

  /// The cached window with queued changes applied, or null when it was never
  /// fetched — see `CalendarRepository.getCached` on why that differs from
  /// empty.
  Future<List<MealPlan>?> getCached(
    String groupId, {
    required String from,
    required String to,
  }) async {
    final row = await _db.getMealPlanRange(groupId, rangeKey(from, to));
    if (row == null) return null;
    final plans = _decodePlans(row.plansJson);
    if (plans == null) return null;
    return applyPending(plans, await pendingChanges(_db),
        groupId: groupId, from: from, to: to);
  }

  /// A cached range that is recent enough to reuse without another request.
  /// The Home aggregate writes this range immediately before its widgets are
  /// built, avoiding a duplicate meal-plan GET on the same screen load.
  Future<List<MealPlan>?> getFreshCached(
    String groupId, {
    required String from,
    required String to,
    Duration maxAge = const Duration(seconds: 30),
  }) async {
    final row = await _db.getMealPlanRange(groupId, rangeKey(from, to));
    if (row == null || DateTime.now().difference(row.updatedAt) > maxAge) {
      return null;
    }
    final plans = _decodePlans(row.plansJson);
    if (plans == null) return null;
    return applyPending(plans, await pendingChanges(_db),
        groupId: groupId, from: from, to: to);
  }

  static List<MealPlan>? _decodePlans(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return null;
      return MealPlanService.parseMealPlans(decoded);
    } catch (_) {
      return null;
    }
  }

  /// Whether [groupId] has meal-plan changes the server has not seen.
  Future<bool> hasPendingChanges(String groupId) async {
    final changes = await pendingChanges(_db);
    return changes.any((c) => c.groupId == null || c.groupId == groupId);
  }

  // ---------------------------------------------------------------------------
  // Overlays
  // ---------------------------------------------------------------------------

  /// Every queued meal-plan change, oldest first.
  ///
  /// Ops queued within one second share a `createdAt` (Drift stores whole
  /// seconds), so the payload's `seq` orders them.
  static Future<List<PendingMealPlanChange>> pendingChanges(
      AppDatabase db) async {
    final ops = <({OutboxOp op, Map<String, dynamic> payload})>[];
    for (final type in opTypes) {
      for (final op in await db.getOutboxOpsByType(type)) {
        try {
          final decoded = jsonDecode(op.payloadJson);
          if (decoded is Map) {
            ops.add((op: op, payload: decoded.cast<String, dynamic>()));
          }
        } catch (_) {
          // Malformed ops are the drainer's problem, not the overlay's.
        }
      }
    }
    ops.sort((a, b) {
      final byTime = a.op.createdAt.compareTo(b.op.createdAt);
      if (byTime != 0) return byTime;
      return ((a.payload['seq'] as int?) ?? 0)
          .compareTo((b.payload['seq'] as int?) ?? 0);
    });

    final changes = <PendingMealPlanChange>[];
    for (final (:op, :payload) in ops) {
      try {
        switch (op.type) {
          case createType:
            final localId = payload['localId'] as String;
            final request = (payload['request'] as Map).cast<String, dynamic>();
            final queuedAt =
                DateTime.tryParse(payload['createdAt'] as String? ?? '') ??
                    op.createdAt;
            changes.add(PendingMealPlanChange(
              type: op.type,
              planId: localId,
              groupId: request['group_id'] as String?,
              title: payload['title'] as String?,
              plan: MealPlan(
                id: localId,
                groupId: request['group_id'] as String,
                date: DateTime.parse(request['date'] as String),
                slot: request['slot'] as String? ?? 'dinner',
                recipeId: request['recipe_id'] as String,
                servings: request['servings'] as int? ?? 1,
                cookUserId: request['cook_user_id'] as String?,
                createdAt: queuedAt,
                updatedAt: queuedAt,
              ),
            ));
          case updateType:
            final plan = MealPlan.fromJson(
                (payload['plan'] as Map).cast<String, dynamic>());
            changes.add(PendingMealPlanChange(
              type: op.type,
              planId: payload['planId'] as String,
              groupId: payload['groupId'] as String? ?? plan.groupId,
              title: payload['title'] as String?,
              plan: plan,
            ));
          case deleteType:
            changes.add(PendingMealPlanChange(
              type: op.type,
              planId: payload['planId'] as String,
              groupId: payload['groupId'] as String?,
            ));
        }
      } catch (_) {
        // Same as above: skip what cannot be decoded.
      }
    }
    return changes;
  }

  /// [plans] for [groupId]'s [from]..[to] window with [changes] applied in
  /// order. A change that moves a meal to another day takes it out of (or
  /// into) the window.
  static List<MealPlan> applyPending(
    List<MealPlan> plans,
    List<PendingMealPlanChange> changes, {
    required String groupId,
    required String from,
    required String to,
  }) {
    if (changes.isEmpty) return plans;
    final out = [...plans];
    for (final change in changes) {
      if (change.groupId != null && change.groupId != groupId) continue;
      out.removeWhere((p) => p.id == change.planId);
      final plan = change.plan;
      if (change.isDelete || plan == null) continue;
      if (plan.groupId != groupId || !_inRange(day(plan.date), from, to)) {
        continue;
      }
      out.add(plan);
    }
    return out;
  }

  /// Calendar counterpart of [applyPending]: meal-plan events for changes
  /// still queued on this device.
  static List<CalendarEvent> applyPendingToCalendar(
    List<CalendarEvent> events,
    List<PendingMealPlanChange> changes, {
    required String groupId,
    required DateTime from,
    required DateTime to,
  }) {
    if (changes.isEmpty) return events;
    final fromDay = day(from);
    final toDay = day(to);
    final out = [...events];
    for (final change in changes) {
      if (change.groupId != null && change.groupId != groupId) continue;
      String? previousTitle;
      out.removeWhere((e) {
        final matches = e.type == CalendarEventType.mealPlan &&
            (e.mealPlan?.mealPlanId == change.planId || e.id == change.planId);
        if (matches) previousTitle = e.title;
        return matches;
      });
      final plan = change.plan;
      if (change.isDelete || plan == null) continue;
      if (plan.groupId != groupId ||
          !_inRange(day(plan.date), fromDay, toDay)) {
        continue;
      }
      out.add(CalendarEvent(
        id: plan.id,
        type: CalendarEventType.mealPlan,
        title: change.title ?? previousTitle ?? '',
        // Local midnight, so the calendar's toLocal() bucketing keeps the day.
        date: DateTime(plan.date.year, plan.date.month, plan.date.day),
        groupId: plan.groupId,
        mealPlan: CalendarMealPlan(
          mealPlanId: plan.id,
          slot: plan.slot,
          recipeId: plan.recipeId,
          servings: plan.servings,
          cookUserId: plan.cookUserId,
        ),
      ));
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Plans a meal. Shows at once in every read; the create replays from the
  /// outbox. [recipeTitle] labels the meal on the calendar and in the sync
  /// sheet until the server has it.
  Future<MealPlan> createOfflineFirst(
    CreateMealPlanRequest req, {
    String? recipeTitle,
  }) async {
    final localId = '$localIdPrefix${_uuid.v4()}';
    final now = DateTime.now();
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: createType,
      payload: {
        'localId': localId,
        'groupId': req.groupId,
        'request': req.toJson(),
        if (recipeTitle != null) 'title': recipeTitle,
        'createdAt': now.toIso8601String(),
        'seq': now.microsecondsSinceEpoch,
      },
      idempotencyKey: '$createType:$localId',
      entityType: 'mealPlan',
      entityId: localId,
    );
    _afterLocalWrite();
    return MealPlan(
      id: localId,
      groupId: req.groupId,
      date: DateTime.parse(req.date),
      slot: req.slot,
      recipeId: req.recipeId,
      servings: req.servings,
      cookUserId: req.cookUserId,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Changes a planned meal. [current] is the plan as the user sees it; the op
  /// carries the patched result so the overlay can show it on any day (a date
  /// change moves it between weeks).
  ///
  /// Works on a meal that has not synced yet too: the op names the local id,
  /// which the create's sync rewrites to the server id before this replays.
  Future<MealPlan> updateOfflineFirst(
    MealPlan current,
    UpdateMealPlanRequest patch, {
    String? recipeTitle,
  }) async {
    final now = DateTime.now();
    final planId = resolveId(current.id);
    final updated = MealPlan(
      id: planId,
      groupId: current.groupId,
      date: patch.date != null ? DateTime.parse(patch.date!) : current.date,
      slot: patch.slot ?? current.slot,
      recipeId: patch.recipeId ?? current.recipeId,
      servings: patch.servings ?? current.servings,
      cookUserId: patch.cookUserId ?? current.cookUserId,
      createdAt: current.createdAt,
      updatedAt: now,
    );
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: updateType,
      payload: {
        'planId': planId,
        'groupId': current.groupId,
        'patch': patch.toJson(),
        'plan': updated.toJson(),
        if (recipeTitle != null) 'title': recipeTitle,
        'seq': now.microsecondsSinceEpoch,
      },
      idempotencyKey: '$updateType:$planId:${now.microsecondsSinceEpoch}',
      entityType: 'mealPlan',
      entityId: planId,
    );
    _afterLocalWrite();
    return updated;
  }

  /// Removes a planned meal.
  Future<void> deleteOfflineFirst(MealPlan plan) async {
    final now = DateTime.now();
    final planId = resolveId(plan.id);
    await _db.enqueueOutbox(
      id: _uuid.v4(),
      type: deleteType,
      payload: {
        'planId': planId,
        'groupId': plan.groupId,
        'seq': now.microsecondsSinceEpoch,
      },
      idempotencyKey: '$deleteType:$planId',
      entityType: 'mealPlan',
      entityId: planId,
    );
    _afterLocalWrite();
  }

  /// Releases the household's batched "meal plan changed" notification once
  /// the planner closes. With edits still queued, releasing now would send the
  /// digest before the edits it summarises, so it waits for the drain instead.
  Future<void> releaseNotifications(String groupId) async {
    if (await hasPendingChanges(groupId)) {
      _flushAfterDrain.add(groupId);
      return;
    }
    await _remote.flushMealPlanNotifications(groupId);
  }

  // ---------------------------------------------------------------------------
  // Shopping list from the plan
  // ---------------------------------------------------------------------------

  /// Builds a shopping list for [groupId]'s [from]..[to] plans on this device,
  /// for when the server's generator cannot be used (offline, or meals still
  /// queued that it would not see).
  ///
  /// Mirrors the server: ingredients are scaled by planned / recipe servings,
  /// summed per (name, unit), and a missing amount counts as one portion. The
  /// list and its items go through the list outbox, so the result is usable
  /// at once and syncs later. Dependencies are passed in so this does not
  /// reach into the list or recipe repositories' construction.
  Future<MealPlanShoppingListResult> generateShoppingListOfflineFirst({
    required String groupId,
    required String from,
    required String to,
    required Future<Recipe?> Function(String recipeId) recipeOf,
    required Future<List<RecipeIngredient>?> Function(String recipeId)
        ingredientsOf,
    required Future<ItemList> Function(CreateListRequest req) createList,
    required Future<void> Function(String listId, CreateListItemRequest req)
        createItem,
  }) async {
    final plans = await load(groupId, from: from, to: to);
    if (plans.isEmpty) {
      throw const MealPlanShoppingListException(
          MealPlanShoppingListFailure.noPlans);
    }

    final recipes = <String, Recipe?>{};
    final ingredients = <String, List<RecipeIngredient>?>{};
    for (final id in plans.map((p) => p.recipeId).toSet()) {
      recipes[id] = await _orNull(() => recipeOf(id));
      ingredients[id] = await _orNull(() => ingredientsOf(id));
    }

    final totals = <(String, String), double>{};
    final names = <(String, String), String>{};
    var skipped = 0;
    for (final plan in plans) {
      final recipe = recipes[plan.recipeId];
      final lines = ingredients[plan.recipeId];
      if (lines == null) {
        skipped++;
        continue;
      }
      final recipeServings = recipe?.servings ?? 0;
      final scale = recipeServings > 0 && plan.servings > 0
          ? plan.servings / recipeServings
          : 1.0;
      for (final ing in lines) {
        final name = ing.name.trim().isNotEmpty ? ing.name.trim() : ing.rawText;
        if (name.trim().isEmpty) continue;
        final key = (name, ing.unit);
        var qty = ing.quantity * scale;
        if (qty <= 0) qty = scale;
        totals[key] = (totals[key] ?? 0) + qty;
        names[key] = name;
      }
    }

    if (totals.isEmpty) {
      throw MealPlanShoppingListException(skipped > 0
          ? MealPlanShoppingListFailure.ingredientsUnavailable
          : MealPlanShoppingListFailure.noIngredients);
    }

    // Same name the server gives a generated list.
    final list = await createList(CreateListRequest(
      groupId: groupId,
      name: 'Shopping $from',
      type: 'shopping',
    ));
    for (final entry in totals.entries) {
      await createItem(
        list.id,
        CreateListItemRequest(
          name: names[entry.key]!,
          quantity: _round(entry.value),
          unit: entry.key.$2,
        ),
      );
    }
    return MealPlanShoppingListResult(
      listId: list.id,
      itemCount: totals.length,
      skippedRecipes: skipped,
    );
  }

  static Future<T?> _orNull<T>(Future<T?> Function() call) async {
    try {
      return await call();
    } catch (_) {
      return null;
    }
  }

  /// Scaled amounts like 0.6666… read badly on a list; two decimals is what
  /// the list editor itself offers.
  static double _round(double v) => (v * 100).roundToDouble() / 100;

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  /// Called after a write has queued an op. Production passes
  /// [_onLocalWrite], which only opens the sync session; without it (tests,
  /// direct constructions) the op drains right away.
  void _afterLocalWrite() {
    if (!_autoSync) return;
    final onLocalWrite = _onLocalWrite;
    if (onLocalWrite != null) {
      onLocalWrite();
    } else {
      unawaited(drainOutboxOnce());
    }
  }

  Future<void> drainOutboxOnce() async {
    if (_isDraining) return;
    _isDraining = true;
    try {
      // One pass for all three types, in queue order: the drainer re-reads
      // each op before sending it, so an edit or removal queued against a
      // meal's local id sees the server id its create's sync rewrote in.
      await OutboxDrainer(_db).drain(
        types: opTypes,
        handlers: {
          createType: (op, payload) async {
            final localId = payload['localId'] as String?;
            final request = payload['request'];
            if (localId == null || request is! Map) {
              await _db.deleteOutboxOp(op.id);
              return;
            }
            final created = await _remote.createMealPlanRaw(
              request.cast<String, dynamic>(),
              idempotencyKey: op.idempotencyKey,
            );
            _syncedIds[localId] = created.id;
            await _db.rewriteOutboxPayloadIds(
                oldId: localId, newId: created.id);
            await _db.deleteOutboxOp(op.id);
            await _patchCaches(created.groupId,
                put: created, title: payload['title'] as String?);
          },
          updateType: (op, payload) async {
            final planId = payload['planId'] as String?;
            final patch = payload['patch'];
            if (planId == null || patch is! Map) {
              await _db.deleteOutboxOp(op.id);
              return;
            }
            final updated = await _remote.updateMealPlanRaw(
              planId,
              patch.cast<String, dynamic>(),
              idempotencyKey: op.idempotencyKey,
            );
            await _db.deleteOutboxOp(op.id);
            await _patchCaches(updated.groupId,
                put: updated, title: payload['title'] as String?);
          },
          deleteType: (op, payload) async {
            final planId = payload['planId'] as String?;
            if (planId != null) {
              try {
                await _remote.deleteMealPlanRaw(planId,
                    idempotencyKey: op.idempotencyKey);
              } catch (e) {
                // Already gone is the outcome we wanted.
                if (!_isNotFound(e)) rethrow;
              }
            }
            await _db.deleteOutboxOp(op.id);
            final groupId = payload['groupId'] as String?;
            if (planId != null && groupId != null) {
              await _patchCaches(groupId, removeId: planId);
            }
          },
        },
      );
    } finally {
      _isDraining = false;
    }
    await _releaseDeferredNotifications();
  }

  Future<void> _releaseDeferredNotifications() async {
    if (_flushAfterDrain.isEmpty) return;
    for (final groupId in _flushAfterDrain.toList()) {
      if (await hasPendingChanges(groupId)) continue;
      _flushAfterDrain.remove(groupId);
      await _remote.flushMealPlanNotifications(groupId);
    }
  }

  static bool _isNotFound(Object e) {
    final cause = e is ApiException ? e.cause : (e is DioException ? e : null);
    return cause?.response?.statusCode == 404;
  }

  /// Applies a synced change to the cached meal-plan and calendar windows.
  ///
  /// The overlay stops covering a change the moment its op is deleted, and
  /// the windows were written before it existed; without this, a meal synced
  /// just before the connection dropped again would vanish from the offline
  /// view until the next successful fetch.
  Future<void> _patchCaches(
    String groupId, {
    MealPlan? put,
    String? removeId,
    String? title,
  }) async {
    final drop = put?.id ?? removeId;
    try {
      final rows = await (_db.select(_db.mealPlanCaches)
            ..where((t) => t.groupId.equals(groupId)))
          .get();
      for (final row in rows) {
        final decoded = jsonDecode(row.plansJson);
        if (decoded is! List) continue;
        final kept = decoded
            .where(
                (e) => !(e is Map && (e['id'] == drop || e['id'] == removeId)))
            .toList();
        final bounds = row.rangeKey.split('_');
        if (put != null &&
            bounds.length == 2 &&
            _inRange(day(put.date), bounds[0], bounds[1])) {
          kept.add(put.toJson());
        }
        if (kept.length == decoded.length && put == null) continue;
        await (_db.update(_db.mealPlanCaches)
              ..where((t) =>
                  t.groupId.equals(groupId) & t.rangeKey.equals(row.rangeKey)))
            .write(MealPlanCachesCompanion(plansJson: Value(jsonEncode(kept))));
      }

      final calendarRows = await (_db.select(_db.calendarCaches)
            ..where((t) => t.groupId.equals(groupId)))
          .get();
      for (final row in calendarRows) {
        final decoded = jsonDecode(row.eventsJson);
        if (decoded is! List) continue;
        String? previousTitle;
        final kept = decoded.where((e) {
          if (e is! Map || e['type'] != 'meal_plan') return true;
          final id = (e['meal_plan'] is Map)
              ? e['meal_plan']['meal_plan_id']
              : e['id'];
          final matches = id == drop || id == removeId;
          if (matches) previousTitle = e['title'] as String?;
          return !matches;
        }).toList();
        final bounds = row.rangeKey.split('_');
        if (put != null &&
            bounds.length == 2 &&
            _inRange(day(put.date), bounds[0], bounds[1])) {
          kept.add({
            'id': put.id,
            'type': 'meal_plan',
            'title': title ?? previousTitle ?? '',
            'date': day(put.date),
            'group_id': put.groupId,
            'meal_plan': {
              'meal_plan_id': put.id,
              'slot': put.slot,
              'recipe_id': put.recipeId,
              'servings': put.servings,
              if (put.cookUserId != null) 'cook_user_id': put.cookUserId,
            },
          });
        }
        if (kept.length == decoded.length && put == null) continue;
        await (_db.update(_db.calendarCaches)
              ..where((t) =>
                  t.groupId.equals(groupId) & t.rangeKey.equals(row.rangeKey)))
            .write(
                CalendarCachesCompanion(eventsJson: Value(jsonEncode(kept))));
      }
    } catch (_) {
      // Best effort: the next successful fetch rewrites these windows anyway.
    }
  }
}
