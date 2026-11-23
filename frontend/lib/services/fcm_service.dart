import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'token_store.dart';

/// Handles Firebase Cloud Messaging setup and device token registration.
///
/// Call [FcmService.init] once after the user is authenticated. It wires the
/// message listeners and registers the device token with the backend right
/// away, whatever the notification permission says. It never shows the
/// system permission dialog: that is [requestPermission], which the app calls
/// at a moment of its choosing (after the user has done their first thing in
/// a household, see `PushPromptGate`) rather than on the first cold start.
///
/// Registering before permission is what keeps home screen widgets fresh:
/// the "household changed" widget refresh push is data-only (Android) or a
/// background push (iOS), and neither needs the user's permission to arrive.
/// Android issues an FCM token without POST_NOTIFICATIONS, and on iOS the
/// firebase_messaging plugin calls `registerForRemoteNotifications` at
/// launch, which yields an APNs (and so an FCM) token without alert
/// authorization. Visible notifications sent to a device that has not allowed
/// them are dropped by the OS, which is what the server already got for a
/// device it had no token for.
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

  static StreamSubscription<RemoteMessage>? _messageSub;
  static StreamSubscription<RemoteMessage>? _tapSub;

  static PushTokenRegistrar? _registrar;

  /// The registrar the service uses; built on first use against the real
  /// Firebase instance.
  static PushTokenRegistrar get _tokens => _registrar ??= PushTokenRegistrar(
        platform: Platform.isIOS ? 'ios' : 'android',
        fetchToken: () => FirebaseMessaging.instance.getToken(),
        tokenRefreshes: () => FirebaseMessaging.instance.onTokenRefresh,
        accessToken: _tokenStore.getAccessToken,
      );

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
  /// device token with the backend for the signed-in user.
  ///
  /// Never shows the permission dialog and does not depend on it. Safe to
  /// call multiple times; each call (one per sign-in) registers the current
  /// token once more, so a token that changed hands on a shared device, or
  /// that the server pruned, is put right. Returns true when the listeners
  /// were registered, so the caller can subscribe to the streams once.
  static Future<bool> init(Dio dio) async {
    if (!await ensureFirebaseCore()) return false;

    // Cancel any existing subscriptions before re-registering to prevent
    // duplicate handlers stacking across logout/login cycles.
    await _messageSub?.cancel();
    await _tapSub?.cancel();

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

    // Registration is best-effort and runs in the background: offline,
    // `getToken()` throws (SERVICE_NOT_AVAILABLE, or no APNs token yet), and
    // that must not keep the caller from attaching the foreground and tap
    // listeners. The registrar retries the APNs race and also registers
    // whatever token `onTokenRefresh` delivers later.
    unawaited(_tokens.start(dio).catchError((Object e) {
      _log.w('FCM token registration deferred (${e.runtimeType})');
    }));
    return true;
  }

  /// Shows the OS notification permission dialog.
  ///
  /// The device token is normally registered already (see [init]); when the
  /// user allows notifications it is registered here too in case [init]
  /// could not fetch it, which is a no-op when it already was.
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
      // Permission is the answer the caller needs; a token that cannot be
      // fetched offline is registered on the next launch.
      try {
        await _tokens.ensureRegistered(dio);
      } catch (e) {
        _log.w('FCM token registration deferred (${e.runtimeType})');
      }
    } else {
      _log.i('Push permission denied');
    }
    return settings.authorizationStatus;
  }

  /// Cancels all active FCM stream subscriptions.
  ///
  /// Call during logout (alongside [unregisterToken]) so that no stale
  /// listeners remain active for the next login cycle.
  static Future<void> reset() async {
    await _registrar?.stop();
    await _messageSub?.cancel();
    await _tapSub?.cancel();
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
    await PushTokenRegistrar.unregister(dio, log: _log);
  }
}

/// Keeps the backend's record of this install's FCM token current for the
/// signed-in user, independent of the notification permission.
///
/// [start] runs once per sign-in: it registers the current token and every
/// token `onTokenRefresh` delivers after it. [stop] runs at sign-out, before
/// [unregister] deletes the server row, so a late refresh cannot re-add it.
/// Every dependency is injected so the timing is testable without Firebase.
class PushTokenRegistrar {
  PushTokenRegistrar({
    required this.platform,
    required this.fetchToken,
    required this.tokenRefreshes,
    required this.accessToken,
    this.apnsRetryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 3),
      Duration(seconds: 10),
    ],
    Future<void> Function(Duration)? wait,
    Logger? log,
  })  : _wait = wait ?? Future<void>.delayed,
        _log = log ?? Logger();

  /// "ios" or "android", as the backend expects.
  final String platform;

  /// Reads the current FCM token (`FirebaseMessaging.getToken`).
  final Future<String?> Function() fetchToken;

  /// `FirebaseMessaging.onTokenRefresh`, read when [start] runs.
  final Stream<String> Function() tokenRefreshes;

  /// The signed-in user's access token; null means signed out.
  final Future<String?> Function() accessToken;

  /// How long to wait before fetching again while iOS has no APNs token yet
  /// (`apns-token-not-set`): the plugin asks for one at launch, and it
  /// usually lands within a second or two.
  final List<Duration> apnsRetryDelays;

  final Future<void> Function(Duration) _wait;
  final Logger _log;

  static const prefDeviceTokenId = 'fcm_device_token_id';

  /// Written by older builds to skip re-registering a known token. A
  /// persisted skip outlived sign-outs that did not run [unregister] (an
  /// expired session) and then kept the next account from ever getting the
  /// token, so it is only cleared now.
  static const legacyPrefRegisteredToken = 'fcm_token_registered';

  StreamSubscription<String>? _refreshSub;

  /// Bumped by [start] and [stop]; work begun under an older value belongs to
  /// a previous session and must not register anything.
  int _session = 0;

  /// The token registered (or being registered) in this session.
  String? _registered;

  /// Begins a session for the signed-in user: registers the current token
  /// and then each refreshed one.
  Future<void> start(Dio dio) async {
    await _refreshSub?.cancel();
    final session = ++_session;
    _registered = null;
    _refreshSub = tokenRefreshes().listen((token) {
      unawaited(_register(dio, token, session));
    });
    await _registerCurrent(dio, session);
  }

  /// Registers the current token if this session has not already.
  Future<void> ensureRegistered(Dio dio) => _registerCurrent(dio, _session);

  /// Ends the session: no refresh or pending fetch registers after this.
  Future<void> stop() async {
    _session++;
    _registered = null;
    await _refreshSub?.cancel();
    _refreshSub = null;
  }

  Future<void> _registerCurrent(Dio dio, int session) async {
    for (var attempt = 0;; attempt++) {
      try {
        final token = await fetchToken();
        if (token == null) {
          _log.w('FCM token is null');
          return;
        }
        await _register(dio, token, session);
        return;
      } on FirebaseException catch (e) {
        if (e.code != 'apns-token-not-set' ||
            attempt >= apnsRetryDelays.length) {
          rethrow;
        }
        await _wait(apnsRetryDelays[attempt]);
        if (session != _session) return;
      }
    }
  }

  Future<void> _register(Dio dio, String token, int session) async {
    if (session != _session || _registered == token) return;
    final access = await accessToken();
    if (access == null || session != _session) return;
    _registered = token;
    try {
      final response = await dio.post<dynamic>(
        '/auth/device-tokens',
        data: {'platform': platform, 'token': token},
        options: Options(headers: {'Authorization': 'Bearer $access'}),
      );
      final data = response.data;
      final id = data is Map ? data['id'] as String? : null;
      if (session != _session) {
        // Signed out while this was in flight: the sign-out cleanup could not
        // know about this row, so take it back with the same credentials.
        if (id != null) {
          try {
            await dio.delete<void>(
              '/auth/device-tokens/$id',
              options: Options(headers: {'Authorization': 'Bearer $access'}),
            );
          } catch (_) {
            // The next sign-in on this device reassigns the token anyway.
          }
        }
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (id != null) await prefs.setString(prefDeviceTokenId, id);
      _log.i('FCM device token registered');
    } catch (e) {
      if (_registered == token) _registered = null;
      _log.w('FCM token registration failed (${e.runtimeType})');
    }
  }

  /// Deletes this install's token row on the server and forgets it locally.
  ///
  /// [dio] is the authenticated cleanup client logout supplies, so this works
  /// after the normal auth interceptor is detached.
  static Future<void> unregister(Dio dio, {Logger? log}) async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(prefDeviceTokenId);
    try {
      if (id != null) await dio.delete<void>('/auth/device-tokens/$id');
    } catch (e) {
      (log ?? Logger()).w('FCM token unregister failed (${e.runtimeType})');
    } finally {
      await prefs.remove(legacyPrefRegisteredToken);
      await prefs.remove(prefDeviceTokenId);
    }
  }
}
