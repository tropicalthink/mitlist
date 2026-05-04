// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class PushSubscriptionService {
  static const _subscribedKey = 'push_subscribed';

  Future<void> init() async {
    if (!kReleaseMode) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_subscribedKey) == true) return;

    try {
      final vapidDio = Dio(BaseOptions(
        baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
        connectTimeout: ApiConfig.requestTimeout,
        receiveTimeout: ApiConfig.requestTimeout,
      ));
      final vapidResp = await vapidDio.get('/vapid');
      final publicKey = vapidResp.data['public_key'] as String;

      final sw = html.window.navigator.serviceWorker;
      if (sw == null) return;
      await sw.register('service_worker.js');
      final reg = await sw.ready;
      final subscription = await reg.pushManager?.subscribe({
        'userVisibleOnly': true,
        'applicationServerKey': _urlBase64ToUint8List(publicKey),
      });
      if (subscription == null) return;

      final authDio = Dio(BaseOptions(
        baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
        connectTimeout: ApiConfig.requestTimeout,
        receiveTimeout: ApiConfig.requestTimeout,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ));
      final token = prefs.getString(ApiConfig.accessTokenKey);
      if (token != null) {
        authDio.options.headers[ApiConfig.authorizationHeader] =
            '${ApiConfig.authorizationPrefix}$token';
      }

      final p256dhKey = subscription.getKey('p256dh');
      final authKey = subscription.getKey('auth');
      if (p256dhKey == null || authKey == null) return;

      await authDio.post('/auth/push-subscriptions', data: {
        'endpoint': subscription.endpoint ?? '',
        'p256dh': _encodeKey(p256dhKey),
        'auth': _encodeKey(authKey),
      });

      await prefs.setBool(_subscribedKey, true);
    } catch (e) {
      debugPrint('push subscription failed: $e');
    }
  }

  static String _encodeKey(ByteBuffer? key) {
    if (key == null) return '';
    return base64.encode(Uint8List.view(key));
  }

  static Uint8List _urlBase64ToUint8List(String input) {
    final normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    switch (normalized.length % 4) {
      case 2:
        return base64.decode('$normalized==');
      case 3:
        return base64.decode('$normalized=');
      default:
        return base64.decode(normalized);
    }
  }
}
