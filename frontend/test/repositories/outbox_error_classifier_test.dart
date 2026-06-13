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

    test('409 is conflict', () {
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

    test('DioException with connectionError type is transient', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionError,
      );
      expect(classifyOutboxError(e), equals(OutboxErrorDisposition.transient));
    });

    test('non-Dio exception is permanent', () {
      expect(classifyOutboxError(StateError('boom')),
          equals(OutboxErrorDisposition.permanent));
    });
  });
}
