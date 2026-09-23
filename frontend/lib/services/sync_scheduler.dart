/// Hands "an op was just queued" signals from the repositories to the
/// `OutboxCoordinator`'s sync session.
///
/// The repositories are built before the coordinator (the coordinator needs
/// them to drain), so they cannot hold the coordinator directly. They get this
/// holder's [noteLocalWrite] instead, and the coordinator provider points the
/// holder at itself once it exists. A write that lands before that is
/// remembered and replayed on [attach], so it still opens a session.
class SyncScheduler {
  void Function()? _target;
  bool _missedWrite = false;

  /// Routes future local-write signals to [target]. Replays one signal if a
  /// write was noted while nothing was attached.
  void attach(void Function() target) {
    _target = target;
    if (_missedWrite) {
      _missedWrite = false;
      target();
    }
  }

  /// Stops routing to [target] (no-op if a newer target replaced it).
  void detach(void Function() target) {
    if (_target == target) _target = null;
  }

  /// Records that an op was queued. Never drains by itself.
  void noteLocalWrite() {
    final target = _target;
    if (target == null) {
      _missedWrite = true;
      return;
    }
    target();
  }
}
