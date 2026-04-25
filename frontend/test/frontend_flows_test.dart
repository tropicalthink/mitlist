import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:goflutter/models/auth_models.dart';
import 'package:goflutter/models/chore_models.dart';
import 'package:goflutter/models/finance_models.dart';
import 'package:goflutter/models/group_models.dart';
import 'package:goflutter/models/living_models.dart' as living_models;
import 'package:goflutter/models/list_models.dart';
import 'package:goflutter/models/recipe_models.dart';
import 'package:goflutter/models/vault_models.dart';
import 'package:goflutter/providers/auth_provider.dart';
import 'package:goflutter/providers/chore_provider.dart';
import 'package:goflutter/providers/finance_provider.dart';
import 'package:goflutter/providers/group_provider.dart';
import 'package:goflutter/providers/living_provider.dart';
import 'package:goflutter/providers/list_provider.dart';
import 'package:goflutter/providers/recipe_provider.dart';
import 'package:goflutter/providers/vault_provider.dart';
import 'package:goflutter/screens/chores/chores_screen.dart';
import 'package:goflutter/screens/home/groups_list_screen.dart';
import 'package:goflutter/screens/home/household_hub_screen.dart';
import 'package:goflutter/screens/living_things/living_things_screen.dart';
import 'package:goflutter/screens/lists/lists_screen.dart';
import 'package:goflutter/screens/money/expenses_screen.dart';
import 'package:goflutter/screens/recipes/recipes_screen.dart';
import 'package:goflutter/screens/vault/vault_screen.dart';
import 'package:goflutter/services/auth_service.dart';
import 'package:goflutter/services/chore_service.dart';
import 'package:goflutter/services/finance_service.dart';
import 'package:goflutter/services/group_service.dart';
import 'package:goflutter/services/living_service.dart';
import 'package:goflutter/services/list_service.dart';
import 'package:goflutter/services/recipe_service.dart';
import 'package:goflutter/services/vault_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
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

  testWidgets('vault item creation flow persists direct content and refreshes',
      (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final vaultService = FakeVaultService();

    await _pumpScreen(
      tester,
      child: const VaultScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        vaultServiceProviderAsync.overrideWith((ref) async => vaultService),
      ],
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Home Wi-Fi');
    await tester.enterText(find.byType(TextField).at(1), 'Password: hunter2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE ITEM'));
    await tester.pumpAndSettle();

    expect(vaultService.lastCreateRequest, isNotNull);
    expect(vaultService.lastCreateRequest!.title, 'Home Wi-Fi');
    expect(vaultService.lastCreateRequest!.content, 'Password: hunter2');
    expect(find.text('Home Wi-Fi'), findsOneWidget);
  });

  testWidgets('vault item card opens a real detail sheet', (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final vaultService = FakeVaultService(
      items: [
        VaultItem(
          id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
          groupId: groupId,
          type: 'document',
          title: 'Insurance Policy',
          content: 'Policy number: 12345',
          reminderDate: DateTime.utc(2026, 6, 1),
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
      ],
    );

    await _pumpScreen(
      tester,
      child: const VaultScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        vaultServiceProviderAsync.overrideWith((ref) async => vaultService),
      ],
    );

    await tester.tap(find.text('Insurance Policy'));
    await tester.pumpAndSettle();

    expect(find.text('Vault Item'), findsOneWidget);
    expect(find.text('Policy number: 12345'), findsOneWidget);
  });

  testWidgets('living things flow creates and opens a detail sheet',
      (tester) async {
    await _setLargeSurface(tester);
    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final livingService = FakeLivingService();

    await _pumpScreen(
      tester,
      child: const LivingThingsScreen(),
      overrides: [
        groupServiceProviderAsync.overrideWith((ref) async => groupService),
        livingServiceProviderAsync.overrideWith((ref) async => livingService),
      ],
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Miso');
    await tester.tap(find.text('Pet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plant').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'Kitchen window');
    await tester.tap(find.text('ADD ITEM'));
    await tester.pumpAndSettle();

    expect(livingService.lastCreateRequest, isNotNull);
    expect(livingService.lastCreateRequest!.name, 'Miso');
    expect(livingService.lastCreateRequest!.species, 'plant');
    expect(find.text('Kitchen window'), findsOneWidget);
    expect(find.textContaining('Next care:'), findsNothing);

    await tester.tap(find.text('Miso'));
    await tester.pumpAndSettle();

    expect(find.text('Pet or Plant'), findsOneWidget);
    expect(find.text('Kitchen window'), findsWidgets);
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

    await tester.enterText(find.byType(TextField).first, 'abcd-1234');
    await tester.pumpAndSettle();
    await tester.tap(find.text('JOIN HOUSEHOLD'));
    await tester.pumpAndSettle();

    expect(groupService.lastJoinRequest, isNotNull);
    expect(groupService.lastJoinRequest!.code, 'ABCD-1234');
    expect(find.text('Joined Household'), findsOneWidget);
  });

  testWidgets(
      'household hub quick actions navigate to vault, living things, and recipes',
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
          path: '/vault',
          name: 'vault',
          builder: (context, state) =>
              const Scaffold(body: Text('Vault route')),
        ),
        GoRoute(
          path: '/living-things',
          name: 'livingThings',
          builder: (context, state) =>
              const Scaffold(body: Text('Living route')),
        ),
        GoRoute(
          path: '/recipes',
          name: 'recipes',
          builder: (context, state) =>
              const Scaffold(body: Text('Recipes route')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupServiceProviderAsync.overrideWith((ref) async => groupService),
          listServiceProviderAsync.overrideWith((ref) async => listService),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vault'));
    await tester.pumpAndSettle();
    expect(find.text('Vault route'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Pets & Plants'));
    await tester.tap(find.text('Pets & Plants'));
    await tester.pumpAndSettle();
    expect(find.text('Living route'), findsOneWidget);

    router.go('/');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Recipes'));
    await tester.tap(find.text('Recipes'));
    await tester.pumpAndSettle();
    expect(find.text('Recipes route'), findsOneWidget);
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

  @override
  Future<User> getMe() async => currentUser;

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

class FakeVaultService implements VaultService {
  FakeVaultService({List<VaultItem>? items}) : _items = items ?? [];

  final List<VaultItem> _items;
  CreateVaultItemRequest? lastCreateRequest;

  @override
  Future<List<VaultItem>> listVaultItems(String groupId,
          {int limit = 50, int offset = 0}) async =>
      _items.skip(offset).take(limit).toList();

  @override
  Future<VaultItem> createVaultItem(CreateVaultItemRequest req) async {
    lastCreateRequest = req;
    final item = VaultItem(
      id: '88888888-8888-8888-8888-888888888888',
      groupId: req.groupId,
      type: req.type,
      title: req.title,
      content: req.content,
      reminderDate: req.reminderDate,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    _items.add(item);
    return item;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeLivingService implements LivingService {
  FakeLivingService({List<living_models.LivingThing>? items})
      : _items = items ?? [];

  final List<living_models.LivingThing> _items;
  living_models.CreateLivingThingRequest? lastCreateRequest;

  @override
  Future<List<living_models.LivingThing>> listLivingThings(
    String groupId, {
    int limit = 50,
    int offset = 0,
  }) async =>
      _items.skip(offset).take(limit).toList();

  @override
  Future<living_models.LivingThing> createLivingThing(
    living_models.CreateLivingThingRequest req,
  ) async {
    lastCreateRequest = req;
    final item = living_models.LivingThing(
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      groupId: req.groupId,
      name: req.name,
      species: req.species,
      location: req.location,
      imageUrl: req.imageUrl,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
    _items.add(item);
    return item;
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
