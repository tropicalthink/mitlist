import 'dart:io';

import 'package:dio/dio.dart';

String friendlyErrorMessage(Object error) {
  if (error is DioException) {
    final response = error.response;
    final statusCode = response?.statusCode;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Check your connection and try again.';
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Check your connection and try again.';
    }

    if (statusCode != null) {
      if (statusCode >= 500) {
        return 'Server hiccup \u2014 try again in a moment.';
      }
      if (statusCode == 409) {
        return 'Someone else changed this. Refresh and try again.';
      }
      if (statusCode == 404) {
        return 'Not found. It may have been deleted.';
      }
      if (statusCode == 403) {
        return 'You don\u2019t have permission for this.';
      }
      if (statusCode == 401) {
        return 'Please sign in again.';
      }
    }
  }

  if (error is SocketException) {
    return 'Check your connection and try again.';
  }

  return 'Something went wrong. Please try again.';
}
