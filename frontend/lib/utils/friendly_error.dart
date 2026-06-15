import 'dart:io';

import 'package:dio/dio.dart';

import '../l10n/app_localizations.dart';

String friendlyErrorMessage(Object error, AppLocalizations l10n) {
  if (error is DioException) {
    final response = error.response;
    final statusCode = response?.statusCode;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return l10n.commonCheckConnection;
    }

    if (error.type == DioExceptionType.connectionError) {
      return l10n.commonCheckConnection;
    }

    if (statusCode != null) {
      if (statusCode >= 500) {
        return l10n.errorServerHiccup;
      }
      if (statusCode == 409) {
        return l10n.errorConflict;
      }
      if (statusCode == 404) {
        return l10n.errorNotFound;
      }
      if (statusCode == 403) {
        return l10n.errorNoPermission;
      }
      if (statusCode == 401) {
        return l10n.errorSignInAgain;
      }
    }
  }

  if (error is SocketException) {
    return l10n.commonCheckConnection;
  }

  return l10n.errorGenericRetry;
}
