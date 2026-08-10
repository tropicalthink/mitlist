import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/repositories/outbox_error_classifier.dart';

import '../support/fakes.dart';

void main() {
  group('classifyOutboxError —', () {
    test('4xx (non-409/429) are permanent', () {
      for (final code in [400, 401, 403, 404, 422]) {
        expect(classifyOutboxError(fakeDioException(statusCode: code)),
            equals(OutboxErrorDisposition.permanent),
            reason: 'status $code should be permanent');
      }
    });

    test('409 is a conflict (routed to the resolution UI)', () {
      expect(classifyOutboxError(fakeDioException(statusCode: 409)),
          equals(OutboxErrorDisposition.conflict));
    });

    test('408 and 429 are transient', () {
      expect(classifyOutboxError(fakeDioException(statusCode: 408)),
          equals(OutboxErrorDisposition.transient));
      expect(classifyOutboxError(fakeDioException(statusCode: 429)),
          equals(OutboxErrorDisposition.transient));
    });

    test('5xx are transient', () {
      for (final code in [500, 502, 503]) {
        expect(classifyOutboxError(fakeDioException(statusCode: code)),
            equals(OutboxErrorDisposition.transient),
            reason: 'status $code should be transient');
      }
    });

    test('transport failures are unreachable, not transient', () {
      // Both retry, but only `transient` spends an attempt. A request that
      // never reached a server is evidence about the network, not the op —
      // counting it dead-letters good writes made offline.
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.cancel,
      ]) {
        expect(
          classifyOutboxError(
            DioException(requestOptions: RequestOptions(path: '/'), type: type),
          ),
          equals(OutboxErrorDisposition.unreachable),
          reason: '$type never reached the server',
        );
      }
    });

    test('stalls after the server was reached stay transient', () {
      // We connected, so the server saw the request; that is real evidence.
      for (final type in [
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          classifyOutboxError(
            DioException(requestOptions: RequestOptions(path: '/'), type: type),
          ),
          equals(OutboxErrorDisposition.transient),
          reason: '$type happened after a connection was established',
        );
      }
    });

    test('non-Dio exception is permanent', () {
      expect(classifyOutboxError(StateError('boom')),
          equals(OutboxErrorDisposition.permanent));
    });
  });
}
