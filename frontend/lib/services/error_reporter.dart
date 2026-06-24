import 'package:sentry_flutter/sentry_flutter.dart';

class ErrorReporter {
  static final ErrorReporter _instance = ErrorReporter._();
  factory ErrorReporter() => _instance;
  ErrorReporter._();

  bool _initialized = false;

  void init({required String dsn, String? environment}) {
    if (_initialized) return;
    // Only mark active when a DSN is provided; self-hosters with no DSN stay
    // in no-op mode and Sentry is never initialised.
    if (dsn.isNotEmpty) {
      _initialized = true;
    }
  }

  void captureException(dynamic exception, {StackTrace? stackTrace}) {
    if (!_initialized) return;
    Sentry.captureException(exception, stackTrace: stackTrace);
  }

  bool get isInitialized => _initialized;
}
