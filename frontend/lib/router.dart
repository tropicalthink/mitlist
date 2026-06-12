import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'widgets/app_icon.dart';
import 'providers/nav_badge_provider.dart';

import 'screens/home/groups_list_screen.dart';
import 'screens/lists/lists_screen.dart';
import 'screens/chores/chores_screen.dart';
import 'screens/money/expenses_screen.dart';
import 'screens/money/recurring_expenses_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/you/account_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/oauth_callback_screen.dart';
import 'screens/auth/session_bootstrap_screen.dart';
import 'screens/home/household_hub_screen.dart';
import 'screens/lists/list_detail_screen.dart';
import 'screens/share_target_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/notifications/notification_preferences_screen.dart';
import 'screens/recipes/recipes_screen.dart';
import 'screens/recipes/recipe_creation_screen.dart';
import 'screens/recipes/recipe_detail_screen.dart';
import 'screens/recipes/cook_mode_screen.dart';
import 'models/recipe_models.dart';
import 'screens/meal_plans/meal_plan_screen.dart';
import 'screens/shopping/shopping_trip_screen.dart';
import 'screens/scanner/scanner_screen.dart';

final currentGroupIdProvider =
    StateNotifierProvider<CurrentGroupIdNotifier, String?>(
  (ref) => CurrentGroupIdNotifier(),
);

class CurrentGroupIdNotifier extends StateNotifier<String?> {
  CurrentGroupIdNotifier() : super(null) {
    _load();
  }

  static const _key = 'current_group_id';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key);
  }

  Future<void> set(String? groupId) async {
    final prefs = await SharedPreferences.getInstance();
    if (groupId != null) {
      await prefs.setString(_key, groupId);
    } else {
      await prefs.remove(_key);
    }
    state = groupId;
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _homeNavKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _listsNavKey = GlobalKey<NavigatorState>(debugLabel: 'lists');
final _choresNavKey = GlobalKey<NavigatorState>(debugLabel: 'chores');
final _moneyNavKey = GlobalKey<NavigatorState>(debugLabel: 'money');
final _recipesNavKey = GlobalKey<NavigatorState>(debugLabel: 'recipes');

final _authRoutePrefixes = [
  '/welcome',
  '/login',
  '/signup',
  '/auth/callback',
];

const _sessionBootstrapPath = '/_session';

bool _isSessionBootstrapPath(String location) =>
    location.startsWith(_sessionBootstrapPath);

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final authBootstrap = ref.watch(authBootstrapProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/welcome',
    redirect: (context, state) {
      final location = state.uri.path;
      final isAuthRoute = _authRoutePrefixes.any((p) => location.startsWith(p));

      if (authBootstrap.isLoading) {
        if (location.startsWith('/auth/callback')) {
          return null;
        }
        if (_isSessionBootstrapPath(location)) {
          return null;
        }
        // Marketing / sign-in routes: stay put so first visits and /login
        // reloads do not bounce through a loading URL.
        if (isAuthRoute) {
          return null;
        }
        final target =
            '${state.uri.path}${state.uri.hasQuery ? '?${state.uri.query}' : ''}';
        return '$_sessionBootstrapPath?continue=${Uri.encodeComponent(target)}';
      }

      if (_isSessionBootstrapPath(location)) {
        if (authState) {
          final cont = state.uri.queryParameters['continue'];
          if (cont != null && cont.isNotEmpty) {
            final decoded = Uri.decodeComponent(cont);
            if (decoded.startsWith('/') && !decoded.startsWith('//')) {
              return decoded;
            }
          }
          return '/home';
        }
        return '/welcome';
      }

      if (!authState && !isAuthRoute) {
        return '/welcome';
      }

      if (authState && isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: _sessionBootstrapPath,
        name: 'sessionBootstrap',
        builder: (context, state) => const SessionBootstrapScreen(),
      ),
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth/callback',
        name: 'oauthCallback',
        builder: (context, state) => OAuthCallbackScreen(
          queryParameters: state.uri.queryParameters,
        ),
      ),
      GoRoute(
        path: '/share-target',
        name: 'shareTarget',
        builder: (context, state) => const ShareTargetScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            BottomNavScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavKey,
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (context, state) => const HouseholdHubScreen(),
                routes: [
                  GoRoute(
                    path: 'groups',
                    name: 'groupsList',
                    builder: (context, state) => const GroupsListScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _choresNavKey,
            routes: [
              GoRoute(
                path: '/chores',
                name: 'chores',
                builder: (context, state) => const ChoresScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _recipesNavKey,
            routes: [
              GoRoute(
                path: '/recipes',
                name: 'recipes',
                builder: (context, state) => const RecipesScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    name: 'recipeCreate',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final extra = state.extra as Map<String, String?>?;
                      return RecipeCreationScreen(
                        initialTitle: extra?['initialTitle'],
                        initialIngredients: extra?['initialIngredients'],
                        initialSteps: extra?['initialSteps'],
                      );
                    },
                  ),
                  GoRoute(
                    path: 'meal-plan',
                    name: 'mealPlan',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const MealPlanScreen(),
                  ),
                  GoRoute(
                    path: ':recipeId',
                    name: 'recipeDetail',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => RecipeDetailScreen(
                      recipeId: state.pathParameters['recipeId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'cook',
                        name: 'recipeCook',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final extra =
                              state.extra as Map<String, Object?>?;
                          return CookModeScreen(
                            recipeId: state.pathParameters['recipeId']!,
                            recipe: extra?['recipe'] as Recipe?,
                            ingredients: extra?['ingredients']
                                as List<RecipeIngredient>?,
                            steps:
                                extra?['steps'] as List<RecipeStep>?,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _moneyNavKey,
            routes: [
              GoRoute(
                path: '/money',
                name: 'money',
                builder: (context, state) => const ExpensesScreen(),
                routes: [
                  GoRoute(
                    path: 'recurring',
                    name: 'recurringExpenses',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) =>
                        const RecurringExpensesScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _listsNavKey,
            routes: [
              GoRoute(
                path: '/lists',
                name: 'lists',
                builder: (context, state) => const ListsScreen(),
                routes: [
                  GoRoute(
                    path: 'shopping-trip',
                    name: 'shoppingTrip',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ShoppingTripScreen(),
                  ),
                  GoRoute(
                    path: ':listId',
                    name: 'listDetail',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final listId = state.pathParameters['listId']!;
                      final extra = state.extra;
                      final initialName =
                          extra is ListDetailRouteArgs ? extra.listName : null;
                      return ListDetailScreen(
                        listId: listId,
                        initialListName: initialName,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/calendar',
        name: 'calendar',
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/you',
        name: 'you',
        builder: (context, state) => const AccountScreen(),
        routes: [
          GoRoute(
            path: 'notifications',
            name: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: 'notification-preferences',
            name: 'notificationPreferences',
            builder: (context, state) =>
                const NotificationPreferencesScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/scanner',
        name: 'scanner',
        builder: (context, state) => const ScannerScreen(),
      ),
    ],
  );
});

class BottomNavScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const BottomNavScaffold({super.key, required this.navigationShell});

  @override
  ConsumerState<BottomNavScaffold> createState() => _BottomNavScaffoldState();
}

class _BottomNavScaffoldState extends ConsumerState<BottomNavScaffold> {
  static const _lastTabKey = 'nav_last_tab_index';
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _restoreLastTab();
  }

  Future<void> _restoreLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_lastTabKey) ?? 0;
    if (!mounted || _restored) return;
    _restored = true;
    if (saved != 0 && saved < 5) {
      widget.navigationShell.goBranch(saved);
    }
  }

  void _onTap(int index) {
    if (index == widget.navigationShell.currentIndex) return;
    widget.navigationShell.goBranch(index);
    SharedPreferences.getInstance().then((p) => p.setInt(_lastTabKey, index));
  }

  @override
  Widget build(BuildContext context) {
    final badgeCounts = ref.watch(navBadgeCountsProvider);
    final badgeData = badgeCounts.valueOrNull ?? const NavBadgeCounts();

    Widget makeBadgeIcon(Widget icon, {int count = 0}) {
      if (count <= 0) return icon;
      return Badge(
        isLabelVisible: count > 0,
        label: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(fontSize: 10),
        ),
        child: icon,
      );
    }

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outline,
              width: 2,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: widget.navigationShell.currentIndex,
          onTap: _onTap,
          items: [
            const BottomNavigationBarItem(
                icon: AppIcon(name: 'home'), label: 'Home'),
            BottomNavigationBarItem(
                icon: makeBadgeIcon(
                  const AppIcon(name: 'clipboardDocumentList'),
                  count: badgeData.choreCount,
                ),
                label: 'Chores'),
            const BottomNavigationBarItem(
                icon: AppIcon(name: 'queueList'), label: 'Kitchen'),
            BottomNavigationBarItem(
                icon: makeBadgeIcon(
                  const AppIcon(name: 'banknotes'),
                  count: badgeData.settlementCount,
                ),
                label: 'Money'),
            const BottomNavigationBarItem(
                icon: AppIcon(name: 'listBullet'), label: 'Lists'),
          ],
        ),
      ),
    );
  }
}
