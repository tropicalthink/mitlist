import 'package:go_router/go_router.dart';

typedef NotificationGroupSwitcher = Future<void> Function(String groupId);

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
    if (preserveInbox) {
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
    default:
      return false;
  }
  return true;
}
