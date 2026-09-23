import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/finance_service.dart';
import '../models/finance_models.dart';
import '../providers/list_provider.dart';
import '../repositories/finance_repository.dart';

final financeServiceProviderAsync = FutureProvider<FinanceService>((ref) async {
  return await FinanceService.create(ref);
});

final financeRepositoryProvider =
    FutureProvider<FinanceRepository>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final service = await ref.read(financeServiceProviderAsync.future);
  return FinanceRepository(
    db: db,
    remote: service,
    onLocalWrite: ref.watch(syncSchedulerProvider).noteLocalWrite,
  );
});

final cachedExpensesByGroupProvider =
    StreamProvider.family<List<Expense>, String>((ref, groupId) async* {
  ref.keepAlive();
  final repo = await ref.watch(financeRepositoryProvider.future);
  yield* repo.watchExpensesByGroup(groupId);
});

final cachedFinanceSummaryByGroupProvider =
    StreamProvider.family<FinanceSummary?, String>((ref, groupId) async* {
  ref.keepAlive();
  final repo = await ref.watch(financeRepositoryProvider.future);
  yield* repo.watchSummaryByGroup(groupId);
});

final expensesByGroupProvider =
    FutureProvider.family<List<Expense>, String>((ref, groupId) async {
  final service = await ref.read(financeServiceProviderAsync.future);
  return service.listExpenses(groupId);
});

final financeSummaryByGroupProvider =
    FutureProvider.family<FinanceSummary, String>((ref, groupId) async {
  final service = await ref.read(financeServiceProviderAsync.future);
  return service.getFinanceSummary(groupId);
});
