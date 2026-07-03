// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:js_interop';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart';
import '../config/api_config.dart';
import 'token_store.dart';

class PushSubscriptionService {
  static const _subscribedKey = 'push_subscribed';
  final TokenStore _tokenStore;

  PushSubscriptionService([TokenStore? tokenStore])
      : _tokenStore = tokenStore ?? SecureTokenStore();

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

      final sw = window.navigator.serviceWorker;
      await sw.register('service_worker.js'.toJS).toDart;
      final reg = await sw.ready.toDart;
      final subscription = await reg.pushManager
          .subscribe(
            PushSubscriptionOptionsInit(
              userVisibleOnly: true,
              applicationServerKey: _urlBase64ToUint8List(publicKey).toJS,
            ),
          )
          .toDart;

      final authDio = Dio(BaseOptions(
        baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
        connectTimeout: ApiConfig.requestTimeout,
        receiveTimeout: ApiConfig.requestTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ));
      final token = await _tokenStore.getAccessToken();
      if (token != null) {
        authDio.options.headers[ApiConfig.authorizationHeader] =
            '${ApiConfig.authorizationPrefix}$token';
      }

      final p256dhKey = subscription.getKey('p256dh');
      final authKey = subscription.getKey('auth');
      if (p256dhKey == null || authKey == null) return;

      await authDio.post('/auth/push-subscriptions', data: {
        'endpoint': subscription.endpoint,
        'p256dh': _encodeKey(p256dhKey),
        'auth': _encodeKey(authKey),
      });

      await prefs.setBool(_subscribedKey, true);
    } catch (e) {
      debugPrint('push subscription failed: $e');
    }
  }

  Future<void> unsubscribe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sw = window.navigator.serviceWorker;
      final reg = await sw.ready.toDart;
      final subscription = await reg.pushManager.getSubscription().toDart;
      final endpoint = subscription?.endpoint;

      if (endpoint != null && endpoint.isNotEmpty) {
        await _deleteServerSubscription(endpoint);
      }
      await subscription?.unsubscribe().toDart;
      await prefs.remove(_subscribedKey);
    } catch (e) {
      debugPrint('push unsubscribe failed: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_subscribedKey);
    }
  }

  Future<void> _deleteServerSubscription(String endpoint) async {
    final authDio = Dio(BaseOptions(
      baseUrl: '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
      connectTimeout: ApiConfig.requestTimeout,
      receiveTimeout: ApiConfig.requestTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    final token = await _tokenStore.getAccessToken();
    if (token != null) {
      authDio.options.headers[ApiConfig.authorizationHeader] =
          '${ApiConfig.authorizationPrefix}$token';
    }

    final response = await authDio.get('/auth/push-subscriptions');
    final raw = response.data;
    final subscriptions = raw is List
        ? raw
        : raw is Map<String, dynamic> && raw['subscriptions'] is List
            ? raw['subscriptions'] as List
            : const [];
    for (final sub in subscriptions) {
      if (sub is Map<String, dynamic> && sub['endpoint'] == endpoint) {
        final id = sub['id'];
        if (id is String && id.isNotEmpty) {
          await authDio.delete('/auth/push-subscriptions/$id');
        }
        return;
      }
    }
  }

  static String _encodeKey(JSArrayBuffer? key) {
    if (key == null) return '';
    return base64.encode(Uint8List.view(key.toDart));
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
