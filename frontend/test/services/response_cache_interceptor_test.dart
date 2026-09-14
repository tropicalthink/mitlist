import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/response_cache_interceptor.dart';
import 'package:mitlist/storage/app_database.dart';

/// In-memory store so the interceptor can be exercised without Drift.
class _MemoryStore implements ResponseCacheStore {
  final Map<String, CachedResponseBody> rows = {};
  int reads = 0;

  @override
  Future<CachedResponseBody?> read(String key) async {
    reads++;
    return rows[key];
  }

  @override
  Future<void> write(String key, int statusCode, String bodyJson) async {
    rows[key] = CachedResponseBody(
      statusCode: statusCode,
      bodyJson: bodyJson,
      updatedAt: DateTime.now(),
    );
  }
}

/// Scripted transport: either answers with a JSON body or fails like a dead
/// network, and counts how often it was reached.
class _ScriptedAdapter implements HttpClientAdapter {
  Object? Function(RequestOptions options) script;
  int calls = 0;

  _ScriptedAdapter(this.script);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    final result = script(options);
    if (result is Exception) throw result;
    return ResponseBody.fromString(
      jsonEncode(result),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _client(
  _ScriptedAdapter adapter,
  ResponseCacheStore store, {
  bool Function()? isKnownOffline,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://api.test/api'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(ResponseCacheInterceptor(
    store: () => store,
    isKnownOffline: isKnownOffline,
  ));
  return dio;
}

DioException _offline(RequestOptions o) =>
    DioException.connectionError(requestOptions: o, reason: 'offline');

void main() {
  group('ResponseCacheInterceptor', () {
    test('stores a successful JSON GET and serves it on a transport failure',
        () async {
      final store = _MemoryStore();
      final adapter = _ScriptedAdapter((_) => [
            {'id': 'p1', 'name': 'Milk'}
          ]);
      final dio = _client(adapter, store);

      final live = await dio.get('/products', queryParameters: {'g': '1'});
      expect(live.extra[ResponseCacheInterceptor.fromCacheExtra], isNot(true));
      // The write is fire-and-forget; let it land.
      await Future<void>.delayed(Duration.zero);
      expect(store.rows, hasLength(1));

      adapter.script = _offline;
      final cached = await dio.get('/products', queryParameters: {'g': '1'});
      expect(cached.statusCode, 200);
      expect(cached.data, [
        {'id': 'p1', 'name': 'Milk'}
      ]);
      expect(cached.extra[ResponseCacheInterceptor.fromCacheExtra], isTrue);
      expect(cached.headers.value(ResponseCacheInterceptor.cacheHeader),
          'stale');
      expect(adapter.calls, 2, reason: 'the request was still attempted');
    });

    test('the query string is part of the key', () async {
      final store = _MemoryStore();
      final adapter = _ScriptedAdapter((_) => {'page': 'one'});
      final dio = _client(adapter, store);
      await dio.get('/items', queryParameters: {'offset': '0'});
      await Future<void>.delayed(Duration.zero);

      adapter.script = _offline;
      await expectLater(
        dio.get('/items', queryParameters: {'offset': '50'}),
        throwsA(isA<DioException>()),
      );
    });

    test('a real server error is passed through, never masked', () async {
      final store = _MemoryStore();
      final adapter = _ScriptedAdapter((_) => {'ok': true});
      final dio = _client(adapter, store);
      await dio.get('/me');
      await Future<void>.delayed(Duration.zero);

      adapter.script = (o) => DioException.badResponse(
            statusCode: 401,
            requestOptions: o,
            response: Response(requestOptions: o, statusCode: 401),
          );
      await expectLater(
        dio.get('/me'),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 401)),
      );
    });

    test('writes are never cached or served', () async {
      final store = _MemoryStore();
      final adapter = _ScriptedAdapter((_) => {'id': 'x'});
      final dio = _client(adapter, store);
      await dio.post('/items', data: {'name': 'a'});
      await Future<void>.delayed(Duration.zero);
      expect(store.rows, isEmpty);

      adapter.script = _offline;
      await expectLater(
        dio.post('/items', data: {'name': 'a'}),
        throwsA(isA<DioException>()),
      );
    });

    test('a known-offline device is answered from cache without a request',
        () async {
      final store = _MemoryStore();
      final adapter = _ScriptedAdapter((_) => {'n': 1});
      var offline = false;
      final dio = _client(adapter, store, isKnownOffline: () => offline);
      await dio.get('/summary');
      await Future<void>.delayed(Duration.zero);
      expect(adapter.calls, 1);

      offline = true;
      final res = await dio.get('/summary');
      expect(res.data, {'n': 1});
      expect(res.extra[ResponseCacheInterceptor.fromCacheExtra], isTrue);
      expect(adapter.calls, 1, reason: 'the wire was not touched');
    });

    test('a known-offline cache miss still sends the request', () async {
      final store = _MemoryStore();
      final adapter = _ScriptedAdapter(_offline);
      final dio = _client(adapter, store, isKnownOffline: () => true);
      await expectLater(dio.get('/never-seen'), throwsA(isA<DioException>()));
      expect(adapter.calls, 1);
    });

    test('a raw SocketException from the transport counts as offline',
        () async {
      final store = _MemoryStore();
      final adapter = _ScriptedAdapter((_) => {'v': 2});
      final dio = _client(adapter, store);
      await dio.get('/v');
      await Future<void>.delayed(Duration.zero);

      adapter.script = (_) => const SocketException('no route');
      final res = await dio.get('/v');
      expect(res.data, {'v': 2});
    });

    test('opts out per request', () async {
      final store = _MemoryStore();
      final adapter = _ScriptedAdapter((_) => {'secret': true});
      final dio = _client(adapter, store);
      await dio.get(
        '/token',
        options: Options(
          extra: {ResponseCacheInterceptor.noCacheExtra: true},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.rows, isEmpty);
    });
  });

  group('DriftResponseCacheStore', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ));
    });

    tearDown(() => db.close());

    test('round-trips a body and overwrites on the same key', () async {
      final store = DriftResponseCacheStore(db);
      await store.write('GET a', 200, '[1]');
      await store.write('GET a', 200, '[1,2]');
      final hit = await store.read('GET a');
      expect(hit?.bodyJson, '[1,2]');
      expect(await store.read('GET b'), isNull);
    });

    test('evicts the oldest rows past the cap', () async {
      final store = DriftResponseCacheStore(db);
      final cap = AppDatabase.maxResponseCacheRows;
      for (var i = 0; i < cap + 5; i++) {
        await db.upsertResponseCache(
          cacheKey: 'GET $i',
          statusCode: 200,
          bodyJson: '{}',
        );
      }
      final remaining = await db.responseCaches.count().getSingle();
      expect(remaining, cap);
      expect(await store.read('GET 0'), isNull, reason: 'oldest evicted');
      expect(await store.read('GET ${cap + 4}'), isNotNull);
    });

    test('is wiped with the rest of the user data', () async {
      final store = DriftResponseCacheStore(db);
      await store.write('GET a', 200, '{}');
      await db.clearAllUserData();
      expect(await store.read('GET a'), isNull);
    });
  });
}
