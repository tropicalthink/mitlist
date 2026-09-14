import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:dio/dio.dart';

import '../storage/app_database.dart';

/// Where [ResponseCacheInterceptor] keeps bodies. Abstract so the interceptor
/// can be tested without a database.
abstract class ResponseCacheStore {
  Future<CachedResponseBody?> read(String key);
  Future<void> write(String key, int statusCode, String bodyJson);
}

class CachedResponseBody {
  final int statusCode;
  final String bodyJson;
  final DateTime updatedAt;

  const CachedResponseBody({
    required this.statusCode,
    required this.bodyJson,
    required this.updatedAt,
  });
}

/// [ResponseCacheStore] backed by the app's Drift database.
class DriftResponseCacheStore implements ResponseCacheStore {
  final AppDatabase _db;

  DriftResponseCacheStore(this._db);

  @override
  Future<CachedResponseBody?> read(String key) async {
    final row = await _db.getResponseCache(key);
    if (row == null) return null;
    return CachedResponseBody(
      statusCode: row.statusCode,
      bodyJson: row.bodyJson,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> write(String key, int statusCode, String bodyJson) {
    return _db.upsertResponseCache(
      cacheKey: key,
      statusCode: statusCode,
      bodyJson: bodyJson,
    );
  }
}

/// Read-through offline cache for JSON `GET` requests.
///
/// Every successful JSON `GET` is stored under its method + full URL. When a
/// later identical request cannot reach the server — connection refused, DNS
/// failure, connect/receive timeout — the stored body is returned instead of
/// the error, so a screen that has no cache of its own still paints what it
/// showed last time rather than an error page.
///
/// Two things keep this honest:
///
///  * Only transport failures are masked. A real server answer (401, 404,
///    500…) is passed through untouched, because serving a stale body over a
///    "you were removed from this household" would be a lie.
///  * When [isKnownOffline] already says the device has no network, the
///    request is answered from the cache *before* it is sent, so the caller
///    does not wait out the connect timeout to learn what it could have known
///    up front. With a cache miss the request still goes out and fails on its
///    own; nothing is invented.
///
/// A served body is marked with `response.extra['fromCache'] == true` and an
/// `x-mitlist-cache: stale` header for callers that want to show it as such.
///
/// Writes (POST/PATCH/DELETE) are never cached: the outbox owns those.
class ResponseCacheInterceptor extends Interceptor {
  final ResponseCacheStore Function() _store;
  final bool Function() _isKnownOffline;

  /// Bodies above this size are not stored. Nothing the app lists comes close;
  /// the bound is there so a runaway payload cannot bloat the database.
  static const int maxBodyBytes = 512 * 1024;

  static const String fromCacheExtra = 'fromCache';
  static const String noCacheExtra = 'noCache';
  static const String cacheHeader = 'x-mitlist-cache';

  ResponseCacheInterceptor({
    required ResponseCacheStore Function() store,
    bool Function()? isKnownOffline,
  })  : _store = store,
        _isKnownOffline = isKnownOffline ?? (() => false);

  static bool _cacheable(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET') return false;
    if (options.responseType != ResponseType.json) return false;
    if (options.extra[noCacheExtra] == true) return false;
    return true;
  }

  static String cacheKey(RequestOptions options) =>
      '${options.method.toUpperCase()} ${options.uri}';

  /// True for failures that mean "the server was never reached", the only
  /// class of error a cached body may legitimately stand in for.
  static bool isTransportFailure(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.unknown:
        return err.error is SocketException;
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return false;
    }
  }

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_cacheable(options) || !_isKnownOffline()) {
      handler.next(options);
      return;
    }
    final hit = await _readSafely(cacheKey(options));
    if (hit == null) {
      handler.next(options);
      return;
    }
    handler.resolve(_toResponse(options, hit), true);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final options = response.requestOptions;
    final data = response.data;
    if (_cacheable(options) &&
        response.extra[fromCacheExtra] != true &&
        response.statusCode == 200 &&
        (data is Map || data is List)) {
      final encoded = jsonEncode(data);
      if (encoded.length <= maxBodyBytes) {
        // Fire-and-forget: a slow disk must not delay the caller, and a failed
        // write only costs the next offline read.
        _store()
            .write(cacheKey(options), response.statusCode!, encoded)
            .catchError((_) {});
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_cacheable(err.requestOptions) || !isTransportFailure(err)) {
      handler.next(err);
      return;
    }
    final hit = await _readSafely(cacheKey(err.requestOptions));
    if (hit == null) {
      handler.next(err);
      return;
    }
    handler.resolve(_toResponse(err.requestOptions, hit));
  }

  Future<CachedResponseBody?> _readSafely(String key) async {
    try {
      return await _store().read(key);
    } catch (_) {
      return null;
    }
  }

  Response<dynamic> _toResponse(RequestOptions options, CachedResponseBody hit) {
    return Response<dynamic>(
      requestOptions: options,
      data: jsonDecode(hit.bodyJson),
      statusCode: hit.statusCode,
      headers: Headers.fromMap({
        cacheHeader: const ['stale'],
        Headers.contentTypeHeader: const [Headers.jsonContentType],
      }),
      extra: {...options.extra, fromCacheExtra: true},
    );
  }
}
