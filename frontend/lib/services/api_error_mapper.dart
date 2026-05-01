import 'package:dio/dio.dart';

/// Maps backend error responses and network failures into stable,
/// user-facing error messages.
class ApiErrorMapper {
  static String fromDio(DioException e) {
    // 1. Try backend error code first.
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final code = data['error']?.toString();
      final message = data['message']?.toString();
      if (code != null && code != 'ok') {
        final mapped = _codeMessages[code];
        if (mapped != null) return mapped;
        if (message != null && message.isNotEmpty) return message;
      }
    }

    // 2. Fall back to HTTP status.
    switch (e.response?.statusCode) {
      case 400:
        return 'Invalid request';
      case 401:
        return 'Your session expired. Please sign in again.';
      case 403:
        return 'You don\'t have permission to do that.';
      case 404:
        return 'Not found.';
      case 409:
        return 'That already exists.';
      case 422:
        return 'Please check your input and try again.';
      case 429:
        return 'Too many requests. Please wait a moment.';
      case 500:
      case 502:
      case 503:
        return 'Something went wrong on our end. Please try again.';
    }

    // 3. Network-level errors.
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Request timed out. Please check your connection.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Network error. Please check your connection.';
    }
    if (e.type == DioExceptionType.cancel) {
      return 'Request was cancelled.';
    }

    return 'Something went wrong. Please try again.';
  }

  static const _codeMessages = <String, String>{
    'not_found': 'Not found.',
    'permission_denied': 'You don\'t have permission to do that.',
    'validation_error': 'Please check your input and try again.',
    'conflict': 'That already exists.',
    'unauthorized': 'Your session expired. Please sign in again.',
    'internal_error': 'Something went wrong on our end. Please try again.',
  };
}
