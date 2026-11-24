import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/chore_models.dart';
import '../router.dart' show currentGroupIdProvider;
import '../services/group_id_validator.dart';
import '../utils/active_group_context.dart';
import '../utils/home_summary.dart';
import 'auth_provider.dart';
import 'chore_provider.dart';
import 'finance_provider.dart';
import 'group_provider.dart';

/// The parts of mitlist a person can choose to use. Home is not one of them:
/// it is always there. Declared in bottom-nav order.
enum AppArea { chores, kitchen, money, lists }

/// What one person said they use, asked once in the first run and changed
/// under You. A choice belongs to the person, not the household or the
/// device: it is stored under their user id, so it survives signing out and
/// back in, and someone else signing in on the same phone gets their own.
///
/// [chosen] is null when the person never chose (everyone who signed up
/// before this existed, and anyone who answered "show me everything"): every
/// area is shown.
class AppAreasState {
  const AppAreasState({this.userId, this.chosen});

  final String? userId;
  final Set<AppArea>? chosen;

  bool get hasChoice => chosen != null;
}

String _key(String userId) => 'app_areas:$userId';

/// The person's chosen areas. Reloads when the signed-in state changes, so a
/// second account on the device reads its own choice.
final appAreasProvider =
    StateNotifierProvider<AppAreasNotifier, AppAreasState>((ref) {
  ref.watch(authStateProvider);
  return AppAreasNotifier();
});

class AppAreasNotifier extends StateNotifier<AppAreasState> {
  AppAreasNotifier() : super(const AppAreasState()) {
    _load();
  }

  static String? _userIdFrom(SharedPreferences prefs) {
    final raw = prefs.getString(ApiConfig.userDataKey);
    if (raw == null) return null;
    try {
      final id = (jsonDecode(raw) as Map<String, dynamic>)['id'];
      return id is String && id.isNotEmpty ? id : null;
    } catch (_) {
      return null;
    }
  }

  static Set<AppArea>? _decode(List<String>? names) {
    if (names == null) return null;
    return {
      for (final area in AppArea.values)
        if (names.contains(area.name)) area,
    };
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _userIdFrom(prefs);
      final chosen =
          userId == null ? null : _decode(prefs.getStringList(_key(userId)));
      if (mounted) state = AppAreasState(userId: userId, chosen: chosen);
    } catch (_) {}
  }

  /// Re-reads the signed-in user and their choice; for flows that save the
  /// user's profile after this provider was first read.
  Future<void> reload() => _load();

  /// Records [areas] as the person's choice. Null clears it: everything
  /// shows again.
  Future<void> choose(Set<AppArea>? areas) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = state.userId ?? _userIdFrom(prefs);
      if (mounted) state = AppAreasState(userId: userId, chosen: areas);
      if (userId == null) return;
      if (areas == null) {
        await prefs.remove(_key(userId));
      } else {
        await prefs.setStringList(
          _key(userId),
          [
            for (final a in AppArea.values)
              if (areas.contains(a)) a.name
          ],
        );
      }
    } catch (_) {}
  }

  /// Turns one area on or off, starting from "everything" when the person
  /// never chose.
  Future<void> setShown(AppArea area, bool shown) {
    final current = {...(state.chosen ?? AppArea.values.toSet())};
    shown ? current.add(area) : current.remove(area);
    return choose(current);
  }
}

/// The areas this person sees right now: what they chose, plus any area
/// where the household has put something on them. A housemate who logs an
/// expense you are in, or a chore whose turn is yours, has to reach you even
/// if you never picked Money or Chores.
final visibleAreasProvider = Provider<Set<AppArea>>((ref) {
  final areas = ref.watch(appAreasProvider);
  final chosen = areas.chosen;
  if (chosen == null) return AppArea.values.toSet();
  final visible = {...chosen};
  if (visible.length == AppArea.values.length) return visible;

  ref.watch(currentGroupIdProvider);
  final groups = ref.watch(cachedGroupsProvider).valueOrNull;
  if (groups == null) return visible;
  final groupId =
      resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
  if (!isValidGroupId(groupId)) return visible;
  final gid = groupId!;

  if (!visible.contains(AppArea.chores)) {
    final chores =
        ref.watch(cachedCurrentChoresByGroupProvider(gid)).valueOrNull ??
            const <CurrentChore>[];
    if (chores.any(choreIsOnMe)) visible.add(AppArea.chores);
  }
  if (!visible.contains(AppArea.money)) {
    final summary =
        ref.watch(cachedFinanceSummaryByGroupProvider(gid)).valueOrNull;
    if (myBalance(summary, areas.userId).cents != 0) {
      visible.add(AppArea.money);
    }
  }
  return visible;
});

/// A chore whose current turn is the caller's and is still open.
bool choreIsOnMe(CurrentChore c) {
  final status = c.pendingAssignment?.status;
  return c.assignedToMe &&
      c.pendingAssignment != null &&
      status != 'completed' &&
      status != 'skipped';
}
