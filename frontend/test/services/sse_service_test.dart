import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/config/api_config.dart';
import 'package:mitlist/services/sse_service.dart';
import 'package:mitlist/services/token_store.dart';

class _MemoryTokenStore implements TokenStore {
  @override
  Future<String?> getAccessToken() async => 'access';

  @override
  Future<String?> getRefreshToken() async => 'refresh';

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {}
}

Future<void> _waitFor(bool Function() condition,
    {Duration timeout = const Duration(seconds: 2)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late HttpServer server;
  var attempts = 0;

  setUp(() async {
    attempts = 0;
    // Stands in for an API that is down: every attempt fails at once.
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      attempts++;
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..close();
    });
    ApiConfig.setRuntimeBaseUrl('http://127.0.0.1:${server.port}');
  });

  tearDown(() async {
    ApiConfig.setRuntimeBaseUrl(null);
    await server.close(force: true);
  });

  test('backs off between failed connects instead of spinning', () async {
    final sse = SseService(_MemoryTokenStore());
    addTearDown(sse.dispose);

    await sse.connect('g1');
    await _waitFor(() => attempts == 1);
    // The first retry waits two seconds; nothing may happen before it.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(attempts, 1);
  });

  test('wake cuts the backoff short once the network is back', () async {
    final sse = SseService(_MemoryTokenStore());
    addTearDown(sse.dispose);

    await sse.connect('g1');
    await _waitFor(() => attempts == 1);
    sse.wake();
    await _waitFor(() => attempts == 2, timeout: const Duration(seconds: 1));
    // One immediate retry, then the backoff applies again.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(attempts, 2);
  });
}
