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

    test('409 carrying the server row is a conflict (resolution UI)', () {
      expect(
          classifyOutboxError(fakeDioException(statusCode: 409, data: {
            'error': 'conflict',
            'current': {'id': 'x', 'name': 'Milk'},
          })),
          equals(OutboxErrorDisposition.conflict));
    });

    test('bare 409 (idempotency replay / uniqueness) is permanent', () {
      // No `current` state means there is nothing for the user to resolve;
      // recording it as a conflict pinned the review banner forever.
      expect(classifyOutboxError(fakeDioException(statusCode: 409)),
          equals(OutboxErrorDisposition.permanent));
    });

    test('409 with Retry-After (replay still processing) is transient', () {
      final requestOptions = RequestOptions(path: '/fake');
      final error = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: requestOptions,
          statusCode: 409,
          data: 'request with this idempotency key is still processing',
          headers: Headers.fromMap({
            'retry-after': ['2'],
          }),
        ),
      );
      expect(classifyOutboxError(error),
          equals(OutboxErrorDisposition.transient));
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
