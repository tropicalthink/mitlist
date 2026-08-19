import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/finance_models.dart';
import '../models/expense_receipt_models.dart';
import 'api_client.dart';
import 'api_error_mapper.dart';
import 'group_id_validator.dart';
import 'outbox_request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FinanceService {
  final Dio _dio;
  final Logger _logger = Logger();
  FinanceService._(this._dio);
  static Future<FinanceService> create([Ref? ref]) async {
    final dio = resolveDio(ref);
    return FinanceService._(dio);
  }

  Future<Expense> createExpense(CreateExpenseRequest req,
      {String? idempotencyKey}) async {
    try {
      final r = await _dio.post('/expenses',
          data: req.toJson(), options: outboxOptions(idempotencyKey));
      return Expense.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Create expense failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<Expense>> listExpenses(String groupId,
      {int limit = 50, int offset = 0}) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio.get('/expenses', queryParameters: {
        'group_id': groupId,
        'limit': limit,
        'offset': offset
      });
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => Expense.fromJson(j)).toList();
    } on DioException catch (e) {
      _logger.e('List expenses failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<FinanceSummary> getFinanceSummary(String groupId) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio
          .get('/finance/summary', queryParameters: {'group_id': groupId});
      final data = r.data;
      if (data is! Map) throw ApiException('Unexpected response format');
      return FinanceSummary.fromJson(data.cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Get finance summary failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<Expense>> exportExpensesJson(String groupId) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio
          .get('/finance/export/json', queryParameters: {'group_id': groupId});
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => Expense.fromJson(j)).toList();
    } on DioException catch (e) {
      _logger.e('Export expenses JSON failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<String> exportExpensesCsv(String groupId) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio
          .get('/finance/export/csv', queryParameters: {'group_id': groupId});
      return r.data?.toString() ?? '';
    } on DioException catch (e) {
      _logger.e('Export expenses CSV failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<Expense> getExpense(String id) async {
    try {
      final r = await _dio.get('/expenses/$id');
      return Expense.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Get expense failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<Expense> updateExpense(String id, UpdateExpenseRequest req,
      {String? idempotencyKey}) async {
    try {
      final r = await _dio.patch('/expenses/$id',
          data: req.toJson(), options: outboxOptions(idempotencyKey));
      return Expense.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Update expense failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> deleteExpense(String id, {String? idempotencyKey}) async {
    try {
      await _dio.delete('/expenses/$id',
          options: outboxOptions(idempotencyKey));
    } on DioException catch (e) {
      _logger.e('Delete expense failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<ExpenseReceipt>> listExpenseReceipts({
    required String groupId,
    required String expenseId,
  }) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio.get(
        '/expenses/$expenseId/receipts',
        queryParameters: {'group_id': groupId},
      );
      final data = r.data;
      if (data is! List) return [];
      return data
          .map((e) =>
              ExpenseReceipt.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('List expense receipts failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> attachExpenseReceipt({
    required String groupId,
    required String expenseId,
    required String attachmentId,
  }) async {
    ensureValidGroupId(groupId);
    try {
      await _dio.post(
        '/expenses/$expenseId/receipts',
        data: {
          'group_id': groupId,
          'attachment_id': attachmentId,
        },
      );
    } on DioException catch (e) {
      _logger.e('Attach expense receipt failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> detachExpenseReceipt({
    required String groupId,
    required String expenseId,
    required String attachmentId,
  }) async {
    ensureValidGroupId(groupId);
    try {
      await _dio.delete(
        '/expenses/$expenseId/receipts/$attachmentId',
        queryParameters: {'group_id': groupId},
      );
    } on DioException catch (e) {
      _logger.e('Detach expense receipt failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<Split>> listExpenseSplits(String expenseId) async {
    try {
      final r = await _dio.get('/expenses/$expenseId/splits');
      final data = r.data;
      if (data is! List) throw ApiException('Unexpected response format');
      return data
          .cast<dynamic>()
          .map((e) => Split.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('List splits failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> createSplit(String expenseId, CreateSplitRequest req) async {
    try {
      await _dio.post('/expenses/$expenseId/splits', data: req.toJson());
    } on DioException catch (e) {
      _logger.e('Create split failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<Split> createSplitReturn(
      String expenseId, CreateSplitRequest req) async {
    try {
      final r =
          await _dio.post('/expenses/$expenseId/splits', data: req.toJson());
      final data = r.data;
      if (data is! Map) throw ApiException('Unexpected response format');
      return Split.fromJson(data.cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Create split failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<Split> updateSplit(
      String expenseId, String splitId, UpdateSplitRequest req) async {
    try {
      final r = await _dio.patch('/expenses/$expenseId/splits/$splitId',
          data: req.toJson());
      final data = r.data;
      if (data is! Map) throw ApiException('Unexpected response format');
      return Split.fromJson(data.cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Update split failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> deleteSplit(String expenseId, String splitId) async {
    try {
      await _dio.delete('/expenses/$expenseId/splits/$splitId');
    } on DioException catch (e) {
      _logger.e('Delete split failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<Settlement>> listSettlements(String groupId,
      {int limit = 50, int offset = 0}) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio.get('/finance/settlements', queryParameters: {
        'group_id': groupId,
        'limit': limit,
        'offset': offset,
      });
      final data = r.data;
      if (data is! List) throw ApiException('Unexpected response format');
      return data
          .whereType<Map>()
          .map((e) => Settlement.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('List settlements failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<Settlement> confirmSettlement(String settlementId) =>
      _respondToSettlement(settlementId, 'confirm');

  Future<Settlement> declineSettlement(String settlementId) =>
      _respondToSettlement(settlementId, 'decline');

  Future<Settlement> _respondToSettlement(
      String settlementId, String action) async {
    try {
      final r = await _dio.post('/finance/settlements/$settlementId/$action');
      final data = r.data;
      if (data is! Map) throw ApiException('Unexpected response format');
      return Settlement.fromJson(data.cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Settlement $action failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  /// Cancels (deletes) a settlement — the creator's own pending one,
  /// or any settlement when called by a group admin.
  Future<void> cancelSettlement(String settlementId) async {
    try {
      await _dio.delete('/finance/settlements/$settlementId');
    } on DioException catch (e) {
      _logger.e('Cancel settlement failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<Settlement> createGroupSettlement(
      String groupId, CreateSettlementRequest req,
      {String? idempotencyKey}) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio.post(
        '/finance/settlements',
        data: CreateSettlementRequest(
          groupId: groupId,
          fromUserId: req.fromUserId,
          toUserId: req.toUserId,
          amount: req.amount,
        ).toJson(),
        options: outboxOptions(idempotencyKey),
      );
      final data = r.data;
      if (data is! Map) throw ApiException('Unexpected response format');
      return Settlement.fromJson(data.cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Create group settlement failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  // Recurring expenses
  Future<RecurringExpense> createRecurringExpense(
      CreateRecurringExpenseRequest req) async {
    try {
      final r = await _dio.post('/recurring-expenses', data: req.toJson());
      final data = r.data;
      if (data is! Map) throw ApiException('Unexpected response format');
      return RecurringExpense.fromJson(data.cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Create recurring expense failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<RecurringExpense>> listRecurringExpenses(String groupId,
      {int limit = 50, int offset = 0}) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio.get('/recurring-expenses', queryParameters: {
        'group_id': groupId,
        'limit': limit,
        'offset': offset
      });
      final data = r.data;
      if (data is! List) return [];
      return data
          .map((j) =>
              RecurringExpense.fromJson((j as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('List recurring expenses failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<RecurringExpense> getRecurringExpense(String id) async {
    try {
      final r = await _dio.get('/recurring-expenses/$id');
      final data = r.data;
      if (data is! Map) throw ApiException('Unexpected response format');
      return RecurringExpense.fromJson(data.cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Get recurring expense failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<RecurringExpense> updateRecurringExpense(
      String id, UpdateRecurringExpenseRequest req) async {
    try {
      final r = await _dio.patch('/recurring-expenses/$id', data: req.toJson());
      final data = r.data;
      if (data is! Map) throw ApiException('Unexpected response format');
      return RecurringExpense.fromJson(data.cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Update recurring expense failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> deleteRecurringExpense(String id) async {
    try {
      await _dio.delete('/recurring-expenses/$id');
    } on DioException catch (e) {
      _logger.e('Delete recurring expense failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  /// Fetches a live advisory exchange rate from → to.
  ///
  /// Returns the rate when the server has one, or null when the feature is
  /// disabled, the provider is unreachable, or any error occurs. The caller
  /// must treat null as "no rate available — let the user enter it manually."
  /// This method never throws; errors are swallowed and null is returned.
  Future<double?> fetchAdvisoryFxRate(String from, String to) async {
    try {
      final r = await _dio.get(
        '/fx/rate',
        queryParameters: {'from': from, 'to': to},
      );
      final data = r.data;
      if (data is! Map) return null;
      if (data['available'] != true) return null;
      final rate = data['rate'];
      if (rate is num && rate > 0) return rate.toDouble();
      return null;
    } catch (_) {
      // Any network / parse / auth error → degrade to manual entry.
      return null;
    }
  }
}
