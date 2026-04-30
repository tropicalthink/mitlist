import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:goflutter/models/activity_models.dart';
import 'package:goflutter/models/auth_models.dart';
import 'package:goflutter/models/chore_models.dart';
import 'package:goflutter/models/finance_models.dart';
import 'package:goflutter/models/group_models.dart';
import 'package:goflutter/models/list_models.dart';
import 'package:goflutter/models/notification_models.dart';
import 'package:goflutter/models/recipe_models.dart';
import 'package:goflutter/providers/auth_provider.dart';
import 'package:goflutter/providers/activity_provider.dart';
import 'package:goflutter/providers/chore_provider.dart';
import 'package:goflutter/providers/finance_provider.dart';
import 'package:goflutter/providers/group_provider.dart';
import 'package:goflutter/providers/list_provider.dart';
import 'package:goflutter/providers/notification_provider.dart';
import 'package:goflutter/providers/recipe_provider.dart';
import 'package:goflutter/screens/auth/login_screen.dart';
import 'package:goflutter/screens/auth/oauth_callback_screen.dart';
import 'package:goflutter/screens/auth/signup_screen.dart';
import 'package:goflutter/screens/chores/chores_screen.dart';
import 'package:goflutter/screens/home/groups_list_screen.dart';
import 'package:goflutter/screens/home/household_hub_screen.dart';
import 'package:goflutter/screens/lists/lists_screen.dart';
import 'package:goflutter/screens/money/expenses_screen.dart';
import 'package:goflutter/screens/recipes/recipes_screen.dart';
import 'package:goflutter/screens/you/account_screen.dart';
import 'package:goflutter/router.dart';
import 'package:goflutter/services/activity_service.dart';
import 'package:goflutter/services/auth_service.dart';
import 'package:goflutter/services/chore_service.dart';
import 'package:goflutter/services/finance_service.dart';
import 'package:goflutter/services/group_service.dart';
import 'package:goflutter/services/list_service.dart';
import 'package:goflutter/services/notification_service.dart';
import 'package:goflutter/services/recipe_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  const groupId = '11111111-1111-1111-1111-111111111111';
  const userId = '22222222-2222-2222-2222-222222222222';

  final group = Group(
    id: groupId,
    name: 'Test Household',
    description: 'Home base',
    memberCount: 2,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  final user = User(
    id: userId,
    email: 'user@example.com',
    firstName: 'Test',
    lastName: 'User',
    isActive: true,
    isVerified: true,
    isGuest: false,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  testWidgets('chore creation flow submits and refreshes the list',
      (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final choreService = FakeChoreService();

    await _pumpScreen(
      tester,
      child: const ChoresScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        choreServiceProviderAsync.overrideWith((ref) async => choreService),
      ],
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Vacuum living room');
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADD CHORE'));
    await tester.pumpAndSettle();

    expect(choreService.lastCreateRequest, isNotNull);
    expect(choreService.lastCreateRequest!.groupId, groupId);
    expect(choreService.lastCreateRequest!.name, 'Vacuum living room');
    expect(choreService.lastCreateRequest!.frequency, 'none');
    expect(find.text('Vacuum living room'), findsOneWidget);
  });

  testWidgets('chore detail flow opens and marks a chore done', (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final choreService = FakeChoreService(
      chores: [
        Chore(
          id: '33333333-3333-3333-3333-333333333333',
          groupId: groupId,
          name: 'Wash dishes',
          description: null,
          rotationType: 'none',
          frequency: 'daily',
          isActive: true,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    );

    await _pumpScreen(
      tester,
      child: const ChoresScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        choreServiceProviderAsync.overrideWith((ref) async => choreService),
      ],
    );

    await tester.tap(find.text('Wash dishes'));
    await tester.pumpAndSettle();

    expect(find.text('Chore Details'), findsOneWidget);
    expect(find.text('Wash dishes'), findsWidgets);

    await tester.tap(find.text('MARK DONE'));
    await tester.pumpAndSettle();

    expect(choreService.completedIds,
        contains('33333333-3333-3333-3333-333333333333'));
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
    expect(checkbox.value, isTrue);
  });

  testWidgets('expense creation flow stores cents and opens detail view',
      (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final authService = FakeAuthService(currentUser: user);
    final financeService = FakeFinanceService();

    await _pumpScreen(
      tester,
      child: const ExpensesScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        authServiceProviderAsync.overrideWith((ref) async => authService),
        financeServiceProviderAsync.overrideWith((ref) async => financeService),
      ],
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Groceries');
    await tester.enterText(find.byType(TextField).at(1), '12.34');
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADD EXPENSE'));
    await tester.pumpAndSettle();

    expect(financeService.lastCreateRequest, isNotNull);
    expect(financeService.lastCreateRequest!.payerId, userId);
    expect(financeService.lastCreateRequest!.amount, 1234);
    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.text('Groceries'));
    await tester.pumpAndSettle();

    expect(find.text('Expense Details'), findsOneWidget);
    expect(find.text('\$12.34'), findsWidgets);
  });

  testWidgets('recipe creation flow persists real recipe fields',
      (tester) async {
    await _setLargeSurface(tester);
    final recipeService = FakeRecipeService();

    await _pumpScreen(
      tester,
      child: const RecipesScreen(),
      overrides: [
        recipeServiceProviderAsync.overrideWith((ref) async => recipeService),
      ],
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Sunday Pancakes');
    await tester.enterText(find.byType(TextField).at(1), 'Mix ingredients');
    await tester.enterText(find.byType(TextField).at(2), '10');
    await tester.enterText(find.byType(TextField).at(3), '20');
    await tester.enterText(find.byType(TextField).at(4), '4');
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE RECIPE'));
    await tester.pumpAndSettle();

    expect(recipeService.lastCreateRequest, isNotNull);
    expect(recipeService.lastCreateRequest!.title, 'Sunday Pancakes');
    expect(recipeService.lastCreateRequest!.description, 'Mix ingredients');
    expect(recipeService.lastCreateRequest!.prepTime, 10);
    expect(recipeService.lastCreateRequest!.cookTime, 20);
    expect(recipeService.lastCreateRequest!.servings, 4);
    expect(find.text('Sunday Pancakes'), findsOneWidget);
  });

  testWidgets('recipe card opens a real detail sheet', (tester) async {
    await _setLargeSurface(tester);
    final recipeService = FakeRecipeService(
      recipes: [
        Recipe(
          id: '99999999-9999-9999-9999-999999999999',
          title: 'Tomato Soup',
          description: 'Blend and simmer.',
          prepTime: 10,
          cookTime: 25,
          servings: 4,
          imageUrl: null,
          isPublic: false,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
      ],
    );

    await _pumpScreen(
      tester,
      child: const RecipesScreen(),
      overrides: [
        recipeServiceProviderAsync.overrideWith((ref) async => recipeService),
      ],
    );

    await tester.tap(find.text('Tomato Soup'));
    await tester.pumpAndSettle();

    expect(find.text('Recipe Details'), findsOneWidget);
    expect(find.text('Blend and simmer.'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('list creation flow submits and refreshes the grid',
      (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final listService = FakeListService(lists: []);

    await _pumpScreen(
      tester,
      child: const ListsScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        listServiceProviderAsync.overrideWith((ref) async => listService),
      ],
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Weekend Groceries');
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE'));
    await tester.pumpAndSettle();

    expect(listService.lastCreateRequest, isNotNull);
    expect(listService.lastCreateRequest!.groupId, groupId);
    expect(listService.lastCreateRequest!.name, 'Weekend Groceries');
    expect(listService.lastCreateRequest!.type, 'shopping');
    expect(find.text('Weekend Groceries'), findsOneWidget);
  });

  testWidgets('join household flow submits invite code and refreshes',
      (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: []);

    await _pumpScreen(
      tester,
      child: const GroupsListScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
      ],
    );

    await tester.tap(find.byTooltip('Join with code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'sunny-taco-42');
    await tester.pumpAndSettle();
    await tester.tap(find.text('JOIN HOUSEHOLD'));
    await tester.pumpAndSettle();

    expect(groupService.lastJoinRequest, isNotNull);
    expect(groupService.lastJoinRequest!.code, 'SUNNY-TACO-42');
    expect(find.text('Joined Household'), findsOneWidget);
  });

  testWidgets(
      'household hub quick actions navigate to lists, chores, money, and recipes',
      (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final listService = FakeListService(
      lists: [
        ItemList(
          id: '44444444-4444-4444-4444-444444444444',
          groupId: groupId,
          name: 'Groceries',
          type: 'shopping',
          itemCount: 3,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    );

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const HouseholdHubScreen(groupId: groupId),
        ),
        GoRoute(
          path: '/recipes',
          name: 'recipes',
          builder: (context, state) =>
              const Scaffold(body: Text('Recipes route')),
        ),
        GoRoute(
          path: '/lists',
          name: 'lists',
          builder: (context, state) =>
              const Scaffold(body: Text('Lists route')),
        ),
        GoRoute(
          path: '/chores',
          name: 'chores',
          builder: (context, state) =>
              const Scaffold(body: Text('Chores route')),
        ),
        GoRoute(
          path: '/money',
          name: 'money',
          builder: (context, state) =>
              const Scaffold(body: Text('Money route')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupServiceProviderAsync.overrideWith((ref) async => groupService),
          listServiceProviderAsync.overrideWith((ref) async => listService),
          choreServiceProviderAsync
              .overrideWith((ref) async => FakeChoreService()),
          financeServiceProviderAsync
              .overrideWith((ref) async => FakeFinanceService()),
          recipeServiceProviderAsync
              .overrideWith((ref) async => FakeRecipeService()),
          activityServiceProviderAsync
              .overrideWith((ref) async => FakeActivityService()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _pumpUi(tester);

    expect(find.text('Vault'), findsNothing);
    expect(find.text('Pets & Plants'), findsNothing);

    await tester.tap(find.text('Lists'));
    await _pumpUi(tester);
    expect(find.text('Lists route'), findsOneWidget);

    router.go('/');
    await _pumpUi(tester);
    await tester.ensureVisible(find.text('Chores'));
    await tester.tap(find.text('Chores'));
    await _pumpUi(tester);
    expect(find.text('Chores route'), findsOneWidget);

    router.go('/');
    await _pumpUi(tester);
    await tester.ensureVisible(find.text('Money'));
    await tester.tap(find.text('Money'));
    await _pumpUi(tester);
    expect(find.text('Money route'), findsOneWidget);

    router.go('/');
    await _pumpUi(tester);
    await tester.ensureVisible(find.text('Kitchen'));
    await tester.tap(find.text('Kitchen'));
    await _pumpUi(tester);
    expect(find.text('Recipes route'), findsOneWidget);
  });

  testWidgets('app shell supports the surviving household journey',
      (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final listService = FakeListService(
      lists: [
        ItemList(
          id: '44444444-4444-4444-4444-444444444444',
          groupId: groupId,
          name: 'Groceries',
          type: 'shopping',
          itemCount: 3,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    );
    final choreService = FakeChoreService();
    final financeService = FakeFinanceService();
    final recipeService = FakeRecipeService();
    final activityService = FakeActivityService();
    final authService = FakeAuthService(currentUser: user);
    final notificationService = FakeNotificationService();

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => BottomNavScaffold(child: child),
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const GroupsListScreen(),
              routes: [
                GoRoute(
                  path: ':groupId/hub',
                  name: 'householdHub',
                  builder: (context, state) => HouseholdHubScreen(
                    groupId: state.pathParameters['groupId']!,
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/lists',
              name: 'lists',
              builder: (context, state) => const ListsScreen(),
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
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWith((ref) => router),
          authStateProvider.overrideWith((ref) => true),
          groupServiceProviderAsync.overrideWith((ref) async => groupService),
          listServiceProviderAsync.overrideWith((ref) async => listService),
          choreServiceProviderAsync.overrideWith((ref) async => choreService),
          financeServiceProviderAsync.overrideWith((ref) async => financeService),
          recipeServiceProviderAsync.overrideWith((ref) async => recipeService),
          activityServiceProviderAsync
              .overrideWith((ref) async => activityService),
          authServiceProviderAsync.overrideWith((ref) async => authService),
          notificationServiceProviderAsync
              .overrideWith((ref) async => notificationService),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _pumpUi(tester);

    expect(find.text('My Households'), findsOneWidget);
    expect(find.text('Test Household'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.list_alt_outlined));
    await _pumpUi(tester);
    expect(find.text('New list'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_box_outlined));
    await _pumpUi(tester);
    expect(find.text('Add chore'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await _pumpUi(tester);
    expect(find.text('Add expense'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await _pumpUi(tester);
    await tester.tap(find.text('Test Household'));
    await _pumpUi(tester);

    expect(find.text('Home base'), findsOneWidget);
    await tester.ensureVisible(find.text('Kitchen').first);
    await tester.tap(find.text('Kitchen').first);
    await _pumpUi(tester);

    expect(find.text('ADD RECIPE'), findsOneWidget);
  });

  testWidgets('account settings change password and show in-app terms',
      (tester) async {
    await _setLargeSurface(tester);
    final authService = FakeAuthService(currentUser: user);
    final notificationService = FakeNotificationService(
      preferences: const [
        NotificationPreferenceModel(
          id: 'pref-1',
          userId: userId,
          groupId: 'group-1',
          pushEnabled: true,
        ),
      ],
    );

    await _pumpScreen(
      tester,
      child: const AccountScreen(),
      overrides: [
        authServiceProviderAsync.overrideWith((ref) async => authService),
        notificationServiceProviderAsync
            .overrideWith((ref) async => notificationService),
      ],
    );

    expect(find.text('Language'), findsNothing);

    await tester.tap(find.text('Change Password'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'oldpassword');
    await tester.enterText(find.byType(TextField).at(1), 'newpassword123');
    await tester.enterText(find.byType(TextField).at(2), 'newpassword123');
    await tester.tap(find.text('CHANGE PASSWORD'));
    await tester.pumpAndSettle();

    expect(authService.lastChangePasswordRequest, isNotNull);
    expect(authService.lastChangePasswordRequest!.oldPassword, 'oldpassword');
    expect(
      authService.lastChangePasswordRequest!.newPassword,
      'newpassword123',
    );

    await tester.tap(find.text('Terms of Service'));
    await tester.pumpAndSettle();

    expect(find.text('Terms of Service'), findsWidgets);
    expect(
      find.textContaining('Shared household content is visible'),
      findsOneWidget,
    );
  });

  testWidgets('login screen completes forgot-password confirm flow',
      (tester) async {
    await _setLargeSurface(tester);
    final authService = FakeAuthService(currentUser: user);

    await _pumpScreen(
      tester,
      child: const LoginScreen(),
      overrides: [
        authServiceProviderAsync.overrideWith((ref) async => authService),
      ],
    );

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), 'reset@example.com');
    await tester.tap(find.text('SEND RESET CODE'));
    await tester.pumpAndSettle();

    expect(authService.lastPasswordResetEmail, 'reset@example.com');
    expect(
      find.text('If that email exists, a reset code has been sent.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(3), 'reset-code-123');
    await tester.enterText(find.byType(TextField).at(4), 'freshpassword');
    await tester.enterText(find.byType(TextField).at(5), 'freshpassword');
    await tester.tap(find.text('RESET PASSWORD'));
    await tester.pumpAndSettle();

    expect(authService.lastConfirmPasswordResetToken, 'reset-code-123');
    expect(authService.lastConfirmPasswordResetPassword, 'freshpassword');
    expect(
      find.text('Password reset successful. You can sign in now.'),
      findsOneWidget,
    );
  });

  testWidgets('login screen forwards remember-me choice to auth login',
      (tester) async {
    await _setLargeSurface(tester);
    final authService = FakeAuthService(currentUser: user);

    await _pumpScreen(
      tester,
      child: const LoginScreen(),
      overrides: [
        authServiceProviderAsync.overrideWith((ref) async => authService),
      ],
    );

    await tester.tap(find.text('Remember me'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.tap(find.text('SIGN IN'));
    await tester.pumpAndSettle();

    expect(authService.lastLoginRequest, isNotNull);
    expect(authService.lastLoginRequest!.email, 'user@example.com');
    expect(authService.lastLoginRequest!.password, 'secret123');
    expect(authService.lastLoginRememberMe, isFalse);
  });

  testWidgets('oauth callback screen completes session and routes home',
      (tester) async {
    await _setLargeSurface(tester);
    final authService = FakeAuthService(currentUser: user)
      ..pendingOAuthRememberMe = false;
    final router = GoRouter(
      initialLocation: '/auth/callback',
      routes: [
        GoRoute(
          path: '/auth/callback',
          builder: (context, state) => OAuthCallbackScreen(
            queryParameters: const {
              'provider': 'google',
              'code': 'oauth-code',
              'state': 'oauth-state',
            },
          ),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const Scaffold(body: Text('Home route')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWith((ref) => router),
          authServiceProviderAsync.overrideWith((ref) async => authService),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _pumpUi(tester);

    expect(authService.lastOAuthProvider, 'google');
    expect(authService.lastOAuthCode, 'oauth-code');
    expect(authService.lastOAuthState, 'oauth-state');
    expect(authService.lastOAuthRememberMe, isFalse);
    expect(find.text('Home route'), findsOneWidget);
  });

  testWidgets('signup screen exposes actionable terms and privacy',
      (tester) async {
    await _setLargeSurface(tester);

    await _pumpScreen(
      tester,
      child: const SignupScreen(),
      overrides: const [],
    );

    await tester.tap(find.text('Terms'));
    await tester.pumpAndSettle();
    expect(find.text('Terms of Service'), findsWidgets);
    expect(
      find.textContaining('Shared household content is visible'),
      findsOneWidget,
    );

    Navigator.of(tester.element(find.text('Terms of Service').first)).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy Policy'), findsWidgets);
    expect(
      find.textContaining('stores the account details'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required Widget child,
  required List<Override> overrides,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _setLargeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
}

class FakeGroupService implements GroupService {
  FakeGroupService({required this.groups, this.groupDetail});

  final List<Group> groups;
  final Group? groupDetail;
  JoinGroupRequest? lastJoinRequest;

  @override
  Future<List<Group>> listGroups({int limit = 50, int offset = 0}) async =>
      groups.take(limit).toList();

  @override
  Future<Group> getGroup(String groupId) async => groupDetail ?? groups.first;

  @override
  Future<Group> joinGroup(JoinGroupRequest request) async {
    lastJoinRequest = request;
    final group = Group(
      id: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
      name: 'Joined Household',
      description: 'Joined from invite',
      memberCount: 3,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    groups.add(group);
    return group;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeChoreService implements ChoreService {
  FakeChoreService({List<Chore>? chores}) : _chores = chores ?? [];

  final List<Chore> _chores;
  CreateChoreRequest? lastCreateRequest;
  final List<String> completedIds = [];

  @override
  Future<List<Chore>> listChores(String groupId,
          {int limit = 50, int offset = 0}) async =>
      _chores.skip(offset).take(limit).toList();

  @override
  Future<Chore> createChore(CreateChoreRequest req) async {
    lastCreateRequest = req;
    final chore = Chore(
      id: '55555555-5555-5555-5555-555555555555',
      groupId: req.groupId,
      name: req.name,
      description: req.description,
      rotationType: req.rotationType,
      frequency: req.frequency,
      isActive: req.isActive,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    _chores.add(chore);
    return chore;
  }

  @override
  Future<void> completeChore(String id, {String? notes}) async {
    completedIds.add(id);
    final index = _chores.indexWhere((chore) => chore.id == id);
    if (index >= 0) {
      final chore = _chores[index];
      _chores[index] = Chore(
        id: chore.id,
        groupId: chore.groupId,
        name: chore.name,
        description: chore.description,
        rotationType: chore.rotationType,
        frequency: chore.frequency,
        isActive: false,
        createdAt: chore.createdAt,
        updatedAt: DateTime.utc(2026, 1, 2),
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeFinanceService implements FinanceService {
  FakeFinanceService({List<Expense>? expenses}) : _expenses = expenses ?? [];

  final List<Expense> _expenses;
  CreateExpenseRequest? lastCreateRequest;

  @override
  Future<List<Expense>> listExpenses(String groupId,
          {int limit = 50, int offset = 0}) async =>
      _expenses.skip(offset).take(limit).toList();

  @override
  Future<Expense> createExpense(CreateExpenseRequest req) async {
    lastCreateRequest = req;
    final expense = Expense(
      id: '66666666-6666-6666-6666-666666666666',
      groupId: req.groupId,
      payerId: req.payerId,
      amount: req.amount,
      description: req.description,
      category: req.category,
      currency: req.currency,
      notes: req.notes,
      date: req.date,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    _expenses.add(expense);
    return expense;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeAuthService implements AuthService {
  FakeAuthService({required this.currentUser});

  final User currentUser;
  ChangePasswordRequest? lastChangePasswordRequest;
  String? lastPasswordResetEmail;
  LoginRequest? lastLoginRequest;
  bool? lastLoginRememberMe;
  String? lastConfirmPasswordResetToken;
  String? lastConfirmPasswordResetPassword;
  String? lastOAuthProvider;
  String? lastOAuthCode;
  String? lastOAuthRedirectUri;
  String? lastOAuthState;
  String? lastOAuthIdToken;
  bool? lastOAuthRememberMe;
  bool pendingOAuthRememberMe = true;

  @override
  Future<User> getMe() async => currentUser;

  @override
  Future<TokenPair> login(
    LoginRequest request, {
    bool rememberMe = true,
  }) async {
    lastLoginRequest = request;
    lastLoginRememberMe = rememberMe;
    return TokenPair(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      user: currentUser,
    );
  }

  @override
  Future<void> changePassword(ChangePasswordRequest request) async {
    lastChangePasswordRequest = request;
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    lastPasswordResetEmail = email;
  }

  @override
  Future<void> confirmPasswordReset(String token, String newPassword) async {
    lastConfirmPasswordResetToken = token;
    lastConfirmPasswordResetPassword = newPassword;
  }

  @override
  Future<void> setPendingOAuthRememberMe(bool rememberMe) async {
    pendingOAuthRememberMe = rememberMe;
  }

  @override
  Future<bool> consumePendingOAuthRememberMe() async => pendingOAuthRememberMe;

  @override
  Future<TokenPair> completeOAuthCallback({
    required String provider,
    required String code,
    required String redirectUri,
    required String state,
    String? idToken,
    bool rememberMe = true,
  }) async {
    lastOAuthProvider = provider;
    lastOAuthCode = code;
    lastOAuthRedirectUri = redirectUri;
    lastOAuthState = state;
    lastOAuthIdToken = idToken;
    lastOAuthRememberMe = rememberMe;
    return TokenPair(
      accessToken: 'oauth-access',
      refreshToken: 'oauth-refresh',
      user: currentUser,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeActivityService implements ActivityService {
  FakeActivityService({List<ActivityLogModel>? activities})
      : _activities = activities ?? <ActivityLogModel>[];

  final List<ActivityLogModel> _activities;

  @override
  Future<List<ActivityLogModel>> listActivityLogs(
    String groupId, {
    int limit = 50,
    int offset = 0,
  }) async =>
      _activities.skip(offset).take(limit).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeRecipeService implements RecipeService {
  FakeRecipeService({List<Recipe>? recipes}) : _recipes = recipes ?? [];

  final List<Recipe> _recipes;
  CreateRecipeRequest? lastCreateRequest;

  @override
  Future<List<Recipe>> listRecipes({int limit = 50, int offset = 0}) async =>
      _recipes.skip(offset).take(limit).toList();

  @override
  Future<Recipe> createRecipe(CreateRecipeRequest req) async {
    lastCreateRequest = req;
    final recipe = Recipe(
      id: '77777777-7777-7777-7777-777777777777',
      title: req.title,
      description: req.description,
      prepTime: req.prepTime,
      cookTime: req.cookTime,
      servings: req.servings,
      imageUrl: req.imageUrl,
      isPublic: req.isPublic,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    _recipes.add(recipe);
    return recipe;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeListService implements ListService {
  FakeListService({required this.lists});

  final List<ItemList> lists;
  CreateListRequest? lastCreateRequest;

  @override
  Future<List<ItemList>> listLists(String groupId,
          {int limit = 50, int offset = 0}) async =>
      lists.skip(offset).take(limit).toList();

  @override
  Future<ItemList> createList(CreateListRequest req) async {
    lastCreateRequest = req;
    final list = ItemList(
      id: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
      groupId: req.groupId,
      name: req.name,
      type: req.type,
      itemCount: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    lists.add(list);
    return list;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeNotificationService implements NotificationService {
  FakeNotificationService({List<NotificationPreferenceModel>? preferences})
      : _preferences = preferences ?? <NotificationPreferenceModel>[];

  final List<NotificationPreferenceModel> _preferences;

  @override
  Future<List<NotificationPreferenceModel>> getPreferences() async =>
      List<NotificationPreferenceModel>.from(_preferences);

  @override
  Future<void> updatePreference(NotificationPreferenceModel pref) async {
    final index = _preferences.indexWhere((item) => item.id == pref.id);
    if (index >= 0) {
      _preferences[index] = pref;
      return;
    }
    _preferences.add(pref);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
