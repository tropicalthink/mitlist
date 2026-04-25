import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/finance_models.dart';
import 'api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FinanceService {
  final Dio _dio;
  final Logger _logger = Logger();
  FinanceService._(this._dio);
  static Future<FinanceService> create([Ref? ref]) async {
    final dio = createApiClient(ref);
    return FinanceService._(dio);
  }

  Future<Expense> createExpense(CreateExpenseRequest req) async {
    try {
      final r = await _dio.post('/expenses', data: req.toJson());
      return Expense.fromJson(r.data);
    } on DioException catch (e) { _logger.e('Create expense failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<List<Expense>> listExpenses(String groupId, {int limit = 50, int offset = 0}) async {
    try {
      final r = await _dio.get('/expenses', queryParameters: {'group_id': groupId, 'limit': limit, 'offset': offset});
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => Expense.fromJson(j)).toList();
    } on DioException catch (e) { _logger.e('List expenses failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<Expense> getExpense(String id) async {
    try {
      final r = await _dio.get('/expenses/$id');
      return Expense.fromJson(r.data);
    } on DioException catch (e) { _logger.e('Get expense failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<void> deleteExpense(String id) async {
    try { await _dio.delete('/expenses/$id'); }
    on DioException catch (e) { _logger.e('Delete expense failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<void> createSplit(String expenseId, CreateSplitRequest req) async {
    try { await _dio.post('/expenses/$expenseId/splits', data: req.toJson()); }
    on DioException catch (e) { _logger.e('Create split failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Future<void> createSettlement(String expenseId, CreateSettlementRequest req) async {
    try { await _dio.post('/expenses/$expenseId/settle', data: req.toJson()); }
    on DioException catch (e) { _logger.e('Create settlement failed: ${e.response?.data}'); throw _handleError(e); }
  }

  Exception _handleError(DioException e) {
    if (e.response?.statusCode == 401) return Exception('Session expired');
    if (e.response?.statusCode == 403) return Exception('Access denied');
    if (e.response?.statusCode == 404) return Exception('Not found');
    if (e.type == DioExceptionType.connectionError) return Exception('Network error');
    return Exception('An error occurred');
  }
}
