import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/finance_service.dart';
import '../models/finance_models.dart';

final financeServiceProviderAsync = FutureProvider<FinanceService>((ref) async {
  return await FinanceService.create(ref);
});

final expensesByGroupProvider = FutureProvider.family<List<Expense>, String>((ref, groupId) async {
  final service = await ref.read(financeServiceProviderAsync.future);
  return service.listExpenses(groupId);
});
