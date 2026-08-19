// Safety net for the ExpensesScreen decomposition (plan 037). Mounts the
// screen with Riverpod overrides (modeled on `frontend_flows_test.dart`'s
// harness) and asserts the two key states the plan calls out: the rendered
// expense list and the create action. Must pass before and after the
// controller extraction to prove behavior parity.

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
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
import 'package:mitlist/providers/list_provider.dart' show appDatabaseProvider;
import 'package:mitlist/repositories/finance_repository.dart';
import 'package:mitlist/screens/money/expenses_screen.dart';
import 'package:mitlist/services/auth_service.dart';
import 'package:mitlist/services/finance_service.dart';
import 'package:mitlist/services/group_service.dart';
import 'package:mitlist/storage/app_database.dart' hide FinanceSummary;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const groupId = '11111111-1111-1111-1111-111111111111';
  const userId = '22222222-2222-2222-2222-222222222222';

  setUp(() {
    SharedPreferences.setMockInitialValues({'current_group_id': groupId});
  });

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

  final expense = Expense(
    id: '66666666-6666-6666-6666-666666666666',
    groupId: groupId,
    payerId: userId,
    amount: 1234,
    baseAmount: 1234,
    fxRate: 1.0,
    description: 'Groceries',
    // Distinct from the description so 'Groceries' stays the unique row
    // identifier now that the category renders its own localized label.
    category: 'dining',
    currency: 'USD',
    notes: '',
    date: DateTime.utc(2026, 1, 15),
    createdAt: DateTime.utc(2026, 1, 15),
  );

  testWidgets('renders the expense timeline and the create action',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(() => db.close());

    final groupService = FakeGroupService(groups: [group], groupDetail: group);
    final authService = FakeAuthService(currentUser: user);
    final financeService = FakeFinanceService(expenses: [expense]);
    final financeRepo = FakeFinanceRepository(financeService);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => true),
          groupServiceProviderAsync.overrideWith((ref) async => groupService),
          authServiceProviderAsync.overrideWith((ref) async => authService),
          financeServiceProviderAsync
              .overrideWith((ref) async => financeService),
          financeRepositoryProvider.overrideWith((ref) async => financeRepo),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ExpensesScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    // Key state 1: the expense timeline renders the fetched expense.
    expect(find.text('Groceries'), findsOneWidget);

    // Key state 2: the create action is present. AppButton's solid variant
    // (the FAB's default) uppercases its label — see AppButton._displayText.
    expect(find.text('ADD EXPENSE'), findsOneWidget);
  });
}

// ---------------------------------------------------------------------------
// Fakes (mirroring the pattern in frontend_flows_test.dart)
// ---------------------------------------------------------------------------

class FakeGroupService implements GroupService {
  FakeGroupService({required this.groups, this.groupDetail});

  final List<Group> groups;
  final Group? groupDetail;

  @override
  Future<List<Group>> listGroups({int limit = 50, int offset = 0}) async =>
      groups.take(limit).toList();

  @override
  Future<Group> getGroup(String groupId) async => groupDetail ?? groups.first;

  @override
  Future<List<GroupMemberProfile>> listMembers(String groupId) async => [];

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
  Future<Expense> createExpense(CreateExpenseRequest req,
      {String? idempotencyKey}) async {
    lastCreateRequest = req;
    final created = Expense(
      id: '77777777-7777-7777-7777-777777777777',
      groupId: req.groupId,
      payerId: req.payerId,
      amount: req.amount,
      baseAmount: req.baseAmount,
      fxRate: req.fxRate,
      description: req.description,
      category: req.category,
      currency: req.currency,
      notes: req.notes,
      date: req.date,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    _expenses.add(created);
    return created;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeFinanceRepository implements FinanceRepository {
  FakeFinanceRepository(this._service);

  final FinanceService _service;

  @override
  Stream<List<Expense>> watchExpensesByGroup(String groupId) async* {
    yield await _service.listExpenses(groupId);
  }

  @override
  Future<List<Expense>> getExpensesByGroupOnce(String groupId) async =>
      _service.listExpenses(groupId);

  @override
  Stream<FinanceSummary?> watchSummaryByGroup(String groupId) => Stream.value(
        const FinanceSummary(balances: [], reimbursements: []),
      ).asBroadcastStream();

  // Settlements are cache-backed; this fake just proxies the service so the
  // screen tests keep exercising whatever the fake service returns.
  final List<Settlement> settlements = [];

  @override
  Stream<List<Settlement>> watchSettlements(String groupId) =>
      Stream.value(settlements);

  @override
  Future<List<Settlement>> getSettlementsOnce(String groupId) async =>
      settlements;

  @override
  Future<List<Settlement>> loadSettlements(String groupId) async {
    try {
      final fresh = await _service.listSettlements(groupId);
      settlements
        ..clear()
        ..addAll(fresh);
    } catch (_) {
      // Offline: keep whatever we have, same as the real repository.
    }
    return settlements;
  }

  @override
  Future<Settlement> recordSettlementOfflineFirst({
    required String groupId,
    required CreateSettlementRequest req,
    required String createdBy,
  }) async {
    final local = Settlement(
      id: 'local-test-${settlements.length}',
      groupId: groupId,
      fromUserId: req.fromUserId,
      toUserId: req.toUserId,
      amount: req.amount,
      status: SettlementStatus.pending,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
    settlements.add(local);
    return local;
  }

  @override
  Future<void> cancelLocalSettlement(
      String groupId, String settlementId) async {
    settlements.removeWhere((s) => s.id == settlementId);
  }

  // Conflict resolution is exercised in finance_repository_test; these screen
  // flows never reach it.
  @override
  Future<void> resolveConflictAcceptServer(Conflict conflict) async {}

  @override
  Future<void> resolveConflictKeepLocal(Conflict conflict) async {}

  @override
  Future<int> refreshGroup(String groupId,
      {int limit = 50, int offset = 0}) async {
    final expenses = await _service.listExpenses(
      groupId,
      limit: limit,
      offset: offset,
    );
    return expenses.length;
  }

  @override
  Future<Expense> createExpenseOfflineFirst(CreateExpenseRequest req) async {
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
