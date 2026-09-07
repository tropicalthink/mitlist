// The recurring list no longer owns a creation form: it opens the shared
// ExpenseCreationSheet locked to a repeat schedule. These tests cover what that
// fold is worth — a rule now carries the split config the job needs, instead of
// silently landing entirely on the payer.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/auth_models.dart';
import 'package:mitlist/models/finance_models.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/providers/auth_provider.dart';
import 'package:mitlist/providers/finance_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/grocery_provider.dart';
import 'package:mitlist/providers/list_provider.dart' show grocerySeedProvider;
import 'package:mitlist/screens/money/recurring_expenses_screen.dart';
import 'package:mitlist/services/auth_service.dart';
import 'package:mitlist/services/finance_service.dart';
import 'package:mitlist/services/grocery_expense_category_service.dart';
import 'package:mitlist/services/group_service.dart';
import 'package:mitlist/widgets/chip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const groupId = '11111111-1111-1111-1111-111111111111';
  const userId = '22222222-2222-2222-2222-222222222222';
  const otherId = '44444444-4444-4444-4444-444444444444';

  setUp(() {
    SharedPreferences.setMockInitialValues({'current_group_id': groupId});
  });

  final group = Group(
    id: groupId,
    name: 'Test Household',
    description: '',
    memberCount: 2,
    currency: 'EUR',
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

  const members = [
    GroupMemberProfile(userId: userId, displayName: 'Test User', role: 'owner'),
    GroupMemberProfile(userId: otherId, displayName: 'Sam', role: 'member'),
  ];

  Future<void> pumpScreen(
    WidgetTester tester,
    _FakeRecurringFinanceService finance, {
    Future<String?> Function(String, String)? resolver,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => true),
          cachedGroupsProvider.overrideWith((ref) async => [group]),
          groupServiceProviderAsync.overrideWith(
            (ref) async => FakeGroupService(groups: [group], members: members),
          ),
          authServiceProviderAsync
              .overrideWith((ref) async => FakeAuthService(currentUser: user)),
          financeServiceProviderAsync.overrideWith((ref) async => finance),
          grocerySeedProvider.overrideWith((ref) async {}),
          groceryExpenseCategoryServiceProvider.overrideWithValue(
            GroceryExpenseCategoryService.withResolver(
              resolver ?? (text, groupId) async => 'canonical-milk',
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RecurringExpensesScreen(),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a new rule carries its split config and household currency',
      (tester) async {
    final finance = _FakeRecurringFinanceService(groupId, userId);
    await pumpScreen(tester, finance);

    await tester.tap(find.text('ADD EXPENSE'));
    await tester.pumpAndSettle();

    // The shared editor opened locked to a schedule.
    expect(find.text('Repeats monthly'), findsOneWidget);
    expect(find.text("Doesn't repeat"), findsNothing);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '25.00'); // amount is the hero field
    await tester.enterText(fields.at(1), 'Rent');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('SAVE'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final created = finance.lastCreate;
    expect(created, isNotNull);
    expect(created!.amount, 2500);
    expect(created.description, 'Rent');
    expect(created.frequency, 'monthly');
    expect(created.currency, 'EUR');
    // The whole point of the fold: the rule charges the household, not just
    // the payer, because the job now has a split config to rebuild from.
    expect(created.splitMode, 'equal');
    expect(
      created.splitInputs.map((s) => s.userId).toSet(),
      {userId, otherId},
    );
  });

  testWidgets('suggests groceries but respects a manual recurring category',
      (tester) async {
    final finance = _FakeRecurringFinanceService(groupId, userId);
    var resolverCalls = 0;
    await pumpScreen(
      tester,
      finance,
      resolver: (text, groupId) async {
        resolverCalls++;
        return 'canonical-milk';
      },
    );

    await tester.tap(find.text('ADD EXPENSE'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '12.50');
    await tester.enterText(fields.at(1), 'Milk delivery');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));
    expect(resolverCalls, greaterThan(0));

    AppChip chip(String label) => tester.widget<AppChip>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(AppChip),
          ),
        );
    // The category folds to a summary line; the suggestion has to read there.
    expect(find.text('Category · Groceries'), findsOneWidget);

    // Unfold it to override the suggestion by hand.
    await tester.ensureVisible(find.text('Category · Groceries'));
    await tester.tap(find.text('Category · Groceries'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(chip('Groceries').selected, isTrue);

    await tester.ensureVisible(find.text('Transport'));
    await tester.tap(find.text('Transport'));
    await tester.pump();
    expect(chip('Transport').selected, isTrue);

    await tester.tap(find.text('SAVE'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(finance.lastCreate?.category, 'transport');
  });

  testWidgets('editing an existing rule prefills it and PATCHes',
      (tester) async {
    final finance = _FakeRecurringFinanceService(groupId, userId)
      ..items = [
        RecurringExpense(
          id: '33333333-3333-3333-3333-333333333333',
          groupId: groupId,
          payerId: userId,
          amount: 4000,
          description: 'Internet',
          category: 'utilities',
          currency: 'EUR',
          frequency: 'quarterly',
          nextDue: DateTime.now().add(const Duration(days: 10)),
          isActive: true,
          createdAt: DateTime.utc(2026, 1, 1),
          splitMode: 'equal',
          splitInputs: const [RecurringSplitInput(userId: userId)],
        ),
      ];
    await pumpScreen(tester, finance);

    await tester.tap(find.text('Internet'));
    await tester.pumpAndSettle();

    // Prefilled from the rule, not from defaults.
    expect(find.text('Repeats quarterly'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Internet'), findsOneWidget);
    expect(find.widgetWithText(TextField, '40.00'), findsOneWidget);
    // The rule leaves Sam out, so the split editor is unfolded rather than
    // hiding that behind "split equally" — which pushes the button down.
    expect(find.text('Sam'), findsWidgets);

    await tester.ensureVisible(find.text('SAVE'));
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(finance.lastUpdateId, '33333333-3333-3333-3333-333333333333');
    expect(finance.lastUpdate?.frequency, 'quarterly');
    expect(finance.lastUpdate?.amount, 4000);
    // The rule's own participant list survives the round-trip rather than
    // being reset to "everyone".
    expect(finance.lastUpdate?.splitInputs?.map((s) => s.userId).toList(),
        [userId]);
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeRecurringFinanceService implements FinanceService {
  _FakeRecurringFinanceService(this.groupId, this.userId);

  final String groupId;
  final String userId;
  List<RecurringExpense> items = const [];
  CreateRecurringExpenseRequest? lastCreate;
  UpdateRecurringExpenseRequest? lastUpdate;
  String? lastUpdateId;

  @override
  Future<List<RecurringExpense>> listRecurringExpenses(
    String groupId, {
    int limit = 50,
    int offset = 0,
  }) async =>
      items;

  @override
  Future<FinanceSummary> getFinanceSummary(String groupId) async =>
      FinanceSummary(
        balances: [
          BalanceEntry(
            userId: userId,
            displayName: 'Test User',
            paid: 0,
            owed: 0,
            total: 0,
          ),
        ],
        reimbursements: const [],
      );

  @override
  Future<RecurringExpense> createRecurringExpense(
    CreateRecurringExpenseRequest req,
  ) async {
    lastCreate = req;
    return RecurringExpense(
      id: '33333333-3333-3333-3333-333333333333',
      groupId: groupId,
      payerId: req.payerId,
      amount: req.amount,
      description: req.description,
      category: req.category,
      currency: req.currency ?? 'EUR',
      frequency: req.frequency,
      nextDue: req.nextDue,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
      splitMode: req.splitMode,
      splitInputs: req.splitInputs,
    );
  }

  @override
  Future<RecurringExpense> updateRecurringExpense(
    String id,
    UpdateRecurringExpenseRequest req,
  ) async {
    lastUpdateId = id;
    lastUpdate = req;
    return items.first;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeGroupService implements GroupService {
  FakeGroupService({required this.groups, required this.members});

  final List<Group> groups;
  final List<GroupMemberProfile> members;

  @override
  Future<List<Group>> listGroups({int limit = 50, int offset = 0}) async =>
      groups.take(limit).toList();

  @override
  Future<Group> getGroup(String groupId) async => groups.first;

  @override
  Future<List<GroupMemberProfile>> listMembers(String groupId) async => members;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeAuthService implements AuthService {
  FakeAuthService({required this.currentUser});

  final User currentUser;

  @override
  Future<User> getMe() async => currentUser;

  @override
  User? get cachedMe => currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
