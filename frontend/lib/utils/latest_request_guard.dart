/// Small lifecycle helper for stateful screens that can start overlapping
/// asynchronous loads.
///
/// Every request captures a token from [begin]. Only the newest token remains
/// current, so an older response cannot overwrite data selected or refreshed
/// more recently. [dispose] invalidates all outstanding work.
class LatestRequestGuard {
  int _generation = 0;
  bool _disposed = false;

  int begin() => ++_generation;

  bool isCurrent(int token) => !_disposed && token == _generation;

  void invalidate() => _generation++;

  void dispose() {
    _disposed = true;
    _generation++;
  }
}
