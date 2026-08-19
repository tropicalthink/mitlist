import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations_en.dart';
import 'package:mitlist/services/api_error_mapper.dart';
import 'package:mitlist/utils/friendly_error.dart';

DioException _dioError(
    {int? statusCode,
    Object? data,
    DioExceptionType type = DioExceptionType.badResponse}) {
  final options = RequestOptions(path: '/groups/join');
  return DioException(
    requestOptions: options,
    type: type,
    response: statusCode == null
        ? null
        : Response(requestOptions: options, statusCode: statusCode, data: data),
  );
}

void main() {
  final l10n = AppLocalizationsEn();

  group('friendlyErrorMessage with ApiException', () {
    test('surfaces the backend message for 4xx responses, sentence-cased', () {
      final dio = _dioError(
        statusCode: 400,
        data: {'error': 'validation_error', 'message': 'invite expired'},
      );
      final err = apiException(dio);
      expect(friendlyErrorMessage(err, l10n), 'Invite expired');
    });

    test('surfaces conflict detail like already-a-member', () {
      final dio = _dioError(
        statusCode: 409,
        data: {
          'error': 'conflict',
          'message': 'already a member of this group'
        },
      );
      final err = apiException(dio);
      expect(friendlyErrorMessage(err, l10n), 'Already a member of this group');
    });

    test('ignores 5xx backend messages in favor of localized copy', () {
      final dio = _dioError(
        statusCode: 500,
        data: {'error': 'internal_error', 'message': 'internal server error'},
      );
      final err = apiException(dio);
      expect(friendlyErrorMessage(err, l10n), l10n.errorServerHiccup);
    });

    test('falls back to localized network copy when no response', () {
      final dio = _dioError(type: DioExceptionType.connectionError);
      final err = apiException(dio);
      expect(friendlyErrorMessage(err, l10n), l10n.commonCheckConnection);
    });

    test('plain ApiException without cause falls back to generic', () {
      expect(
        friendlyErrorMessage(
            const ApiException('Unexpected response format'), l10n),
        l10n.errorGenericRetry,
      );
    });
  });

  group('friendlyErrorMessage with raw DioException', () {
    test('maps statuses to localized copy', () {
      expect(friendlyErrorMessage(_dioError(statusCode: 404), l10n),
          l10n.errorNotFound);
      expect(friendlyErrorMessage(_dioError(statusCode: 403), l10n),
          l10n.errorNoPermission);
    });
  });
}
