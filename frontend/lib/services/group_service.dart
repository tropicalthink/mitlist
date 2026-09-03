import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../models/group_models.dart';
import 'api_client.dart';
import 'api_error_mapper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for managing groups/households.
class GroupService {
  final Dio _dio;
  final Logger _logger = Logger();

  GroupService._(this._dio);

  /// Creates an instance of GroupService.
  static Future<GroupService> create([Ref? ref]) async {
    final dio = resolveDio(ref);
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
      throw apiException(e);
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
      throw apiException(e);
    }
  }

  /// Gets a specific group by ID.
  Future<Group> getGroup(String groupId) async {
    try {
      final response = await _dio.get('/groups/$groupId');
      return Group.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Get group failed: ${e.response?.data}');
      throw apiException(e);
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
      throw apiException(e);
    }
  }

  /// Deletes a group.
  Future<void> deleteGroup(String groupId) async {
    try {
      await _dio.delete('/groups/$groupId');
    } on DioException catch (e) {
      _logger.e('Delete group failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  /// Describes the household behind an invite code without joining it, so
  /// the accept page can show what the user is saying yes to.
  Future<InvitePreview> previewInvite(String code) async {
    try {
      final response = await _dio.get(
        '/groups/invites/${Uri.encodeComponent(code.trim().toUpperCase())}',
      );
      return InvitePreview.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Preview invite failed: ${e.response?.data}');
      throw apiException(e);
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
      throw apiException(e);
    }
  }

  Future<GroupInvite> inviteMember(
      String groupId, InviteMemberRequest request) async {
    try {
      final response =
          await _dio.post('/groups/$groupId/members', data: request.toJson());
      return GroupInvite.fromJson(
          (response.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      _logger.e('Invite member failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<GroupMemberProfile>> listMembers(String groupId) async {
    try {
      final response = await _dio.get('/groups/$groupId/members');
      final data = response.data;
      if (data is! List) return [];
      return data
          .map((json) => GroupMemberProfile.fromJson(
              (json as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('List members failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> removeMember(String groupId, String userId) async {
    try {
      await _dio.delete('/groups/$groupId/members/$userId');
    } on DioException catch (e) {
      _logger.e('Remove member failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> updateMemberRole(
      String groupId, String userId, UpdateMemberRoleRequest request) async {
    try {
      await _dio.patch('/groups/$groupId/members/$userId',
          data: request.toJson());
    } on DioException catch (e) {
      _logger.e('Update member role failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<List<PendingClaim>> listPendingClaims(String groupId) async {
    try {
      final response = await _dio.get('/groups/$groupId/pending-claims');
      final data = response.data;
      if (data is! List) return [];
      return data
          .map((json) =>
              PendingClaim.fromJson((json as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('List pending claims failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> approveClaim(String groupId, String claimId) async {
    try {
      await _dio.post('/groups/$groupId/pending-claims/$claimId/approve');
    } on DioException catch (e) {
      _logger.e('Approve claim failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  Future<void> rejectClaim(String groupId, String claimId) async {
    try {
      await _dio.post('/groups/$groupId/pending-claims/$claimId/reject');
    } on DioException catch (e) {
      _logger.e('Reject claim failed: ${e.response?.data}');
      throw apiException(e);
    }
  }
}
