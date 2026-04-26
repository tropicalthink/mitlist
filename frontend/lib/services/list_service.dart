import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/list_models.dart';
import '../models/list_item_photo_models.dart';
import 'api_client.dart';
import 'group_id_validator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ListService {
  final Dio _dio;
  final Logger _logger = Logger();
  ListService._(this._dio);
  static Future<ListService> create([Ref? ref]) async {
    final dio = createApiClient(ref);
    return ListService._(dio);
  }

  Future<ItemList> createList(CreateListRequest req) async {
    try {
      final r = await _dio.post('/lists', data: req.toJson());
      return ItemList.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Create list failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<List<ItemList>> listLists(String groupId,
      {int limit = 50, int offset = 0}) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio.get('/lists', queryParameters: {
        'group_id': groupId,
        'limit': limit,
        'offset': offset
      });
      final data = r.data;
      if (data is! List) return [];
      return data.map((j) => ItemList.fromJson(j)).toList();
    } on DioException catch (e) {
      _logger.e('List lists failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<ItemList> getList(String id) async {
    try {
      final r = await _dio.get('/lists/$id');
      return ItemList.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Get list failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<void> deleteList(String id) async {
    try {
      await _dio.delete('/lists/$id');
    } on DioException catch (e) {
      _logger.e('Delete list failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<ItemList> updateList(String id, UpdateListRequest req) async {
    try {
      final r = await _dio.patch('/lists/$id', data: req.toJson());
      return ItemList.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Update list failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<ListItem> createItem(String listId, CreateListItemRequest req) async {
    try {
      final r = await _dio.post('/lists/$listId/items', data: req.toJson());
      return ListItem.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Create item failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<List<ListItem>> listItems(String listId,
      {int limit = 50, int offset = 0}) async {
    try {
      final r = await _dio.get('/lists/$listId/items',
          queryParameters: {'limit': limit, 'offset': offset});
      return _parseItemsResponse(r.data);
    } on DioException catch (e) {
      _logger.e('List items failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<ListItem> updateItem(
      String listId, String itemId, UpdateListItemRequest req) async {
    try {
      final r =
          await _dio.patch('/lists/$listId/items/$itemId', data: req.toJson());
      return ListItem.fromJson(r.data);
    } on DioException catch (e) {
      _logger.e('Update item failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<void> deleteItem(String listId, String itemId) async {
    try {
      await _dio.delete('/lists/$listId/items/$itemId');
    } on DioException catch (e) {
      _logger.e('Delete item failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<void> reorderItems(String listId, ReorderItemsRequest req) async {
    try {
      await _dio.post('/lists/$listId/reorder', data: req.toJson());
    } on DioException catch (e) {
      _logger.e('Reorder items failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<List<ListItemPhoto>> listItemPhotos({
    required String groupId,
    required String itemId,
  }) async {
    ensureValidGroupId(groupId);
    try {
      final r = await _dio.get(
        '/lists/items/$itemId/photos',
        queryParameters: {'group_id': groupId},
      );
      final data = r.data;
      if (data is! List) return [];
      return data
          .map((e) =>
              ListItemPhoto.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('List item photos failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<void> attachItemPhoto({
    required String groupId,
    required String itemId,
    required String attachmentId,
  }) async {
    ensureValidGroupId(groupId);
    try {
      await _dio.post(
        '/lists/items/$itemId/photos',
        data: {'group_id': groupId, 'attachment_id': attachmentId},
      );
    } on DioException catch (e) {
      _logger.e('Attach item photo failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  Future<void> detachItemPhoto({
    required String groupId,
    required String itemId,
    required String attachmentId,
  }) async {
    ensureValidGroupId(groupId);
    try {
      await _dio.delete(
        '/lists/items/$itemId/photos/$attachmentId',
        queryParameters: {'group_id': groupId},
      );
    } on DioException catch (e) {
      _logger.e('Detach item photo failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  static List<ListItem> _parseItemsResponse(dynamic data) {
    if (data is List) {
      return data.map((dynamic e) {
        final m = Map<String, dynamic>.from(e as Map);
        return ListItem.fromJson(m);
      }).toList();
    }
    if (data is Map<String, dynamic>) {
      final raw = data['items'] ?? data['data'];
      if (raw is List) {
        return raw.map((dynamic e) {
          final m = Map<String, dynamic>.from(e as Map);
          return ListItem.fromJson(m);
        }).toList();
      }
    }
    return [];
  }

  Exception _handleError(DioException e) {
    if (e.response?.statusCode == 401) return Exception('Session expired');
    if (e.response?.statusCode == 403) return Exception('Access denied');
    if (e.response?.statusCode == 404) return Exception('Not found');
    if (e.type == DioExceptionType.connectionError) {
      return Exception('Network error');
    }
    return Exception('An error occurred');
  }
}
