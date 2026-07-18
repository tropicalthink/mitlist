import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/feedback_config.dart';

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
                connectTimeout: ApiConfig.requestTimeout,
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
