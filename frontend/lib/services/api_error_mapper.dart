import 'package:dio/dio.dart';

/// Exception that carries a clean, user-facing message.
class ApiException implements Exception {
  final String message;

  /// The verbatim message the backend sent in its error payload, if any.
  /// UI-layer mappers prefer this over a generic fallback.
  final String? serverMessage;

  /// The underlying transport error, so UI-layer mappers can still
  /// localize network/status failures.
  final DioException? cause;

  const ApiException(this.message, {this.serverMessage, this.cause});

  /// True when the backend refused because the household needs premium
  /// (HTTP 402). Callers show the premium sheet instead of a plain error.
  bool get isPaymentRequired => cause?.response?.statusCode == 402;

  @override
  String toString() => message;
}

Exception apiException(DioException e) => ApiException(
      ApiErrorMapper.fromDio(e),
      serverMessage: ApiErrorMapper.serverMessage(e),
      cause: e,
    );

/// Maps backend error responses and network failures into stable,
/// user-facing error messages.
class ApiErrorMapper {
  /// The backend's specific plain-language message, or null when the
  /// response carried none (e.g. pure network failures). Limited to 4xx:
  /// 5xx bodies say "internal server error", which is worse than the
  /// localized fallback.
  static String? serverMessage(DioException e) {
    final status = e.response?.statusCode;
    if (status == null || status >= 500) return null;
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    return null;
  }

  static String fromDio(DioException e) {
    // 1. Try backend error response first.
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final code = data['error']?.toString();
      final message = data['message']?.toString();

      // Prefer the backend's specific plain-language message when available.
      if (message != null && message.isNotEmpty) {
        return message;
      }

      if (code != null && code != 'ok') {
        final mapped = _codeMessages[code];
        if (mapped != null) return mapped;
      }
    }

    // 2. Fall back to HTTP status.
    switch (e.response?.statusCode) {
      case 400:
        return 'Invalid request';
      case 401:
        return 'Your session expired. Please sign in again.';
      case 402:
        return 'This household needs premium to add more members.';
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
