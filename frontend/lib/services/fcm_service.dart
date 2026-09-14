import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'token_store.dart';

const _prefKey = 'fcm_token_registered';
const _prefDeviceTokenId = 'fcm_device_token_id';

/// Handles Firebase Cloud Messaging setup and device token registration.
///
/// Call [FcmService.init] once after the user is authenticated. It wires the
/// message listeners and, when the OS permission is already granted,
/// registers the device token with the backend. It never shows the system
/// permission dialog: that is [requestPermission], which the app calls at a
/// moment of its choosing (after the user has done their first thing in a
/// household, see `PushPromptGate`) rather than on the first cold start.
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
  static final TokenStore _tokenStore = SecureTokenStore.shared;

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

  /// FCM is a mobile-only transport; web uses VAPID, desktop has no push.
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Ensures the default Firebase app exists. Safe to call multiple times.
  ///
  /// Returns false when Firebase config is missing (e.g. no google-services.json
  /// in a local dev build). Call from [main] before registering background handlers.
  static Future<bool> ensureFirebaseCore() async {
    if (!isSupported) return false;
    if (Firebase.apps.isNotEmpty) return true;
    try {
      await Firebase.initializeApp();
      return true;
    } catch (e) {
      _log.w('Firebase init failed (no google-services.json?): $e');
      return false;
    }
  }

  static bool _isGranted(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  /// Whether this device may show notifications, read without prompting.
  ///
  /// Android 12 and older have no runtime permission and report authorized.
  static Future<bool> hasPermission() async {
    if (!isSupported || Firebase.apps.isEmpty) return false;
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      return _isGranted(settings.authorizationStatus);
    } catch (e) {
      _log.w('FCM getNotificationSettings failed: $e');
      return false;
    }
  }

  /// Initialise Firebase, wire the message listeners, and register the FCM
  /// device token with the backend when the OS permission is already granted.
  ///
  /// Never shows the permission dialog. Safe to call multiple times;
  /// re-registers only when the token changes. Returns true when the
  /// listeners were registered, whether or not permission is granted, so the
  /// caller can subscribe to the streams once and have them start delivering
  /// as soon as [requestPermission] succeeds later.
  static Future<bool> init(Dio dio) async {
    if (!await ensureFirebaseCore()) return false;

    final messaging = FirebaseMessaging.instance;

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

    final settings = await messaging.getNotificationSettings();
    if (_isGranted(settings.authorizationStatus)) {
      await _registerCurrentToken(dio, messaging);
    } else {
      _log.i('Push permission not granted yet; token registration deferred');
    }
    return true;
  }

  /// Shows the OS notification permission dialog and, when the user allows
  /// it, registers the device token with the backend.
  ///
  /// On Android 13+ the system stops showing the dialog after two refusals
  /// and this returns [AuthorizationStatus.denied] at once; the caller should
  /// then point the user at the phone's settings.
  static Future<AuthorizationStatus> requestPermission(Dio dio) async {
    if (!await ensureFirebaseCore()) return AuthorizationStatus.notDetermined;

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (_isGranted(settings.authorizationStatus)) {
      await _registerCurrentToken(dio, messaging);
    } else {
      _log.i('Push permission denied');
    }
    return settings.authorizationStatus;
  }

  static Future<void> _registerCurrentToken(
    Dio dio,
    FirebaseMessaging messaging,
  ) async {
    final token = await messaging.getToken();
    if (token == null) {
      _log.w('FCM token is null');
      return;
    }
    await _registerToken(dio, token);
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
    if (!isSupported) return null;
    if (Firebase.apps.isEmpty) return null;
    try {
      return await FirebaseMessaging.instance.getInitialMessage();
    } catch (e) {
      _log.w('FCM getInitialMessage failed: $e');
      return null;
    }
  }

  /// Removes the device token from the backend and clears it from local storage.
  ///
  /// Call during logout so the user stops receiving push notifications.
  static Future<void> unregisterToken(Dio dio) async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefDeviceTokenId);
    try {
      if (id != null) {
        // The caller supplies an authenticated cleanup client so logout can
        // unregister even after the normal auth interceptor is detached.
        await dio.delete('/auth/device-tokens/$id');
      }
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
        '/auth/device-tokens',
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
