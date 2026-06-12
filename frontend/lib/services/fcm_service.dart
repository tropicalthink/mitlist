import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'token_store.dart';

const _prefKey = 'fcm_token_registered';
const _prefDeviceTokenId = 'fcm_device_token_id';

/// Handles Firebase Cloud Messaging setup and device token registration.
///
/// Call [FcmService.init] once after the user is authenticated.
/// The service registers the FCM token with the backend so the server can
/// send push notifications to this device.
///
/// Subscribe to [FcmService.onForegroundMessage] to show in-app banners
/// for notifications that arrive while the app is open.
///
/// Prerequisites (one-time project setup):
///   Android — add google-services.json to android/app/
///   iOS     — add GoogleService-Info.plist to ios/Runner/ and enable
///             Push Notifications + Background Modes capabilities in Xcode.
class FcmService {
  static final Logger _log = Logger();
  static final TokenStore _tokenStore = SecureTokenStore();

  static final StreamController<RemoteMessage> _foregroundController =
      StreamController<RemoteMessage>.broadcast();

  static final StreamController<RemoteMessage> _tapController =
      StreamController<RemoteMessage>.broadcast();

  static StreamSubscription<String>? _tokenSub;
  static StreamSubscription<RemoteMessage>? _messageSub;
  static StreamSubscription<RemoteMessage>? _tapSub;

  /// Fires when a push notification is received while the app is in the foreground.
  static Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundController.stream;

  /// Fires when the user taps a notification while the app is in the background.
  /// For cold-start taps (app killed), use [checkInitialMessage] instead.
  static Stream<RemoteMessage> get onNotificationTap => _tapController.stream;

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

    // Cancel any existing subscriptions before re-registering to prevent
    // duplicate handlers stacking across logout/login cycles.
    await _tokenSub?.cancel();
    await _messageSub?.cancel();
    await _tapSub?.cancel();

    _tokenSub = messaging.onTokenRefresh.listen((newToken) {
      _registerToken(dio, newToken);
    });

    // Foreground messages — the OS won't show a heads-up automatically when
    // the app is open; emit on the stream so the UI can display a banner.
    _messageSub = FirebaseMessaging.onMessage.listen((message) {
      _foregroundController.add(message);
    });

    // Background-to-foreground taps — user tapped a notification while the
    // app was backgrounded (not killed).
    _tapSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _tapController.add(message);
    });
  }

  /// Cancels all active FCM stream subscriptions.
  ///
  /// Call during logout (alongside [unregisterToken]) so that no stale
  /// listeners remain active for the next login cycle.
  static Future<void> reset() async {
    await _tokenSub?.cancel();
    await _messageSub?.cancel();
    await _tapSub?.cancel();
    _tokenSub = null;
    _messageSub = null;
    _tapSub = null;
  }

  /// Returns the notification that launched the app from a killed state, or
  /// null if the app was opened normally.  Call after [init] completes.
  static Future<RemoteMessage?> checkInitialMessage() async {
    if (kIsWeb) return null;
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    return FirebaseMessaging.instance.getInitialMessage();
  }

  /// Removes the device token from the backend and clears it from local storage.
  ///
  /// Call during logout so the user stops receiving push notifications.
  static Future<void> unregisterToken(Dio dio) async {
    if (kIsWeb) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefDeviceTokenId);
    if (id == null) return;
    try {
      final accessToken = await _tokenStore.getAccessToken();
      if (accessToken == null) return;
      await dio.delete(
        '${ApiConfig.apiPrefix}/auth/device-tokens/$id',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } catch (e) {
      _log.w('FCM token unregister failed: $e');
    } finally {
      await prefs.remove(_prefKey);
      await prefs.remove(_prefDeviceTokenId);
    }
  }

  static Future<void> _registerToken(Dio dio, String token) async {
    final platform = Platform.isIOS ? 'ios' : 'android';

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    if (stored == token) return; // already registered this token

    try {
      final accessToken = await _tokenStore.getAccessToken();
      if (accessToken == null) return;

      final response = await dio.post(
        '${ApiConfig.apiPrefix}/auth/device-tokens',
        data: {'platform': platform, 'token': token},
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
        ),
      );
      await prefs.setString(_prefKey, token);
      final id = (response.data as Map<String, dynamic>?)?['id'] as String?;
      if (id != null) await prefs.setString(_prefDeviceTokenId, id);
      _log.i('FCM device token registered');
    } catch (e) {
      _log.w('FCM token registration failed: $e');
    }
  }
}
