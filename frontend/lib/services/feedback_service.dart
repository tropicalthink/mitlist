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

  /// Submits private feedback that only the team sees.
  ///
  /// [sourcePage] is the route the user was on when they opened the feedback
  /// form; [previousPage] is the route before that (relevant when the form is
  /// reached via the account screen). Both help the team replicate the
  /// submitter's context.
  Future<void> submitFeatureRequest({
    required String text,
    FeatureBoardKind kind = FeatureBoardKind.feature,
    String? sourcePage,
    String? previousPage,
  }) async {
    final user = await _cachedUser();
    await _dio.post<void>(
      FeedbackConfig.intakePath,
      data: {
        'text': text,
        'kind': kind.toJson(),
        if (sourcePage != null && sourcePage.isNotEmpty)
          'sourcePage': sourcePage,
        if (user?['id'] != null) 'submitterRef': user!['id'],
        if (user?['email'] != null) 'submitterContact': user!['email'],
        'metadata': _metadata(previousPage: previousPage),
      },
    );
  }

  Future<List<FeatureBoardItem>> listFeatureBoard({
    FeatureBoardKind? kind,
    FeatureBoardSort sort = FeatureBoardSort.top,
  }) async {
    final user = await _requireCachedUser();
    final response = await _dio.get<Map<String, dynamic>>(
      FeedbackConfig.boardPath,
      queryParameters: {
        'sort': sort.toQuery(),
        if (kind != null) 'kind': kind.toJson(),
      },
      options: Options(headers: {'X-Submitter-Ref': user.id}),
    );
    final rawItems = response.data?['items'] as List<dynamic>? ?? const [];
    return rawItems
        .map((item) => FeatureBoardItem.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList(growable: false);
  }

  Future<FeatureBoardDetail> getFeatureBoardItem(String requestId) async {
    final user = await _requireCachedUser();
    final response = await _dio.get<Map<String, dynamic>>(
      '${FeedbackConfig.boardPath}/$requestId',
      options: Options(headers: {'X-Submitter-Ref': user.id}),
    );
    return FeatureBoardDetail.fromJson(response.data!);
  }

  Future<void> submitBoardFeature({
    required String title,
    String? description,
    FeatureBoardKind kind = FeatureBoardKind.feature,
    String? sourcePage,
  }) async {
    final user = await _requireCachedUser();
    await _dio.post<Map<String, dynamic>>(
      FeedbackConfig.boardPath,
      data: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'kind': kind.toJson(),
        'voterRef': user.id,
        if (user.email != null) 'submitterContact': user.email,
        if (sourcePage != null && sourcePage.isNotEmpty)
          'sourcePage': sourcePage,
        'metadata': _metadata(),
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

  /// Posts a public comment. Only the user's first name travels with it; the
  /// tracker stores a hash of the user id, never the id itself.
  Future<FeatureBoardComment> addBoardComment({
    required String requestId,
    required String body,
  }) async {
    final user = await _requireCachedUser();
    final response = await _dio.post<Map<String, dynamic>>(
      '${FeedbackConfig.boardPath}/$requestId/comments',
      data: {
        'body': body,
        'voterRef': user.id,
        if (user.firstName case final name? when name.isNotEmpty)
          'authorName': name,
      },
    );
    return FeatureBoardComment.fromJson(response.data!);
  }

  Map<String, dynamic> _metadata({String? previousPage}) {
    return {
      'appVersion': _appVersion,
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
      'locale': PlatformDispatcher.instance.locale.toString(),
      if (previousPage != null && previousPage.isNotEmpty)
        'previousPage': previousPage,
    };
  }

  Future<({String id, String? email, String? firstName})>
      _requireCachedUser() async {
    final user = await _cachedUser();
    final id = user?['id'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('A signed-in user is required for the feature board.');
    }
    return (
      id: id,
      email: user?['email'] as String?,
      firstName: (user?['first_name'] as String?)?.trim(),
    );
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
