/// Rolling record of recent router locations, fed by the GoRouter delegate
/// listener in `router.dart`.
///
/// Used to attribute feedback submissions to the screen the user was on (and
/// the one they came from) so the team can reproduce the submitter's context.
class RouteHistory {
  RouteHistory._();

  static const int _maxEntries = 8;
  static final List<String> _recent = <String>[];

  static void record(String location) {
    if (_recent.isNotEmpty && _recent.last == location) return;
    _recent.add(location);
    if (_recent.length > _maxEntries) _recent.removeAt(0);
  }

  /// The location currently on screen, if any navigation has been recorded.
  static String? get current => _recent.isEmpty ? null : _recent.last;

  /// The location visited before [current] — useful when feedback is opened
  /// from the account screen but is really about the previous screen.
  static String? get previous =>
      _recent.length < 2 ? null : _recent[_recent.length - 2];
}
