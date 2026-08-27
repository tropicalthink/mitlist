import 'package:go_router/go_router.dart';

typedef NotificationGroupSwitcher = Future<void> Function(String groupId);

/// Route names that live inside the app's `StatefulShellRoute`.
///
/// These can only be reached with `go`, never `push`. The notification inbox is
/// a root-level route (`/you/notifications`) sitting *above* the shell, so
/// pushing a branch route from there builds a second `StatefulShellRoute` while
/// the first is still mounted. Both claim the same branch `navigatorKey`
/// GlobalKeys and the framework throws:
///
///   'package:flutter/src/widgets/navigator.dart': Failed assertion:
///   '!keyReservation.contains(key)': is not true.
///   A GlobalKey was used multiple times inside one widget's child list.
///
/// Keep this in sync with the branches in `router.dart`.
const _shellRouteNames = {
  'home',
  'chores',
  'recipes',
  'recipeDetail',
  'mealPlan',
  'money',
  'recurringExpenses',
  'lists',
  'listDetail',
};

/// Resolves the shared notification payload contract for inbox, FCM, and other
/// Flutter entry points. Returns false when the payload has no safe target.
Future<bool> navigateNotificationPayload(
  GoRouter router,
  Map<String, dynamic> payload, {
  required bool preserveInbox,
  NotificationGroupSwitcher? switchGroup,
}) async {
  final screen = payload['screen'] as String?;
  final id = payload['id'] as String?;
  final groupId = payload['group_id'] as String?;

  if (groupId != null && groupId.isNotEmpty && switchGroup != null) {
    await switchGroup(groupId);
  }

  void open(String name, {Map<String, String> pathParameters = const {}}) {
    // preserveInbox asks for a push so back returns to the notification list,
    // but a shell-branch destination cannot be pushed at all — see
    // [_shellRouteNames]. Those always go.
    if (preserveInbox && !_shellRouteNames.contains(name)) {
      router.pushNamed(name, pathParameters: pathParameters);
    } else {
      router.goNamed(name, pathParameters: pathParameters);
    }
  }

  switch (screen) {
    case 'choreDetail':
      open('chores');
    case 'expenseDetail':
    case 'settlements':
      open('money');
    case 'listDetail':
      if (id == null || id.isEmpty) return false;
      open('listDetail', pathParameters: {'listId': id});
    case 'recipeDetail':
      if (id == null || id.isEmpty) return false;
      open('recipeDetail', pathParameters: {'recipeId': id});
    case 'mealPlan':
      open('mealPlan');
    case 'householdHub':
      open('home');
    case 'recurringExpenses':
      open('recurringExpenses');
    case 'weeklySummary':
      // The summary is per-household, so a payload without a group has nothing
      // to show. Fall back to the hub rather than opening an empty screen.
      if (groupId == null || groupId.isEmpty) {
        open('home');
        return true;
      }
      open('weeklySummary', pathParameters: {'groupId': groupId});
    default:
      return false;
  }
  return true;
}
