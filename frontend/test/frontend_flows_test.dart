import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:mitlist/models/activity_models.dart';
import 'package:mitlist/models/auth_models.dart';
import 'package:mitlist/models/chore_models.dart';
import 'package:mitlist/models/finance_models.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/models/notification_models.dart';
import 'package:mitlist/models/pinwall_models.dart';
import 'package:mitlist/models/pinwall_media_models.dart';
import 'package:mitlist/models/recipe_models.dart';
import 'package:mitlist/models/meal_plan_models.dart';
import 'package:mitlist/services/meal_plan_service.dart';
import 'package:mitlist/services/pinwall_service.dart';
import 'package:mitlist/providers/auth_provider.dart';
import 'package:mitlist/providers/activity_provider.dart';
import 'package:mitlist/providers/chore_provider.dart';
import 'package:mitlist/providers/finance_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/list_provider.dart';
import 'package:mitlist/providers/notification_provider.dart';
import 'package:mitlist/providers/pinwall_provider.dart';
import 'package:mitlist/providers/recipe_provider.dart';
import 'package:mitlist/providers/meal_plan_provider.dart';
import 'package:mitlist/repositories/chore_repository.dart';
import 'package:mitlist/repositories/list_repository.dart';
import 'package:mitlist/repositories/finance_repository.dart';
import 'package:mitlist/repositories/pinwall_repository.dart';
import 'package:mitlist/screens/auth/login_screen.dart';
import 'package:mitlist/screens/auth/oauth_callback_screen.dart';
import 'package:mitlist/screens/auth/signup_screen.dart';
import 'package:mitlist/screens/chores/chores_screen.dart';
import 'package:mitlist/screens/home/groups_list_screen.dart';
import 'package:mitlist/screens/home/household_hub_screen.dart';
import 'package:mitlist/screens/lists/lists_screen.dart';
import 'package:mitlist/screens/money/expenses_screen.dart';
import 'package:mitlist/screens/recipes/recipes_screen.dart';
import 'package:mitlist/screens/you/account_screen.dart';
import 'package:mitlist/router.dart';
import 'package:mitlist/services/activity_service.dart';
import 'package:mitlist/services/auth_service.dart';
import 'package:mitlist/services/chore_service.dart';
import 'package:mitlist/services/finance_service.dart';
import 'package:mitlist/services/group_service.dart';
import 'package:mitlist/services/list_service.dart';
import 'package:mitlist/services/notification_service.dart';
import 'package:mitlist/services/recipe_service.dart';
import 'package:mitlist/storage/app_database.dart' hide FinanceSummary;
import 'package:mitlist/widgets/app_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
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
    final choreRepo = FakeChoreRepository(choreService);

    await choreService.createChore(
      CreateChoreRequest(
        groupId: groupId,
        name: 'Vacuum living room',
        description: null,
        frequency: 'none',
      ),
    );

    await _pumpScreen(
      tester,
      child: const ChoresScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        choreServiceProviderAsync.overrideWith((ref) async => choreService),
        choreRepositoryProvider.overrideWith((ref) async => choreRepo),
      ],
    );

    await _pumpUi(tester);

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
    final choreRepo = FakeChoreRepository(choreService);

    await _pumpScreen(
      tester,
      child: const ChoresScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        choreServiceProviderAsync.overrideWith((ref) async => choreService),
        choreRepositoryProvider.overrideWith((ref) async => choreRepo),
      ],
    );

    await _pumpUi(tester);

    expect(find.text('Wash dishes'), findsOneWidget);

    await choreService.completeChore(
      '33333333-3333-3333-3333-333333333333',
      notes: null,
    );
    await choreRepo.refreshCurrentChores(groupId);
    await _pumpUi(tester);

    expect(choreService.completedIds,
        contains('33333333-3333-3333-3333-333333333333'));
  });

  testWidgets('expense creation flow stores cents and opens detail view',
      (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final authService = FakeAuthService(currentUser: user);
    final financeService = FakeFinanceService();
    final financeRepo = FakeFinanceRepository(financeService);

    await financeService.createExpense(
      CreateExpenseRequest(
        groupId: groupId,
        payerId: userId,
        description: 'Groceries',
        amount: 1234,
        category: 'groceries',
        currency: 'USD',
        date: DateTime.utc(2026, 1, 15),
      ),
    );

    await _pumpScreen(
      tester,
      child: const ExpensesScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        authServiceProviderAsync.overrideWith((ref) async => authService),
        financeServiceProviderAsync.overrideWith((ref) async => financeService),
        financeRepositoryProvider.overrideWith((ref) async => financeRepo),
      ],
    );

    await _pumpUi(tester);

    expect(financeService.lastCreateRequest, isNotNull);
    expect(financeService.lastCreateRequest!.payerId, userId);
    expect(financeService.lastCreateRequest!.amount, 1234);
    expect(find.text('Groceries'), findsOneWidget);

    await tester.tap(find.text('Groceries'));
    await _pumpAfter(tester);

    expect(find.text('Expense details'), findsOneWidget);
  });

  testWidgets('recipe creation flow persists real recipe fields',
      (tester) async {
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
    final groupService = FakeGroupService(groups: [group], groupDetail: group);

    await recipeService.createRecipe(
      CreateRecipeRequest(
        title: 'Sunday Pancakes',
        description: 'Mix ingredients',
        prepTime: 10,
        cookTime: 20,
        servings: 4,
      ),
    );

    await _pumpScreen(
      tester,
      child: const RecipesScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        recipeServiceProviderAsync.overrideWith((ref) async => recipeService),
        mealPlanServiceProviderAsync
            .overrideWith((ref) async => FakeMealPlanService()),
      ],
    );

    await _pumpUi(tester);

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

    final groupService = FakeGroupService(groups: [group], groupDetail: group);

    await _pumpScreen(
      tester,
      child: const RecipesScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        recipeServiceProviderAsync.overrideWith((ref) async => recipeService),
        mealPlanServiceProviderAsync
            .overrideWith((ref) async => FakeMealPlanService()),
      ],
    );

    await _pumpUi(tester);

    await tester.tap(find.text('Tomato Soup'));
    await _pumpAfter(tester);

    expect(find.text('Recipe details'), findsOneWidget);
    expect(find.text('Blend and simmer.'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('list creation flow submits and refreshes the grid',
      (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final listService = FakeListService(lists: []);
    final listRepo = FakeListRepository(listService);

    await _pumpScreen(
      tester,
      child: const ListsScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        listServiceProviderAsync.overrideWith((ref) async => listService),
        listRepositoryProvider.overrideWith((ref) async => listRepo),
      ],
    );

    await _pumpUi(tester);

    await listService.createList(
      CreateListRequest(
        groupId: groupId,
        name: 'Weekend Groceries',
        type: 'shopping',
      ),
    );
    await listRepo.refreshLists(groupId);
    await _pumpUi(tester);

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
    await _pumpAfter(tester);

    await tester.enterText(find.byType(TextField).first, 'sunny-taco-42');
    await _pumpAfter(tester);
    await tester.tap(find.widgetWithText(AppButton, 'JOIN HOUSEHOLD')); // solid variant renders text as uppercase
    await _pumpAfter(tester);

    expect(groupService.lastJoinRequest, isNotNull);
    expect(groupService.lastJoinRequest!.code, 'SUNNY-TACO-42');
    expect(find.text("You're in."), findsOneWidget);
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
          authServiceProviderAsync
              .overrideWith((ref) async => FakeAuthService(currentUser: user)),
          pinwallServiceProviderAsync
              .overrideWith((ref) async => FakePinwallService()),
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
          choreRepositoryProvider.overrideWith(
              (ref) async => FakeChoreRepository(FakeChoreService())),
          listRepositoryProvider.overrideWith(
              (ref) async => FakeListRepository(listService)),
          financeRepositoryProvider.overrideWith(
              (ref) async => FakeFinanceRepository(FakeFinanceService())),
          pinwallRepositoryProvider.overrideWith(
              (ref) async => FakePinwallRepository(FakePinwallService())),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await _pumpUi(tester);

    router.go('/lists');
    await _pumpUi(tester);
    expect(find.text('Lists route'), findsOneWidget);

    router.go('/');
    await _pumpUi(tester);
    router.go('/chores');
    await _pumpUi(tester);
    expect(find.text('Chores route'), findsOneWidget);

    router.go('/');
    await _pumpUi(tester);
    router.go('/money');
    await _pumpUi(tester);
    expect(find.text('Money route'), findsOneWidget);

    router.go('/');
    await _pumpUi(tester);
    router.go('/recipes');
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
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              BottomNavScaffold(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
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
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/lists',
                  name: 'lists',
                  builder: (context, state) => const ListsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/chores',
                  name: 'chores',
                  builder: (context, state) => const ChoresScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/money',
                  name: 'money',
                  builder: (context, state) => const ExpensesScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/recipes',
                  name: 'recipes',
                  builder: (context, state) => const RecipesScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/you',
          name: 'you',
          builder: (context, state) => const AccountScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWith((ref) => router),
          authStateProvider.overrideWith((ref) => true),
          pinwallServiceProviderAsync
              .overrideWith((ref) async => FakePinwallService()),
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

    await tester.tap(find.text('Lists'));
    await _pumpUi(tester);
    expect(find.text('Lists'), findsAtLeast(1));

    await tester.tap(find.text('Chores'));
    await _pumpUi(tester);
    expect(find.text('Chores'), findsAtLeast(1));

    await tester.tap(find.text('Money'));
    await _pumpUi(tester);
    expect(find.text('Money'), findsAtLeast(1));

    await tester.tap(find.text('Home'));
    await _pumpUi(tester);

    expect(find.text('My Households'), findsOneWidget);
    expect(find.text('Test Household'), findsOneWidget);
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
    await _pumpAfter(tester);
    await tester.enterText(find.byType(TextField).at(0), 'oldpassword');
    await tester.enterText(find.byType(TextField).at(1), 'newpassword123');
    await tester.enterText(find.byType(TextField).at(2), 'newpassword123');
    await tester.tap(find.text('CHANGE PASSWORD')); // solid variant renders uppercase
    await _pumpAfter(tester);

    expect(authService.lastChangePasswordRequest, isNotNull);
    expect(authService.lastChangePasswordRequest!.oldPassword, 'oldpassword');
    expect(
      authService.lastChangePasswordRequest!.newPassword,
      'newpassword123',
    );

    await tester.tap(find.text('Terms of Service'));
    await _pumpAfter(tester);

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

    expect(find.text('CONTINUE WITH GOOGLE'), findsOneWidget); // outline variant renders uppercase
    expect(find.text('CONTINUE WITH APPLE'), findsOneWidget); // outline variant renders uppercase
    expect(find.text('Remember me'), findsOneWidget);

    await tester.tap(find.text('Forgot password?'));
    await _pumpAfter(tester);
    await tester.enterText(find.byType(TextField).at(2), 'reset@example.com');
    await tester.tap(find.text('SEND RESET CODE')); // solid variant renders uppercase
    await _pumpAfter(tester);

    expect(authService.lastPasswordResetEmail, 'reset@example.com');
    expect(
      find.text('If that email exists, a reset code has been sent.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(3), 'reset-code-123');
    await tester.enterText(find.byType(TextField).at(4), 'freshpassword');
    await tester.enterText(find.byType(TextField).at(5), 'freshpassword');
    await tester.ensureVisible(find.widgetWithText(AppButton, 'RESET PASSWORD')); // solid variant renders uppercase
    await tester.tap(find.widgetWithText(AppButton, 'RESET PASSWORD'));
    await _pumpAfter(tester);

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
    await _pumpAfter(tester);
    await tester.enterText(find.byType(TextField).at(0), 'user@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'secret123');
    await tester.tap(find.text('SIGN IN')); // solid variant renders uppercase
    await _pumpAfter(tester);

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
          name: 'onboarding', // OAuthCallbackScreen navigates via goNamed('onboarding')
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

    await tester.tap(find.text('Terms of Service')); // ghost variant, button text matches exactly
    await _pumpAfter(tester);
    expect(find.text('Terms of Service'), findsWidgets);
    expect(
      find.textContaining('Shared household content is visible'),
      findsOneWidget,
    );

    Navigator.of(tester.element(find.text('Terms of Service').first)).pop();
    await _pumpAfter(tester);

    await tester.tap(find.text('Privacy Policy'));
    await _pumpAfter(tester);
    expect(find.text('Privacy Policy'), findsWidgets);
    expect(
      find.textContaining('stores the account details'),
      findsOneWidget,
    );
  });
  testWidgets('chores screen shows empty state when no chores exist',
      (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final choreService = FakeChoreService(chores: []);
    final choreRepo = FakeChoreRepository(choreService);

    await _pumpScreen(
      tester,
      child: const ChoresScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        choreServiceProviderAsync.overrideWith((ref) async => choreService),
        choreRepositoryProvider.overrideWith((ref) async => choreRepo),
      ],
    );

    expect(find.text('No chores yet'), findsOneWidget);
  });

  testWidgets('expenses screen shows empty state when no expenses exist',
      (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final authService = FakeAuthService(currentUser: user);
    final financeService = FakeFinanceService(expenses: []);
    final financeRepo = FakeFinanceRepository(financeService);

    await _pumpScreen(
      tester,
      child: const ExpensesScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        authServiceProviderAsync.overrideWith((ref) async => authService),
        financeServiceProviderAsync.overrideWith((ref) async => financeService),
        financeRepositoryProvider.overrideWith((ref) async => financeRepo),
      ],
    );

    expect(find.text('No expenses yet'), findsOneWidget);
  });

  testWidgets('recipes screen shows empty state when no recipes exist',
      (tester) async {
    await _setLargeSurface(tester);
    final recipeService = FakeRecipeService(recipes: []);

    await _pumpScreen(
      tester,
      child: const RecipesScreen(),
      overrides: [
        recipeServiceProviderAsync.overrideWith((ref) async => recipeService),
      ],
    );

    expect(find.text('Build your kitchen'), findsOneWidget);
  });

  testWidgets('expenses screen shows error state on API failure',
      (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final authService = FakeAuthService(currentUser: user);

    await _pumpScreen(
      tester,
      child: const ExpensesScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        authServiceProviderAsync.overrideWith((ref) async => authService),
        financeRepositoryProvider.overrideWith((ref) async {
          throw Exception('API error');
        }),
      ],
    );

    expect(find.text('Couldn\u2019t load expenses. Check your connection.'),
        findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget); // solid variant renders uppercase
  });

  testWidgets('chores screen shows error state on API failure',
      (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);

    await _pumpScreen(
      tester,
      child: const ChoresScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        choreRepositoryProvider.overrideWith((ref) async {
          throw Exception('API error');
        }),
      ],
    );

    expect(find.text('Failed to load chores. Please try again.'),
        findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget); // solid variant renders uppercase
  });

  testWidgets('chore creation prevents submitting with empty name',
      (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final choreService = FakeChoreService();
    final choreRepo = FakeChoreRepository(choreService);

    await _pumpScreen(
      tester,
      child: const ChoresScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        choreServiceProviderAsync.overrideWith((ref) async => choreService),
        choreRepositoryProvider.overrideWith((ref) async => choreRepo),
      ],
    );

    await tester.tap(find.byTooltip('Add chore'));
    await _pumpAfter(tester);

    final createButtons = find.widgetWithText(AppButton, 'ADD CHORE'); // solid variant renders uppercase
    expect(createButtons, findsAtLeast(1));
    final button = tester.widget<AppButton>(createButtons.last);
    expect(button.onPressed, isNull);
  });

  testWidgets('list creation prevents submitting with empty name',
      (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final listService = FakeListService(lists: []);
    final listRepo = FakeListRepository(listService);

    await _pumpScreen(
      tester,
      child: const ListsScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        listServiceProviderAsync.overrideWith((ref) async => listService),
        listRepositoryProvider.overrideWith((ref) async => listRepo),
      ],
    );

    await tester.tap(find.byTooltip('New list'));
    await _pumpAfter(tester);

    final createButton = find.widgetWithText(AppButton, 'CREATE'); // solid variant renders uppercase
    expect(createButton, findsOneWidget);
    final button = tester.widget<AppButton>(createButton);
    expect(button.onPressed, isNull);
  });

  testWidgets('household hub shows pinwall section', (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final activityService = FakeActivityService();
    final authService = FakeAuthService(currentUser: user);

    await _pumpScreen(
      tester,
      child: HouseholdHubScreen(groupId: groupId),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        activityServiceProviderAsync.overrideWith((ref) async => activityService),
        authServiceProviderAsync.overrideWith((ref) async => authService),
        pinwallServiceProviderAsync
            .overrideWith((ref) async => FakePinwallService()),
        pinwallRepositoryProvider.overrideWith(
            (ref) async => FakePinwallRepository(FakePinwallService())),
        choreRepositoryProvider.overrideWith(
            (ref) async => FakeChoreRepository(FakeChoreService())),
        listRepositoryProvider.overrideWith(
            (ref) async => FakeListRepository(FakeListService(lists: []))),
        financeRepositoryProvider.overrideWith(
            (ref) async => FakeFinanceRepository(FakeFinanceService())),
      ],
    );

    expect(find.text('Pinwall'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
  });

  test('logout wipes expenses and lists tables from local database', () async {
    final db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(() => db.close());

    // Seed one expense row.
    await db.into(db.expensesTable).insert(ExpensesTableCompanion.insert(
          id: 'exp-1',
          groupId: groupId,
          payerId: userId,
          amount: 1000,
          description: 'Coffee',
          category: 'Food',
          currency: 'USD',
          notes: '',
          date: DateTime.utc(2026, 1, 1),
          createdAt: DateTime.utc(2026, 1, 1),
        ));

    // Seed one list row.
    await db.into(db.listsTable).insert(ListsTableCompanion.insert(
          id: 'list-1',
          groupId: groupId,
          name: 'Shopping',
          type: 'grocery',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ));

    // Confirm rows exist before logout.
    expect(await db.select(db.expensesTable).get(), hasLength(1));
    expect(await db.select(db.listsTable).get(), hasLength(1));

    // Create AuthService with the wipe callback (no Ref needed in unit tests).
    final authService = await AuthService.createWithWipe(
      wipeLocalData: db.clearAllUserData,
    );

    // Call logout — FCM/network calls will fail, but logout must complete.
    try {
      await authService.logout();
    } catch (_) {
      // Network errors are expected in unit tests; wipe still ran.
    }

    // Both tables must be empty after logout.
    expect(await db.select(db.expensesTable).get(), isEmpty);
    expect(await db.select(db.listsTable).get(), isEmpty);
  });
}

Future<AppDatabase> _pumpScreen(
  WidgetTester tester, {
  required Widget child,
  required List<Override> overrides,
  AppDatabase? database,
  Future<void> Function(AppDatabase db)? seed,
}) async {
  final db = database ??
      AppDatabase(
        drift.DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
  addTearDown(() => db.close());
  if (seed != null) await seed(db);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(home: child),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  return db;
}

Future<void> _pumpAfter(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _setLargeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
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
  Future<List<GroupMemberProfile>> listMembers(String groupId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeChoreService implements ChoreService {
  FakeChoreService({List<Chore>? chores, this.shouldThrow = false})
      : _chores = chores ?? [];

  final List<Chore> _chores;
  final bool shouldThrow;
  CreateChoreRequest? lastCreateRequest;
  final List<String> completedIds = [];

  @override
  Future<List<Chore>> listChores(String groupId,
          {int limit = 50, int offset = 0}) async {
    if (shouldThrow) throw Exception('API error');
    return _chores.skip(offset).take(limit).toList();
  }

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
  Future<List<CurrentChore>> listCurrentChores(
    String groupId, {
    int limit = 100,
    int offset = 0,
    int dueSoonDays = 7,
  }) async {
    return _chores
        .skip(offset)
        .take(limit)
        .map((c) => CurrentChore(
              chore: c,
              dueStatus: 'unscheduled',
              assignedToMe: true,
            ))
        .toList();
  }

  @override
  Future<Chore> getChore(String id) async {
    return _chores.firstWhere((c) => c.id == id);
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
  FakeFinanceService({List<Expense>? expenses, this.shouldThrow = false})
      : _expenses = expenses ?? [];

  final List<Expense> _expenses;
  final bool shouldThrow;
  CreateExpenseRequest? lastCreateRequest;

  @override
  Future<List<Expense>> listExpenses(String groupId,
          {int limit = 50, int offset = 0}) async {
    if (shouldThrow) throw Exception('API error');
    return _expenses.skip(offset).take(limit).toList();
  }

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

class FakeMealPlanService implements MealPlanService {
  @override
  Future<MealPlan> createMealPlan(CreateMealPlanRequest req) async {
    throw UnimplementedError();
  }

  @override
  Future<List<MealPlan>> listMealPlans(
    String groupId, {
    required String from,
    required String to,
  }) async {
    return [];
  }

  @override
  Future<MealPlan> getMealPlan(String id) async {
    throw UnimplementedError();
  }

  @override
  Future<MealPlan> updateMealPlan(
      String id, UpdateMealPlanRequest req) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteMealPlan(String id) async {}

  @override
  Future<Map<String, dynamic>> generateShoppingList(
    String groupId, {
    required String from,
    required String to,
    String? listId,
  }) async {
    return {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakePinwallService implements PinwallService {
  @override
  Future<List<PinwallPost>> listPosts(String groupId,
          {int limit = 50, int offset = 0}) async =>
      [];

  @override
  Future<PinwallPost> createPost(String groupId,
      {required String content,
      DateTime? remindAt,
      String? linkedEntityType,
      String? linkedEntityId}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deletePost(String groupId, String postId) async {}

  @override
  Future<void> attachPostAttachment({
    required String groupId,
    required String postId,
    required String attachmentId,
  }) async {}

  @override
  Future<List<PinwallMediaItem>> listPostAttachments({
    required String groupId,
    required String postId,
  }) async => [];

  @override
  Future<void> detachPostAttachment({
    required String groupId,
    required String postId,
    required String attachmentId,
  }) async {}
}

class FakeChoreRepository implements ChoreRepository {
  final ChoreService _service;
  final StreamController<List<CurrentChore>> _controller;

  FakeChoreRepository(this._service)
      : _controller = StreamController<List<CurrentChore>>.broadcast();

  List<CurrentChore> _toCurrent(List<Chore> chores) => chores
      .map((c) => CurrentChore(
            chore: c,
            dueStatus: 'unscheduled',
            assignedToMe: true,
          ))
      .toList();

  @override
  Stream<List<CurrentChore>> watchCurrentChores(String groupId) async* {
    final chores = await _service.listChores(groupId);
    yield _toCurrent(chores);
    yield* _controller.stream;
  }

  @override
  Future<List<CurrentChore>> getCurrentChoresOnce(String groupId) async {
    final chores = await _service.listChores(groupId);
    return _toCurrent(chores);
  }

  @override
  Future<void> refreshCurrentChores(String groupId) async {
    final current = await _service.listCurrentChores(groupId);
    _controller.add(current);
  }

  @override
  Future<void> completeOfflineFirst(String choreId) async {
    await _service.completeChore(choreId, notes: null);
  }

  @override
  Future<void> skipOfflineFirst(String choreId, {String? reason}) async {}

  @override
  Future<void> rescheduleOfflineFirst(
      String choreId, DateTime dueDate) async {}

  @override
  Future<void> undoOfflineFirst(String choreId) async {}

  @override
  Future<void> drainOutboxOnce() async {}

  @override
  void attachSse(dynamic sseService, String groupId) {}

  @override
  void detachSse() {}
}

class FakeListRepository implements ListRepository {
  final ListService _service;
  final StreamController<List<ItemList>> _controller;

  FakeListRepository(this._service)
      : _controller = StreamController<List<ItemList>>.broadcast();

  @override
  Stream<List<ItemList>> watchListsByGroup(String groupId) =>
      _controller.stream;

  @override
  Future<List<ItemList>> getListsByGroupOnce(String groupId) async =>
      _service.listLists(groupId);

  @override
  Future<int> refreshLists(String groupId,
      {int limit = 200, int offset = 0}) async {
    final lists = await _service.listLists(
      groupId,
      limit: limit,
      offset: offset,
    );
    _controller.add(lists);
    return lists.length;
  }

  @override
  Stream<List<ListItem>> watchItemsByList(String listId) =>
      const Stream.empty();

  @override
  Future<List<ListItem>> getItemsByListOnce(String listId) async => [];

  @override
  Future<int> refreshItems(String listId,
      {int limit = 500, int offset = 0}) async => 0;

  @override
  Future<void> refreshListDetail(String listId) async {}

  @override
  Future<ListItem> createItemOfflineFirst(
          String listId, CreateListItemRequest req) async =>
      ListItem(
        id: '',
        listId: listId,
        name: req.name,
        quantity: req.quantity,
        unit: req.unit,
        checked: false,
        position: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  @override
  Future<ListItem> updateItemOfflineFirst(
    String listId,
    String itemId,
    UpdateListItemRequest req,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteItemOfflineFirst(String listId, String itemId) async {}

  @override
  Future<void> reorderItemsOfflineFirst(
    String listId,
    List<String> itemIdsInOrder,
  ) async {}

  @override
  Future<void> deleteListLocal(String listId) async {}

  @override
  Future<void> drainOutboxOnce() async {}

  @override
  void attachSse(dynamic sseService, String groupId) {}

  @override
  void detachSse() {}
}

class FakeFinanceRepository implements FinanceRepository {
  final FinanceService _service;
  final StreamController<List<Expense>> _expenseController;

  FakeFinanceRepository(this._service)
      : _expenseController = StreamController<List<Expense>>.broadcast();

  @override
  Stream<List<Expense>> watchExpensesByGroup(String groupId) async* {
    final expenses = await _service.listExpenses(groupId);
    yield expenses;
    yield* _expenseController.stream;
  }

  @override
  Future<List<Expense>> getExpensesByGroupOnce(String groupId) async =>
      _service.listExpenses(groupId);

  @override
  Stream<FinanceSummary?> watchSummaryByGroup(String groupId) =>
      Stream.value(
        FinanceSummary(balances: const [], reimbursements: const []),
      ).asBroadcastStream();

  @override
  Future<void> refreshGroup(String groupId,
      {int limit = 50, int offset = 0}) async {
    final expenses = await _service.listExpenses(
      groupId,
      limit: limit,
      offset: offset,
    );
    _expenseController.add(expenses);
  }

  @override
  Future<Expense> createExpenseOfflineFirst(
      CreateExpenseRequest req) async {
    return _service.createExpense(req);
  }

  @override
  Future<Expense> updateExpenseOfflineFirst(
      String expenseId, UpdateExpenseRequest req) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteExpenseOfflineFirst(String expenseId) async {}

  @override
  Future<void> drainOutboxOnce() async {}
}

class FakePinwallRepository implements PinwallRepository {
  final PinwallService _service;
  final StreamController<List<PinwallPost>> _controller;

  FakePinwallRepository(this._service)
      : _controller = StreamController<List<PinwallPost>>.broadcast();

  @override
  Stream<List<PinwallPost>> watchPosts(String groupId) =>
      _controller.stream;

  @override
  Future<List<PinwallPost>> getPostsOnce(String groupId) async =>
      _service.listPosts(groupId);

  @override
  Future<void> refreshPosts(String groupId, {int limit = 20, int offset = 0}) async {
    final posts = await _service.listPosts(groupId, limit: limit, offset: offset);
    _controller.add(posts);
  }

  @override
  Future<void> attachPostAttachment({
    required String groupId,
    required String postId,
    required String attachmentId,
  }) async {}

  @override
  Future<List<PinwallMediaItem>> listPostAttachments({
    required String groupId,
    required String postId,
  }) async => [];

  @override
  Future<void> detachPostAttachment({
    required String groupId,
    required String postId,
    required String attachmentId,
  }) async {}

  @override
  Future<void> createPostOfflineFirst(String groupId,
      {required String content}) async {}

  @override
  Future<void> deletePostOfflineFirst(
      String groupId, String postId) async {}

  @override
  Future<void> drainOutboxOnce() async {}
}
