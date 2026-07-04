import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/chore_models.dart';
import 'api_client.dart';
import 'api_error_mapper.dart';
import 'group_id_validator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChoreService {
  final Dio _dio;
  final Logger _logger = Logger();
  ChoreService._(this._dio);
  static Future<ChoreService> create([Ref? ref]) async {
    final dio = resolveDio(ref);
    return ChoreService._(dio);
  }

  Future<Chore> createChore(CreateChoreRequest req) async {
    try {
      final r = await _dio.post('/chores', data: req.toJson());
      return Chore.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Create chore failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<Chore>> listChores(String groupId,
      {int limit = 50, int offset = 0}) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio.get('/chores', queryParameters: {
        'group_id': groupId,
        'limit': limit,
        'offset': offset
      });
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => Chore.fromJson(j)).toList();
    } on DioException catch (e) {
      _logger.e('List chores failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<CurrentChore>> listCurrentChores(
    String groupId, {
    int limit = 100,
    int offset = 0,
    int dueSoonDays = 7,
  }) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio.get('/chores/current', queryParameters: {
        'group_id': groupId,
        'limit': limit,
        'offset': offset,
        'due_soon_days': dueSoonDays,
      });
      final data = r.data;
      if (data is! List) return [];
      return data
          .map((j) => CurrentChore.fromJson((j as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('List current chores failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<ChoreTemplate>> listChoreTemplates(
    String groupId, {
    int limit = 50,
    int offset = 0,
  }) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio.get('/chore-templates', queryParameters: {
        'group_id': groupId,
        'limit': limit,
        'offset': offset,
      });
      final data = r.data;
      if (data is! List) return [];
      return data
          .map(
              (j) => ChoreTemplate.fromJson((j as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('List chore templates failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<ChoreTemplate> createChoreTemplate(
      CreateChoreTemplateRequest req) async {
    try {
      final r = await _dio.post('/chore-templates', data: req.toJson());
      return ChoreTemplate.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Create chore template failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<ChoreTemplate> updateChoreTemplate(
      String id, UpdateChoreTemplateRequest req) async {
    try {
      final r = await _dio.patch('/chore-templates/$id', data: req.toJson());
      return ChoreTemplate.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Update chore template failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> deleteChoreTemplate(String id) async {
    try {
      await _dio.delete('/chore-templates/$id');
    } on DioException catch (e) {
      _logger.e('Delete chore template failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<ChoreLoadEntry>> getChoreLoad(
    String groupId, {
    int days = 30,
  }) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio.get('/chores/load', queryParameters: {
        'group_id': groupId,
        'days': days,
      });
      final data = r.data;
      if (data is! List) return [];
      return data
          .map((j) =>
              ChoreLoadEntry.fromJson((j as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('Get chore load failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<Chore> getChore(String id) async {
    try {
      final r = await _dio.get('/chores/$id');
      return Chore.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Get chore failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<ChoreDetails> getChoreDetails(String id, {int dueSoonDays = 7}) async {
    try {
      final r = await _dio.get(
        '/chores/$id/details',
        queryParameters: {'due_soon_days': dueSoonDays},
      );
      return ChoreDetails.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Get chore details failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<Chore> updateChore(String id, UpdateChoreRequest req) async {
    try {
      final r = await _dio.patch('/chores/$id', data: req.toJson());
      return Chore.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Update chore failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<ChoreAssignment>> listAssignments(String choreId,
      {int limit = 50, int offset = 0}) async {
    try {
      final r = await _dio.get(
        '/chores/$choreId/assignments',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final data = r.data;
      if (data is! List) return [];
      return data
          .map((j) =>
              ChoreAssignment.fromJson((j as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('List assignments failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> deleteChore(String id) async {
    try {
      await _dio.delete('/chores/$id');
    } on DioException catch (e) {
      _logger.e('Delete chore failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> completeChore(String id, {String? notes}) async {
    try {
      await _dio.post('/chores/$id/complete',
          data: CompleteChoreRequest(notes: notes).toJson());
    } on DioException catch (e) {
      _logger.e('Complete chore failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> rotateChore(String id) async {
    try {
      await _dio.post('/chores/$id/rotate');
    } on DioException catch (e) {
      _logger.e('Rotate chore failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> skipChore(String id, {String? skipReason}) async {
    try {
      await _dio.post('/chores/$id/skip',
          data: SkipChoreRequest(skipReason: skipReason).toJson());
    } on DioException catch (e) {
      _logger.e('Skip chore failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> rescheduleChore(
    String id, {
    DateTime? dueDate,
    String? assigneeId,
  }) async {
    try {
      await _dio.patch(
        '/chores/$id/pending',
        data: RescheduleChoreRequest(
          dueDate: dueDate,
          assigneeId: assigneeId,
        ).toJson(),
      );
    } on DioException catch (e) {
      _logger.e('Reschedule chore failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> undoLastChoreExecution(String id) async {
    try {
      await _dio.post('/chores/$id/undo');
    } on DioException catch (e) {
      _logger.e('Undo chore execution failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<ChoreSubtask>> listSubtasks(String choreId) async {
    try {
      final r = await _dio.get('/chores/$choreId/subtasks');
      final data = r.data;
      if (data is! List) return [];
      return data
          .map((j) => ChoreSubtask.fromJson((j as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('List subtasks failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<ChoreSubtask> createSubtask(String choreId, String title) async {
    try {
      final r = await _dio.post('/chores/$choreId/subtasks',
          data: CreateSubtaskRequest(title: title).toJson());
      return ChoreSubtask.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Create subtask failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<ChoreSubtask> updateSubtask(
    String subtaskId, {
    String? title,
    bool? completed,
    int? position,
  }) async {
    try {
      final r = await _dio.patch('/chores/subtasks/$subtaskId',
          data: UpdateSubtaskRequest(
            title: title,
            completed: completed,
            position: position,
          ).toJson());
      return ChoreSubtask.fromJson((r.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Update subtask failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> deleteSubtask(String subtaskId) async {
    try {
      await _dio.delete('/chores/subtasks/$subtaskId');
    } on DioException catch (e) {
      _logger.e('Delete subtask failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> reorderSubtasks(String choreId, List<String> subtaskIds) async {
    try {
      await _dio.put('/chores/$choreId/subtasks/reorder',
          data: ReorderSubtasksRequest(subtaskIds: subtaskIds).toJson());
    } on DioException catch (e) {
      _logger.e('Reorder subtasks failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> addSuppliesToList(String choreId, String listId) async {
    try {
      await _dio.post('/chores/$choreId/add-supplies-to-list',
          data: AddSuppliesToListRequest(listId: listId).toJson());
    } on DioException catch (e) {
      _logger.e('Add supplies to list failed: ${e.response?.data}');
      throw apiException(e);
    }
  }
}
