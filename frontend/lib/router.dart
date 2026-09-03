import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'providers/group_provider.dart' show cachedGroupsProvider;
import 'widgets/mitlist_bottom_nav.dart';
import 'widgets/shell_branch_switcher.dart';
import 'providers/nav_badge_provider.dart';
import 'providers/grocery_provider.dart' show groceryGraphSyncProvider;
import 'theme/animations.dart';
import 'utils/active_group_context.dart';
import 'utils/route_history.dart';
import 'utils/shell_tab_load.dart';

import 'screens/home/groups_list_screen.dart';
import 'screens/lists/lists_screen.dart';
import 'screens/chores/chores_screen.dart';
import 'screens/money/expenses_screen.dart';
import 'screens/money/recurring_expenses_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/you/account_screen.dart';
import 'screens/you/feature_board_screen.dart';
import 'screens/you/weekly_summary_screen.dart';
import 'screens/you/home_assistant_connections_screen.dart';
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
import 'screens/recipes/shared_recipe_screen.dart';
import 'screens/recipes/cook_mode_screen.dart';
import 'screens/recipes/cookbooks_screen.dart';
import 'screens/recipes/cookbook_detail_screen.dart';
import 'screens/recipes/cookbook_add_recipes_screen.dart';
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

/// Root navigator key for UI that lives above the Navigator (the offline
/// banner in MaterialApp.builder) and needs a context *inside* it to be able
/// to open sheets and dialogs.
GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;

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

/// Auth flow pages crossfade instead of sliding: every one of them paints the
/// same deterministic cork board, so a fade reads as papers changing on a wall
/// that never moves — the whole first run happens on one continuous surface.
CustomTransitionPage<void> _boardPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: MitlistAnimations.page,
    reverseTransitionDuration: MitlistAnimations.page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.of(context).disableAnimations) return child;
      return FadeTransition(
        opacity:
            CurveTween(curve: MitlistAnimations.easeEnter).animate(animation),
        child: child,
      );
    },
  );
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

  final router = GoRouter(
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
          // The backend puts the upgrade marker next to the handoff: in the
          // query for deep links, in the fragment for web.
          isOAuthLinkCallback: state.uri.queryParameters['link'] == '1' ||
              Uri.splitQueryString(state.uri.fragment)['link'] == '1',
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
        pageBuilder: (context, state) =>
            _boardPage(state, const WelcomeScreen()),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => _boardPage(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        pageBuilder: (context, state) =>
            _boardPage(state, const SignupScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) =>
            _boardPage(state, const OnboardingScreen()),
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
        // Public: a shared recipe renders for signed-out visitors too, so
        // router_redirect exempts this prefix from the /welcome bounce.
        path: '/r/:token',
        name: 'sharedRecipe',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => SharedRecipeScreen(
          token: state.pathParameters['token']!,
        ),
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
                          initial: state.extra as RecipeCollection?,
                        ),
                        routes: [
                          GoRoute(
                            path: 'add',
                            name: 'cookbookAddRecipes',
                            parentNavigatorKey: _rootNavigatorKey,
                            builder: (context, state) =>
                                CookbookAddRecipesScreen(
                              collectionId:
                                  state.pathParameters['collectionId']!,
                              excludedRecipeIds:
                                  state.extra as Set<String>? ?? const {},
                            ),
                          ),
                        ],
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
      // Root-level on purpose. The weekly digest notification opens this from
      // the inbox, which also lives outside the stateful shell; a shell-branch
      // route pushed from there duplicates the branch navigator GlobalKeys.
      GoRoute(
        path: '/weekly-summary/:groupId',
        name: 'weeklySummary',
        builder: (context, state) => WeeklySummaryScreen(
          groupId: state.pathParameters['groupId']!,
        ),
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
            path: 'feature-board',
            name: 'featureBoard',
            builder: (context, state) => const FeatureBoardScreen(),
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
          GoRoute(
            path: 'integrations/home-assistant',
            name: 'homeAssistantConnections',
            builder: (context, state) => const HomeAssistantConnectionsScreen(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'homeAssistantConnectionNew',
                builder: (context, state) =>
                    const HomeAssistantConnectionCreateScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/scanner',
        name: 'scanner',
        builder: (context, state) => Consumer(
          builder: (context, routeRef, _) {
            final preferred = routeRef.watch(currentGroupIdProvider);
            final groups = routeRef.watch(cachedGroupsProvider).asData?.value;
            return ScannerScreen(
              groupId: groups == null
                  ? preferred
                  : resolveActiveGroupId(groups, preferred),
            );
          },
        ),
      ),
    ],
  );

  // Feed the feedback sheet's page attribution: record every location change
  // so submissions can report the screen the user was on (and came from).
  router.routerDelegate.addListener(() {
    RouteHistory.record(
        router.routerDelegate.currentConfiguration.uri.toString());
  });

  return router;
});

const _lastShellTabKey = 'nav_last_tab_index';

/// Forgets the remembered bottom-nav tab so the next entry into the shell
/// lands on the hub.
///
/// Onboarding calls this before handing over: the shell restores the tab the
/// last session ended on, which silently overrode the explicit "go to the
/// board" navigation and dropped a freshly created household into whatever
/// tab happened to be last.
Future<void> resetLastShellTab() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_lastShellTabKey, 0);
}

class BottomNavScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const BottomNavScaffold({super.key, required this.navigationShell});

  @override
  ConsumerState<BottomNavScaffold> createState() => _BottomNavScaffoldState();
}

class _BottomNavScaffoldState extends ConsumerState<BottomNavScaffold> {
  bool _restored = false;

  /// Nav motion stays off until the tab the user left on has been restored and
  /// painted. Otherwise every cold start opens on Home and then slides across
  /// to wherever they actually were, which is choreography nobody asked for.
  bool _navMotionArmed = false;

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
    final saved = prefs.getInt(_lastShellTabKey) ?? 0;
    if (!mounted || _restored) return;
    _restored = true;
    if (saved != 0 && saved < 5) {
      widget.navigationShell.goBranch(saved);
      markShellTabVisited(ref, saved);
    }
    _armNavMotion();
  }

  /// Arms nav motion one frame after the restore, so the restored tab paints
  /// in place first and only genuine navigation animates.
  void _armNavMotion() {
    if (_navMotionArmed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _navMotionArmed) return;
      setState(() => _navMotionArmed = true);
    });
  }

  void _onTap(int index) {
    // Tapping the tab you're already on pops that branch back to its root —
    // the standard escape hatch out of a detail page, and the only thing that
    // makes the press feedback on an active tab mean something.
    if (index == widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(index, initialLocation: true);
      return;
    }
    markShellTabVisited(ref, index);
    widget.navigationShell.goBranch(index);
    SharedPreferences.getInstance()
        .then((p) => p.setInt(_lastShellTabKey, index));
  }

  @override
  Widget build(BuildContext context) {
    final groupId = ref.watch(currentGroupIdProvider);
    if (groupId != null && groupId.isNotEmpty) {
      ref.watch(groceryGraphSyncProvider(groupId));
    }
    final badgeData = ref.watch(navBadgeCountsProvider);

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
        body: ShellBranchSwitcher(
          index: widget.navigationShell.currentIndex,
          animate: _navMotionArmed,
          child: widget.navigationShell,
        ),
        bottomNavigationBar: MitlistBottomNav(
          currentIndex: widget.navigationShell.currentIndex,
          animate: _navMotionArmed,
          onTap: _onTap,
          items: [
            MitlistNavItem(iconName: 'home', label: l10n.navHome),
            MitlistNavItem(
              iconName: 'clipboardDocumentList',
              label: l10n.navChores,
              badgeCount: badgeData.choreCount,
            ),
            MitlistNavItem(iconName: 'queueList', label: l10n.navKitchen),
            MitlistNavItem(
              iconName: 'banknotes',
              label: l10n.navMoney,
              badgeCount: badgeData.settlementCount,
            ),
            MitlistNavItem(iconName: 'listBullet', label: l10n.navLists),
          ],
        ),
      ),
    );
  }
}
