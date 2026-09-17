import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/notification_models.dart';
import '../models/push_subscription_models.dart';
import 'api_client.dart';

class NotificationService {
  final Dio _dio;
  final Logger _logger = Logger();

  NotificationService._(this._dio);

  static Future<NotificationService> create([Ref? ref]) async {
    final dio = resolveDio(ref);
    return NotificationService._(dio);
  }

  Future<List<NotificationModel>> listNotifications(
      {int limit = 50,
      int offset = 0,
      DateTime? beforeCreatedAt,
      String? beforeId}) async {
    try {
      final query = <String, dynamic>{'limit': limit};
      if (beforeCreatedAt != null && beforeId != null) {
        query['before_created_at'] = beforeCreatedAt.toUtc().toIso8601String();
        query['before_id'] = beforeId;
      } else {
        query['offset'] = offset;
      }
      final r = await _dio.get('/notifications', queryParameters: query);
      final data = (r.data as List).cast<dynamic>();
      return data
          .map((e) =>
              NotificationModel.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      _logger.e('List notifications failed: ${e.response?.data}');
      rethrow;
    }
  }

  Future<int> countUnreadNotifications() async {
    final r = await _dio.get('/notifications/unread-count');
    return (r.data as Map<String, dynamic>)['count'] as int? ?? 0;
  }

  Future<NotificationModel> getNotification(String id) async {
    final r = await _dio.get('/notifications/$id');
    return NotificationModel.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<void> markAsRead(String id) async {
    await _dio.patch('/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await _dio.patch('/notifications/read-all');
  }

  Future<void> deleteNotification(String id) async {
    await _dio.delete('/notifications/$id');
  }

  Future<List<NotificationPreferenceModel>> getPreferences() async {
    final r = await _dio.get('/notifications/preferences');
    final data = (r.data as List).cast<dynamic>();
    return data
        .map((e) => NotificationPreferenceModel.fromJson(
            (e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<NotificationPreferenceModel> getGroupPreference(String groupId) async {
    final r = await _dio.get('/notifications/preferences',
        queryParameters: {'group_id': groupId});
    return NotificationPreferenceModel.fromJson(
        (r.data as Map).cast<String, dynamic>());
  }

  Future<void> updatePreference(NotificationPreferenceModel pref) async {
    await _dio.patch('/notifications/preferences', data: pref.toJson());
  }

  /// Releases every server-side notification digest this user has pending
  /// (list items, meal plan edits, expenses) so housemates get their one
  /// summary as soon as the editing session ends. Sent when the app goes to
  /// the background, which ends whatever screen was open. Fire-and-forget:
  /// on failure the server's fallback window delivers a little later.
  Future<void> flushAllDigests() async {
    try {
      await _dio.post('/notifications/flush');
    } on DioException catch (e) {
      _logger.w('Flush all notification digests failed: ${e.response?.data}');
    }
  }

  // ---------------------------------------------------------------------------
  // Push subscriptions (web push)
  // ---------------------------------------------------------------------------

  Future<PushSubscriptionModel> createPushSubscription({
    required String endpoint,
    required String p256dh,
    required String auth,
  }) async {
    final r = await _dio.post(
      '/auth/push-subscriptions',
      data: {'endpoint': endpoint, 'p256dh': p256dh, 'auth': auth},
    );
    return PushSubscriptionModel.fromJson(
        (r.data as Map).cast<String, dynamic>());
  }

  Future<List<PushSubscriptionModel>> listPushSubscriptions() async {
    final r = await _dio.get('/auth/push-subscriptions');
    final data = (r.data as List).cast<dynamic>();
    return data
        .map((e) =>
            PushSubscriptionModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> deletePushSubscription(String id) async {
    await _dio.delete('/auth/push-subscriptions/$id');
  }
}
