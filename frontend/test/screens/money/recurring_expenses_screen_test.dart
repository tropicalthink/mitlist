import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/finance_models.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/providers/finance_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/grocery_provider.dart';
import 'package:mitlist/providers/list_provider.dart' show grocerySeedProvider;
import 'package:mitlist/screens/money/recurring_expenses_screen.dart';
import 'package:mitlist/services/finance_service.dart';
import 'package:mitlist/services/grocery_expense_category_service.dart';
import 'package:mitlist/widgets/chip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const groupId = '11111111-1111-1111-1111-111111111111';
  const userId = '22222222-2222-2222-2222-222222222222';
  final group = Group(
    id: groupId,
    name: 'Test Household',
    description: '',
    memberCount: 1,
    currency: 'EUR',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  testWidgets('suggests groceries but respects a manual recurring category',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final finance = _FakeRecurringFinanceService(groupId, userId);
    var resolverCalls = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cachedGroupsProvider.overrideWith((ref) async => [group]),
          financeServiceProviderAsync.overrideWith((ref) async => finance),
          grocerySeedProvider.overrideWith((ref) async {}),
          groceryExpenseCategoryServiceProvider.overrideWithValue(
            GroceryExpenseCategoryService.withResolver(
              (text, groupId) async {
                resolverCalls++;
                return 'canonical-milk';
              },
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

    await tester.tap(find.text('ADD EXPENSE'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'Milk delivery');
    await tester.enterText(fields.at(1), '12.50');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));
    expect(resolverCalls, greaterThan(0));

    AppChip chip(String label) => tester.widget<AppChip>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(AppChip),
          ),
        );
    expect(chip('Groceries').selected, isTrue);

    await tester.tap(find.text('Transport'));
    await tester.pump();
    expect(chip('Transport').selected, isTrue);
    await tester.tap(find.text('SAVE'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(finance.lastCreate?.category, 'transport');
  });
}

class _FakeRecurringFinanceService implements FinanceService {
  _FakeRecurringFinanceService(this.groupId, this.userId);

  final String groupId;
  final String userId;
  CreateRecurringExpenseRequest? lastCreate;

  @override
  Future<List<RecurringExpense>> listRecurringExpenses(
    String groupId, {
    int limit = 50,
    int offset = 0,
  }) async =>
      const [];

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
      payerId: userId,
      amount: req.amount,
      description: req.description,
      category: req.category,
      currency: 'EUR',
      frequency: req.frequency,
      nextDue: req.nextDue,
      isActive: true,
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
