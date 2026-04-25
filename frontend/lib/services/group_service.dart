import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/group_models.dart';
import 'api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for managing groups/households.
class GroupService {
  final Dio _dio;
  final Logger _logger = Logger();

  GroupService._(this._dio);

  /// Creates an instance of GroupService.
  static Future<GroupService> create([Ref? ref]) async {
    final dio = createApiClient(ref);
    return GroupService._(dio);
  }

  /// Creates a new group.
  Future<Group> createGroup(CreateGroupRequest request) async {
    try {
      final response = await _dio.post(
        '/groups',
        data: request.toJson(),
      );
      return Group.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Create group failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Lists all groups for the current user.
  Future<List<Group>> listGroups({int limit = 50, int offset = 0}) async {
    try {
      final response = await _dio.get(
        '/groups',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );
      final data = response.data;
      if (data is! List) return [];
      return data.map((json) => Group.fromJson(json)).toList();
    } on DioException catch (e) {
      _logger.e('List groups failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Gets a specific group by ID.
  Future<Group> getGroup(String groupId) async {
    try {
      final response = await _dio.get('/groups/$groupId');
      return Group.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Get group failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Updates a group.
  Future<Group> updateGroup(String groupId, UpdateGroupRequest request) async {
    try {
      final response = await _dio.patch(
        '/groups/$groupId',
        data: request.toJson(),
      );
      return Group.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Update group failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Deletes a group.
  Future<void> deleteGroup(String groupId) async {
    try {
      await _dio.delete('/groups/$groupId');
    } on DioException catch (e) {
      _logger.e('Delete group failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Joins a group with an invite code.
  Future<Group> joinGroup(JoinGroupRequest request) async {
    try {
      final response = await _dio.post(
        '/groups/join',
        data: request.toJson(),
      );
      return Group.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Join group failed: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// Handles Dio errors and converts them to user-friendly messages.
  Exception _handleError(DioException e) {
    if (e.response?.statusCode == 400) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data.containsKey('error')) {
        final error = data['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'] ?? 'Invalid request';
          return Exception(message);
        }
      }
      return Exception('Invalid request');
    } else if (e.response?.statusCode == 401) {
      return Exception('Invalid credentials or session expired');
    } else if (e.response?.statusCode == 403) {
      return Exception('Access denied');
    } else if (e.response?.statusCode == 404) {
      return Exception('Group not found');
    } else if (e.response?.statusCode == 409) {
      return Exception('Group already exists');
    } else if (e.response?.statusCode == 422) {
      return Exception('Validation error');
    } else if (e.response?.statusCode == 429) {
      return Exception('Too many requests. Please try again later.');
    } else if (e.response?.statusCode == 500) {
      return Exception('Server error. Please try again later.');
    } else if (e.response?.statusCode == 503) {
      return Exception('Service unavailable. Please try again later.');
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return Exception('Request timeout. Please check your connection.');
    } else if (e.type == DioExceptionType.connectionError) {
      return Exception('Network error. Please check your connection.');
    } else {
      return Exception('An unexpected error occurred');
    }
  }
}
