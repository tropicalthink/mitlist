import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'providers/group_provider.dart';
import 'services/group_id_validator.dart';

import 'screens/home/groups_list_screen.dart';
import 'screens/lists/lists_screen.dart';
import 'screens/chores/chores_screen.dart';
import 'screens/money/expenses_screen.dart';
import 'screens/you/account_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/home/household_hub_screen.dart';
import 'screens/lists/list_detail_screen.dart';
import 'screens/share_target_screen.dart';
import 'screens/integration_test_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/recipes/recipes_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final _authRoutePrefixes = ['/welcome', '/login', '/signup', '/onboarding'];

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/welcome',
    redirect: (context, state) {
      final location = state.uri.path;
      final isAuthRoute = _authRoutePrefixes.any((p) => location.startsWith(p));

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
        path: '/share-target',
        name: 'shareTarget',
        builder: (context, state) => const ShareTargetScreen(),
      ),
      if (!kReleaseMode)
        GoRoute(
          path: '/integration-test',
          name: 'integrationTest',
          builder: (context, state) => const IntegrationTestScreen(),
        ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => BottomNavScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const _HomeEntryScreen(),
            routes: [
              GoRoute(
                path: ':groupId/hub',
                name: 'householdHub',
                builder: (context, state) {
                  final groupId = state.pathParameters['groupId']!;
                  return HouseholdHubScreen(groupId: groupId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/lists',
            name: 'lists',
            builder: (context, state) => const ListsScreen(),
            routes: [
              GoRoute(
                path: ':listId',
                name: 'listDetail',
                builder: (context, state) {
                  final listId = state.pathParameters['listId']!;
                  return ListDetailScreen(listId: listId);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/chores',
            name: 'chores',
            builder: (context, state) => const ChoresScreen(),
          ),
          GoRoute(
            path: '/money',
            name: 'money',
            builder: (context, state) => const ExpensesScreen(),
          ),
          GoRoute(
            path: '/recipes',
            name: 'recipes',
            builder: (context, state) => const RecipesScreen(),
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
            ],
          ),
        ],
      ),
    ],
  );
});

class BottomNavScaffold extends StatelessWidget {
  final Widget child;
  const BottomNavScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _calculateIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => _onTap(i, context),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), label: 'Lists'),
          BottomNavigationBarItem(icon: Icon(Icons.check_box_outlined), label: 'Chores'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Money'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_outlined), label: 'Kitchen'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'You'),
        ],
      ),
    );
  }

  int _calculateIndex(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/lists')) return 1;
    if (location.startsWith('/chores')) return 2;
    if (location.startsWith('/money')) return 3;
    if (location.startsWith('/recipes')) return 4;
    if (location.startsWith('/you')) return 5;
    return 0;
  }

  void _onTap(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.goNamed('home');
        return;
      case 1:
        context.goNamed('lists');
        return;
      case 2:
        context.goNamed('chores');
        return;
      case 3:
        context.goNamed('money');
        return;
      case 4:
        context.goNamed('recipes');
        return;
      case 5:
        context.goNamed('you');
        return;
    }
  }
}

class _HomeEntryScreen extends ConsumerStatefulWidget {
  const _HomeEntryScreen();

  @override
  ConsumerState<_HomeEntryScreen> createState() => _HomeEntryScreenState();
}

class _HomeEntryScreenState extends ConsumerState<_HomeEntryScreen> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ref.read(groupServiceProviderAsync.future),
      builder: (context, serviceSnap) {
        if (serviceSnap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (serviceSnap.hasError || serviceSnap.data == null) {
          return const GroupsListScreen();
        }

        return FutureBuilder(
          future: serviceSnap.data!.listGroups(limit: 1),
          builder: (context, groupsSnap) {
            if (groupsSnap.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final groups = groupsSnap.data ?? const [];
            final groupId = groups.isEmpty ? null : groups.first.id;
            if (!isValidGroupId(groupId)) {
              return const GroupsListScreen();
            }

            return HouseholdHubScreen(groupId: groupId!);
          },
        );
      },
    );
  }
}
