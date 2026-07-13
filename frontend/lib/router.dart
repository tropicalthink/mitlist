import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'providers/group_provider.dart' show cachedGroupsProvider;
import 'widgets/app_icon.dart';
import 'providers/nav_badge_provider.dart';
import 'providers/grocery_provider.dart' show groceryGraphSyncProvider;
import 'utils/active_group_context.dart';
import 'utils/shell_tab_load.dart';

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
import 'screens/auth/join_landing_screen.dart';
import 'screens/home/household_hub_screen.dart';
import 'screens/lists/list_detail_screen.dart';
import 'screens/share_target_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/notifications/notification_preferences_screen.dart';
import 'screens/recipes/recipes_screen.dart';
import 'screens/recipes/recipe_creation_screen.dart';
import 'screens/recipes/recipe_detail_screen.dart';
import 'screens/recipes/cook_mode_screen.dart';
import 'screens/recipes/cookbooks_screen.dart';
import 'screens/recipes/cookbook_detail_screen.dart';
import 'screens/lists/products_screen.dart';
import 'screens/lists/shopping_locations_screen.dart';
import 'models/recipe_models.dart';
import 'screens/meal_plans/meal_plan_screen.dart';
import 'screens/shopping/shopping_trip_screen.dart';
import 'screens/scanner/scanner_screen.dart';
import 'l10n/app_localizations.dart';
import 'router_redirect.dart';

final currentGroupIdProvider =
    StateNotifierProvider<CurrentGroupIdNotifier, String?>(
  (ref) => CurrentGroupIdNotifier(),
);

class CurrentGroupIdNotifier extends StateNotifier<String?> {
  CurrentGroupIdNotifier() : super(null) {
    _loadFuture = _load();
  }

  static const _key = 'current_group_id';

  late final Future<void> _loadFuture;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// Awaits hydration from SharedPreferences before resolving group context.
  Future<void> ensureLoaded() => _loadFuture;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key);
    _isLoaded = true;
  }

  Future<void> set(String? groupId) async {
    await ensureLoaded();
    final prefs = await SharedPreferences.getInstance();
    if (groupId != null) {
      await prefs.setString(_key, groupId);
    } else {
      await prefs.remove(_key);
    }
    state = groupId;
  }
}

/// Triggers [GoRouter] redirect re-evaluation without recreating the router.
class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(authBootstrapProvider, (_, __) => notifyListeners());
    ref.listen(pendingAuthNavigationProvider, (_, __) => notifyListeners());
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _homeNavKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _listsNavKey = GlobalKey<NavigatorState>(debugLabel: 'lists');
final _choresNavKey = GlobalKey<NavigatorState>(debugLabel: 'chores');
final _moneyNavKey = GlobalKey<NavigatorState>(debugLabel: 'money');
final _recipesNavKey = GlobalKey<NavigatorState>(debugLabel: 'recipes');

const _sessionBootstrapPath = sessionBootstrapPath;

Future<void> _reconcileActiveGroupAfterAuth(Ref ref) async {
  await ref.read(currentGroupIdProvider.notifier).ensureLoaded();
  try {
    final groups = await ref.read(cachedGroupsProvider.future);
    final resolved = resolveActiveGroupId(
      groups,
      ref.read(currentGroupIdProvider),
    );
    if (resolved != ref.read(currentGroupIdProvider)) {
      await ref.read(currentGroupIdProvider.notifier).set(resolved);
    }
  } catch (_) {}
}

final routerProvider = Provider<GoRouter>((ref) {
  ref.watch(authBootstrapListenerProvider);
  ref.listen<bool>(authStateProvider, (previous, next) {
    if (!next && previous == true) {
      unawaited(ref.read(currentGroupIdProvider.notifier).set(null));
    } else if (next && previous != true) {
      unawaited(_reconcileActiveGroupAfterAuth(ref));
    }
  });
  final refreshListenable = _RouterRefreshListenable(ref);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: _sessionBootstrapPath,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final authBootstrap = ref.read(authBootstrapProvider);
      final result = resolveAppRedirect(
        AppRedirectInput(
          location: state.uri.path,
          queryParameters: state.uri.queryParameters,
          authBootstrapLoading: authBootstrap.isLoading,
          authState: authState,
          pendingAuthNavigation: ref.read(pendingAuthNavigationProvider),
          requestedPathWithQuery:
              '${state.uri.path}${state.uri.hasQuery ? '?${state.uri.query}' : ''}',
        ),
      );
      if (result.clearPendingAuth) {
        ref.read(pendingAuthNavigationProvider.notifier).state = null;
      }
      return result.redirect;
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
          uri: state.uri,
        ),
      ),
      GoRoute(
        path: '/share-target',
        name: 'shareTarget',
        builder: (context, state) => const ShareTargetScreen(),
      ),
      GoRoute(
        path: '/join/:code',
        name: 'joinLanding',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => JoinLandingScreen(
          code: state.pathParameters['code']!,
        ),
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
                    path: 'cookbooks',
                    name: 'cookbooks',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const CookbooksScreen(),
                    routes: [
                      GoRoute(
                        path: ':collectionId',
                        name: 'cookbookDetail',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => CookbookDetailScreen(
                          collectionId: state.pathParameters['collectionId']!,
                          initialName: state.extra as String?,
                        ),
                      ),
                    ],
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
                          final extra = state.extra as Map<String, Object?>?;
                          return CookModeScreen(
                            recipeId: state.pathParameters['recipeId']!,
                            recipe: extra?['recipe'] as Recipe?,
                            ingredients: extra?['ingredients']
                                as List<RecipeIngredient>?,
                            steps: extra?['steps'] as List<RecipeStep>?,
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
                      final args = extra is ListDetailRouteArgs ? extra : null;
                      return ListDetailScreen(
                        listId: listId,
                        initialListName: args?.listName,
                        autoFocusTitle: args?.autoFocusTitle ?? false,
                        autoFocusComposer: args?.autoFocusComposer ?? false,
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
            builder: (context, state) => const NotificationPreferencesScreen(),
          ),
          GoRoute(
            path: 'products',
            name: 'products',
            builder: (context, state) => const ProductsScreen(),
          ),
          GoRoute(
            path: 'shopping-locations',
            name: 'shoppingLocations',
            builder: (context, state) => const ShoppingLocationsScreen(),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      markShellTabVisited(ref, widget.navigationShell.currentIndex);
    });
    _restoreLastTab();
  }

  Future<void> _restoreLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_lastTabKey) ?? 0;
    if (!mounted || _restored) return;
    _restored = true;
    if (saved != 0 && saved < 5) {
      widget.navigationShell.goBranch(saved);
      markShellTabVisited(ref, saved);
    }
  }

  void _onTap(int index) {
    if (index == widget.navigationShell.currentIndex) return;
    markShellTabVisited(ref, index);
    widget.navigationShell.goBranch(index);
    SharedPreferences.getInstance().then((p) => p.setInt(_lastTabKey, index));
  }

  @override
  Widget build(BuildContext context) {
    final groupId = ref.watch(currentGroupIdProvider);
    if (groupId != null && groupId.isNotEmpty) {
      ref.watch(groceryGraphSyncProvider(groupId));
    }
    final badgeData = ref.watch(navBadgeCountsProvider);

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

    final l10n = AppLocalizations.of(context)!;

    // Android back handling for the bottom-nav shell. Without this, pressing
    // system-back at the root of a tab falls through to the root navigator and
    // exits the app — on *any* tab, which reads as "back randomly quits the
    // app." Routes pushed inside a branch (e.g. list detail) are popped by
    // their own navigator first, so this only runs once a tab is at its root:
    // from a non-Home tab it returns to Home; from Home it lets the app exit.
    return PopScope(
      canPop: widget.navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onTap(0);
      },
      child: Scaffold(
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
              BottomNavigationBarItem(
                  icon: const AppIcon(name: 'home'), label: l10n.navHome),
              BottomNavigationBarItem(
                  icon: makeBadgeIcon(
                    const AppIcon(name: 'clipboardDocumentList'),
                    count: badgeData.choreCount,
                  ),
                  label: l10n.navChores),
              BottomNavigationBarItem(
                  icon: const AppIcon(name: 'queueList'),
                  label: l10n.navKitchen),
              BottomNavigationBarItem(
                  icon: makeBadgeIcon(
                    const AppIcon(name: 'banknotes'),
                    count: badgeData.settlementCount,
                  ),
                  label: l10n.navMoney),
              BottomNavigationBarItem(
                  icon: const AppIcon(name: 'listBullet'),
                  label: l10n.navLists),
            ],
          ),
        ),
      ),
    );
  }
}
