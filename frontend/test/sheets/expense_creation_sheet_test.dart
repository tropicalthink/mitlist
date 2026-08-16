// Verifies the Splitwise/Tricount-style folding of the expense creation sheet:
// the payer + split editor is collapsed to a one-line summary by default and
// only unfolds the full split grid when the summary is tapped.

import 'dart:async';

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
import 'package:mitlist/sheets/expense_creation_sheet.dart';
import 'package:mitlist/services/auth_service.dart';
import 'package:mitlist/services/finance_service.dart';
import 'package:mitlist/services/grocery_expense_category_service.dart';
import 'package:mitlist/services/group_service.dart';
import 'package:mitlist/widgets/chip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const groupId = '11111111-1111-1111-1111-111111111111';
  const userId = '22222222-2222-2222-2222-222222222222';
  const otherId = '33333333-3333-3333-3333-333333333333';

  setUp(() {
    SharedPreferences.setMockInitialValues({'current_group_id': groupId});
  });

  final group = Group(
    id: groupId,
    name: 'Test Household',
    description: 'Home base',
    memberCount: 2,
    currency: 'USD',
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

  Future<void> pumpSheet(
    WidgetTester tester, {
    String? initialDescription,
    List<Override> extraOverrides = const [],
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => true),
          // Serve the group list directly so the sheet's group/member load
          // doesn't hang on the Drift-backed groupRepositoryProvider.
          cachedGroupsProvider.overrideWith((ref) async => [group]),
          groupServiceProviderAsync.overrideWith(
            (ref) async => FakeGroupService(groups: [group], members: members),
          ),
          authServiceProviderAsync
              .overrideWith((ref) async => FakeAuthService(currentUser: user)),
          ...extraOverrides,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ExpenseCreationSheet(
                initialDescription: initialDescription,
              ),
            ),
          ),
        ),
      ),
    );

    // Let the async group/member load settle.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('folds payer + split into one summary line by default',
      (tester) async {
    await pumpSheet(tester);

    // The calm default: a single sentence, no split grid.
    expect(find.text('Paid by you · split equally'), findsOneWidget);
    // The split-mode chips (the "wall") are hidden while folded.
    expect(find.text('Exact'), findsNothing);
    expect(find.text('Shares'), findsNothing);
    // The per-member "Paid by" picker is also folded away.
    expect(find.text('Sam'), findsNothing);
  });

  testWidgets('tapping the summary unfolds the full split editor',
      (tester) async {
    await pumpSheet(tester);

    final summary = find.text('Paid by you · split equally');
    await tester.ensureVisible(summary);
    await tester.pump();
    await tester.tap(summary);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Now the full editor is revealed: split modes + members.
    expect(find.text('Exact'), findsOneWidget);
    expect(find.text('Shares'), findsOneWidget);
    // Both members appear (payer picker + split checklist).
    expect(find.text('Sam'), findsWidgets);
  });

  testWidgets('suggests groceries from a grocery expense description',
      (tester) async {
    await pumpSheet(
      tester,
      initialDescription: 'milk',
      extraOverrides: [
        grocerySeedProvider.overrideWith((ref) async {}),
        groceryExpenseCategoryServiceProvider.overrideWithValue(
          GroceryExpenseCategoryService.withResolver(
            (text, groupId) async => 'canonical-milk',
          ),
        ),
      ],
    );

    final groceriesChip = tester.widget<AppChip>(
      find.ancestor(
        of: find.text('Groceries'),
        matching: find.byType(AppChip),
      ),
    );
    expect(groceriesChip.selected, isTrue);
  });

  testWidgets('never replaces a category explicitly chosen by the user',
      (tester) async {
    final pendingSuggestion = Completer<String?>();
    await pumpSheet(
      tester,
      initialDescription: 'milk',
      extraOverrides: [
        grocerySeedProvider.overrideWith((ref) async {}),
        groceryExpenseCategoryServiceProvider.overrideWithValue(
          GroceryExpenseCategoryService.withResolver(
            (text, groupId) => pendingSuggestion.future,
          ),
        ),
      ],
    );

    await tester.ensureVisible(find.text('Transport'));
    await tester.tap(find.text('Transport'));
    pendingSuggestion.complete('groceries');
    await tester.pump();

    final transportChip = tester.widget<AppChip>(
      find.ancestor(
        of: find.text('Transport'),
        matching: find.byType(AppChip),
      ),
    );
    final groceriesChip = tester.widget<AppChip>(
      find.ancestor(
        of: find.text('Groceries'),
        matching: find.byType(AppChip),
      ),
    );
    expect(transportChip.selected, isTrue);
    expect(groceriesChip.selected, isFalse);
  });

  testWidgets('percent shares that cannot be written exactly still total 100%',
      (tester) async {
    final finance = FakeFinanceService();
    await pumpSheet(
      tester,
      extraOverrides: [
        financeServiceProviderAsync.overrideWith((ref) async => finance),
      ],
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '100.00');
    await tester.enterText(fields.at(1), 'Dinner');
    await tester.pump();

    // Unfold the split editor and switch to percentage.
    await tester.tap(find.text('Paid by you · split equally'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.ensureVisible(find.text('Percent'));
    await tester.tap(find.text('Percent'));
    await tester.pump();

    // A two-way split of a third / two-thirds: 33.33 + 66.66 rounds to 9999
    // basis points, which the server rejects as "must total 100%".
    final percentFields = find.byType(TextField);
    await tester.enterText(percentFields.at(2), '33.33');
    await tester.enterText(percentFields.at(3), '66.66');
    await tester.pump();

    await tester.ensureVisible(find.text('ADD EXPENSE'));
    await tester.pump();
    await tester.tap(find.text('ADD EXPENSE'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final request = finance.lastCreate;
    expect(request, isNotNull,
        reason: 'the submit should not have been blocked');
    final points = request!.splits.map((s) => s.percentage ?? 0).toList();
    expect(points.reduce((a, b) => a + b), 10000);
    // The stray basis point lands on the larger share, and nobody drops to zero.
    expect(points..sort(), [3333, 6667]);
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

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
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeFinanceService implements FinanceService {
  CreateExpenseRequest? lastCreate;

  @override
  Future<Expense> createExpense(
    CreateExpenseRequest req, {
    String? idempotencyKey,
  }) async {
    lastCreate = req;
    return Expense(
      id: '55555555-5555-5555-5555-555555555555',
      groupId: req.groupId,
      payerId: req.payerId,
      amount: req.amount,
      baseAmount: req.baseAmount,
      fxRate: req.fxRate,
      description: req.description,
      category: req.category,
      currency: req.currency,
      date: req.date,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
