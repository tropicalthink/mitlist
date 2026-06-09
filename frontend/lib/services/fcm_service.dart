import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

const _prefKey = 'fcm_token_registered';

/// Handles Firebase Cloud Messaging setup and device token registration.
///
/// Call [FcmService.init] once after the user is authenticated.
/// The service registers the FCM token with the backend so the server can
/// send push notifications to this device.
///
/// Prerequisites (one-time project setup):
///   Android — add google-services.json to android/app/
///   iOS     — add GoogleService-Info.plist to ios/Runner/ and enable
///             Push Notifications + Background Modes capabilities in Xcode.
class FcmService {
  static final Logger _log = Logger();

  /// Initialise Firebase and register the FCM device token with the backend.
  ///
  /// Safe to call multiple times; re-registers only when the token changes.
  static Future<void> init(Dio dio) async {
    if (kIsWeb) return; // web uses VAPID, not FCM
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      _log.w('Firebase init failed (no google-services.json?): $e');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      _log.i('Push permission denied');
      return;
    }

    final token = await messaging.getToken();
    if (token == null) {
      _log.w('FCM token is null');
      return;
    }

    await _registerToken(dio, token);

    messaging.onTokenRefresh.listen((newToken) {
      _registerToken(dio, newToken);
    });
  }

  static Future<void> _registerToken(Dio dio, String token) async {
    final platform = Platform.isIOS ? 'ios' : 'android';

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    if (stored == token) return; // already registered this token

    try {
      final accessToken = prefs.getString(ApiConfig.accessTokenKey);
      if (accessToken == null) return;

      await dio.post(
        '${ApiConfig.apiPrefix}/auth/device-tokens',
        data: {'platform': platform, 'token': token},
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
      await prefs.setString(_prefKey, token);
      _log.i('FCM device token registered');
    } catch (e) {
      _log.w('FCM token registration failed: $e');
    }
  }
}
