import 'dart:io';

import 'package:dio/dio.dart';

import '../l10n/app_localizations.dart';
import '../services/app_check_service.dart';
import '../services/api_error_mapper.dart';
import '../services/turnstile_provider.dart';

String friendlyErrorMessage(Object error, AppLocalizations l10n) {
  // Attestation failures carry their own already-user-facing message; both
  // reach the user before any request is sent, so there is no server message
  // to prefer over them.
  if (error is AppCheckUnavailableException ||
      error is TurnstileUnavailableException) {
    return _sentenceCase((error as ApiException).message);
  }

  // Services wrap transport errors in ApiException. Surface the backend's
  // specific message when it sent one ("invite expired", "already a member
  // of this group", ...) instead of collapsing to the generic fallback.
  if (error is ApiException) {
    final server = error.serverMessage;
    if (server != null && server.isNotEmpty) {
      return _sentenceCase(server);
    }
    final cause = error.cause;
    if (cause != null) {
      return friendlyErrorMessage(cause, l10n);
    }
    return l10n.errorGenericRetry;
  }

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

String _sentenceCase(String message) {
  if (message.isEmpty) return message;
  return message[0].toUpperCase() + message.substring(1);
}
