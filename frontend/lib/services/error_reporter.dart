class ErrorReporter {
  static final ErrorReporter _instance = ErrorReporter._();
  factory ErrorReporter() => _instance;
  ErrorReporter._();

  bool _initialized = false;

  void init({required String dsn, String? environment}) {
    if (_initialized) return;
    _initialized = true;
  }

  void captureException(dynamic exception, {StackTrace? stackTrace}) {
    if (!_initialized) return;
    // GlitchTip/Sentry capture would go here.
    // For now, log to console in debug builds.
    // ignore: avoid_print
    print('[ErrorReporter] $exception');
  }

  bool get isInitialized => _initialized;
}
