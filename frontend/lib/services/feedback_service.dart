import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/feedback_config.dart';
import '../models/feature_board_models.dart';

const String _appVersion = '1.0.0';

/// Sends feature requests to the studio's request tracker (reqtrack).
///
/// Uses its own [Dio] instance: requests go to a different host than the
/// mitlist API and must carry the intake app key, never the user's Bearer
/// token.
class FeedbackService {
  FeedbackService([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: FeedbackConfig.baseUrl,
                connectTimeout: ApiConfig.connectTimeout,
                receiveTimeout: ApiConfig.requestTimeout,
                sendTimeout: ApiConfig.requestTimeout,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                  'X-App-Key': FeedbackConfig.appKey,
                },
              ),
            );

  final Dio _dio;

  /// Submits a feature request.
  ///
  /// [sourcePage] is the route the user was on when they opened the feedback
  /// form; [previousPage] is the route before that (relevant when the form is
  /// reached via the account screen). Both help the team replicate the
  /// submitter's context.
  Future<void> submitFeatureRequest({
    required String text,
    String? sourcePage,
    String? previousPage,
  }) async {
    final user = await _cachedUser();
    await _dio.post<void>(
      FeedbackConfig.intakePath,
      data: {
        'text': text,
        if (sourcePage != null && sourcePage.isNotEmpty)
          'sourcePage': sourcePage,
        if (user?['id'] != null) 'submitterRef': user!['id'],
        if (user?['email'] != null) 'submitterContact': user!['email'],
        'metadata': {
          'appVersion': _appVersion,
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
          'locale': PlatformDispatcher.instance.locale.toString(),
          if (previousPage != null && previousPage.isNotEmpty)
            'previousPage': previousPage,
        },
      },
    );
  }

  Future<List<FeatureBoardItem>> listFeatureBoard() async {
    final user = await _requireCachedUser();
    final response = await _dio.get<Map<String, dynamic>>(
      FeedbackConfig.boardPath,
      options: Options(headers: {'X-Submitter-Ref': user.id}),
    );
    final rawItems = response.data?['items'] as List<dynamic>? ?? const [];
    return rawItems
        .map((item) => FeatureBoardItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
  }

  Future<void> submitBoardFeature({
    required String title,
    String? description,
    String? sourcePage,
  }) async {
    final user = await _requireCachedUser();
    await _dio.post<Map<String, dynamic>>(
      FeedbackConfig.boardPath,
      data: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'voterRef': user.id,
        if (user.email != null) 'submitterContact': user.email,
        if (sourcePage != null && sourcePage.isNotEmpty)
          'sourcePage': sourcePage,
        'metadata': {
          'appVersion': _appVersion,
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
          'locale': PlatformDispatcher.instance.locale.toString(),
        },
      },
    );
  }

  Future<FeatureBoardVote> upvoteBoardFeature(String requestId) async {
    final user = await _requireCachedUser();
    final response = await _dio.put<Map<String, dynamic>>(
      '${FeedbackConfig.boardPath}/$requestId/upvote',
      data: {'voterRef': user.id},
    );
    return FeatureBoardVote.fromJson(response.data!);
  }

  Future<({String id, String? email})> _requireCachedUser() async {
    final user = await _cachedUser();
    final id = user?['id'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('A signed-in user is required for the feature board.');
    }
    return (id: id, email: user?['email'] as String?);
  }

  Future<Map<String, dynamic>?> _cachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(ApiConfig.userDataKey);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

final feedbackServiceProvider =
    Provider<FeedbackService>((ref) => FeedbackService());
