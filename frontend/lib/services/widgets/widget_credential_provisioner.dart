import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../config/api_config.dart';
import 'widget_bridge.dart';

/// Keeps a widget credential in native storage while the app is signed in
/// (plans/047, D5 and C3).
///
/// Widgets, Siri and the quick add call the API with this narrow, device-bound
/// credential instead of the app's session: a second process refreshing the
/// session would replay its refresh token and sign the person out. The app
/// issues one per install and renews it while it is in the foreground:
/// - when it is older than [renewAfter] (it lives 90 days on the server);
/// - when the account, server or set of households changed, since a
///   credential only covers the households it was issued for;
/// - when a widget reported a 401, or native storage lost it (a restore to a
///   new device cannot read the Keychain/Keystore item).
class WidgetCredentialProvisioner {
  WidgetCredentialProvisioner({
    required Dio dio,
    required WidgetBridge bridge,
    DateTime Function()? now,
  })  : _dio = dio,
        _bridge = bridge,
        _now = now ?? DateTime.now;

  static const deviceIdKey = 'widget_device_id';
  static const issuedAtKey = 'widget_credential_issued_at';
  static const scopeKey = 'widget_credential_scope';
  static const renewAfter = Duration(days: 7);

  final Dio _dio;
  final WidgetBridge _bridge;
  final DateTime Function() _now;
  Future<bool>? _inFlight;

  /// Issues or renews the credential when needed. Returns whether it issued
  /// one. Network failures propagate; callers treat them as "try later".
  Future<bool> ensure({
    required String userId,
    required Iterable<String> householdIds,
  }) {
    return _inFlight ??=
        _ensure(userId, householdIds).whenComplete(() => _inFlight = null);
  }

  Future<bool> _ensure(String userId, Iterable<String> householdIds) async {
    if (!_bridge.isSupported) return false;
    final prefs = await SharedPreferences.getInstance();
    final deviceId = installId(prefs);
    final scope = ([
      userId,
      ApiConfig.baseUrl,
      ...(householdIds.toSet().toList()..sort()),
    ]).join('|');

    // Both flags are read every time: consuming the auth failure clears it.
    final authFailed = await _bridge.consumeAuthFailure();
    final stored = await _bridge.hasCredential();
    final issuedAt = prefs.getInt(issuedAtKey);
    final fresh = issuedAt != null &&
        _now().difference(DateTime.fromMillisecondsSinceEpoch(issuedAt)) <
            renewAfter;
    if (!authFailed && stored && fresh && prefs.getString(scopeKey) == scope) {
      return false;
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/widget-credential',
      data: {'device_id': deviceId},
    );
    final data = response.data ?? const {};
    final token = data['token'];
    if (token is! String || token.isEmpty) {
      throw StateError('widget credential response without a token');
    }
    await _bridge.setCredential({
      'token': token,
      'expires_at': data['expires_at'],
      'api_base_url': '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
      'user_id': userId,
      'device_id': deviceId,
    });
    await prefs.setInt(issuedAtKey, _now().millisecondsSinceEpoch);
    await prefs.setString(scopeKey, scope);
    return true;
  }

  /// Whether this install holds a credential issued to [userId]. Ops in the
  /// native queue were made with that credential, so only then do they
  /// belong to the signed-in person.
  static Future<bool> issuedFor(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(scopeKey)?.startsWith('$userId|') ?? false;
  }

  /// This install's id: random, kept in shared preferences.
  static String installId(SharedPreferences prefs) {
    final existing = prefs.getString(deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = const Uuid().v4();
    prefs.setString(deviceIdKey, created);
    return created;
  }

  /// Sign-out: revokes this install's credential on the server with [dio],
  /// which must still carry the session, and forgets the local bookkeeping.
  /// Native storage is wiped separately ([WidgetBridge.clearAll]).
  static Future<void> revokeOnSignOut(Dio dio) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString(deviceIdKey);
    await prefs.remove(issuedAtKey);
    await prefs.remove(scopeKey);
    if (deviceId == null) return;
    await dio.delete<void>('/auth/widget-credential',
        queryParameters: {'device_id': deviceId});
  }
}
