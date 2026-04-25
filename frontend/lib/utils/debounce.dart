import 'dart:async';

/// Debounces a callback so it only fires after [duration] of inactivity.
///
/// Typical usage inside a StatefulWidget:
/// ```dart
/// final _debounce = Debounce();
///
/// void _onSearchChanged(String value) {
///   _debounce(() => performSearch(value));
/// }
///
/// @override
/// void dispose() {
///   _debounce.dispose();
///   super.dispose();
/// }
/// ```
class Debounce {
  final Duration duration;
  Timer? _timer;

  Debounce({this.duration = const Duration(milliseconds: 300)});

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void cancel() {
    _timer?.cancel();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Creates a one-off debounced function.
///
/// Returns a function that, when called, schedules [action] after [delay].
/// Calling the returned function again before the delay resets the timer.
///
/// The caller is responsible for cancelling the underlying timer via
/// [Debounce.dispose] when the owning widget is disposed.
Debounce debounce([
  void Function()? action,
  Duration delay = const Duration(milliseconds: 300),
]) {
  final d = Debounce(duration: delay);
  if (action != null) {
    d(action);
  }
  return d;
}
