import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every quick-start preference key starts with this; sign-out clears them
/// all (see `AuthService`).
const String kHubQuickStartPrefsPrefix = 'hub_quick_start_';

/// What the person answered to "What do you want to sort out first?" in the
/// first run (plans/048 stage 6). The matching checklist step moves to the
/// first open position.
enum HubQuickStartIntent { lists, money, chores }

/// What a member who joined an established household does first (plans/048
/// stage 7). Each is recorded where it happens, per household.
enum HubQuickStartStep { tick, chore, balance }

/// The quick-start checklist's state for one household, kept per household
/// and not per device: a second household starts with its own checklist.
class HubQuickStartPrefs {
  const HubQuickStartPrefs({
    this.collapsed = false,
    this.invited = false,
    this.intent,
    this.joined = false,
    this.done = const {},
  });

  /// Folded into its one-line bar. There is no permanent dismiss; the card
  /// retires on its own once every step is done.
  final bool collapsed;

  /// The person opened the invite flow from the checklist. Joining is out of
  /// their hands, so asking is what ticks "Invite someone"; the solo invite
  /// card stays until somebody actually joins.
  final bool invited;

  final HubQuickStartIntent? intent;

  /// This person joined the household (by link or code) rather than
  /// creating it; with a household already in use they get the joiner
  /// checklist.
  final bool joined;

  /// The joiner steps already done.
  final Set<HubQuickStartStep> done;
}

String _key(String name, String groupId) =>
    '$kHubQuickStartPrefsPrefix$name:$groupId';

final hubQuickStartPrefsProvider =
    FutureProvider.family<HubQuickStartPrefs, String>((ref, groupId) async {
  final prefs = await SharedPreferences.getInstance();
  final intent = prefs.getString(_key('intent', groupId));
  return HubQuickStartPrefs(
    collapsed: prefs.getBool(_key('collapsed', groupId)) ?? false,
    invited: prefs.getBool(_key('invited', groupId)) ?? false,
    intent:
        HubQuickStartIntent.values.where((i) => i.name == intent).firstOrNull,
    joined: prefs.getBool(_key('joined', groupId)) ?? false,
    done: {
      for (final step in HubQuickStartStep.values)
        if (prefs.getBool(_key('did_${step.name}', groupId)) ?? false) step,
    },
  );
});

Future<void> setHubQuickStartCollapsed(String groupId, bool collapsed) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_key('collapsed', groupId), collapsed);
}

Future<void> markHubQuickStartInvited(String groupId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_key('invited', groupId), true);
}

/// Stores the first-run intent answer for [groupId]; "Just looking" stores
/// nothing.
Future<void> setHubQuickStartIntent(
  String groupId,
  HubQuickStartIntent intent,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_key('intent', groupId), intent.name);
}

/// Records that this person joined [groupId] rather than creating it.
Future<void> markHubQuickStartJoined(String groupId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_key('joined', groupId), true);
}

/// Records a joiner step as done. Cheap and harmless for creators, whose
/// checklist does not show these steps.
Future<void> markHubQuickStartStep(
  String groupId,
  HubQuickStartStep step,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_key('did_${step.name}', groupId), true);
}
