import 'package:dio/dio.dart';

const int kOutboxMaxAttempts = 10;

enum OutboxErrorDisposition { transient, permanent }

OutboxErrorDisposition classifyOutboxError(Object error) {
  if (error is! DioException) return OutboxErrorDisposition.permanent;
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.cancel:
      return OutboxErrorDisposition.transient;
    case DioExceptionType.badCertificate:
      return OutboxErrorDisposition.permanent;
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }
  final status = error.response?.statusCode;
  if (status == null) return OutboxErrorDisposition.transient;
  if (status == 408 || status == 429) return OutboxErrorDisposition.transient;
  if (status >= 500) return OutboxErrorDisposition.transient;
  if (status >= 400) return OutboxErrorDisposition.permanent;
  return OutboxErrorDisposition.transient;
}
