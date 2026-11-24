/// Hands "an op was just queued" signals from the repositories to the
/// `OutboxCoordinator`'s sync session, and owns the outbox *holds*.
///
/// The repositories are built before the coordinator (the coordinator needs
/// them to drain), so they cannot hold the coordinator directly. They get this
/// holder's [noteLocalWrite] instead, and the coordinator provider points the
/// holder at itself once it exists. A write that lands before that is
/// remembered and replayed on [attach], so it still opens a session.
///
/// A hold ([hold]) keeps the outbox from draining on its own while a screen
/// that edits in batches is open (the list detail screen): writes stay queued
/// on the device and go out in one flush when the last hold is released. The
/// coordinator listens ([addHoldListener]) and does the actual deferring and
/// flushing; holds are counted here so a screen can take one synchronously,
/// before the coordinator exists.
class SyncScheduler {
  void Function()? _target;
  bool _missedWrite = false;
  final Set<SyncHold> _holds = {};
  final List<void Function(bool held)> _holdListeners = [];

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

  /// True while at least one [SyncHold] is active.
  bool get isHeld => _holds.isNotEmpty;

  /// Why the outbox is held right now (one entry per active hold), for logs.
  List<String> get holdReasons => [for (final h in _holds) h.reason];

  /// Takes a hold on the outbox. Holds nest: the outbox stays held until
  /// every one of them is released. Release each exactly once with
  /// [SyncHold.release] (repeat calls are no-ops).
  SyncHold hold(String reason) {
    final hold = SyncHold._(this, reason);
    final wasHeld = isHeld;
    _holds.add(hold);
    if (!wasHeld) _notifyHold(true);
    return hold;
  }

  void _release(SyncHold hold) {
    if (!_holds.remove(hold)) return;
    if (!isHeld) _notifyHold(false);
  }

  /// Called with true when the first hold is taken and with false when the
  /// last one is released.
  void addHoldListener(void Function(bool held) listener) =>
      _holdListeners.add(listener);

  void removeHoldListener(void Function(bool held) listener) =>
      _holdListeners.remove(listener);

  void _notifyHold(bool held) {
    for (final listener in List.of(_holdListeners)) {
      listener(held);
    }
  }
}

/// One hold on the outbox, from [SyncScheduler.hold].
class SyncHold {
  SyncHold._(this._scheduler, this.reason);

  final SyncScheduler _scheduler;

  /// What took the hold, for logs.
  final String reason;
  bool _released = false;

  /// False once [release] has been called.
  bool get isActive => !_released;

  /// Gives the hold back. When it was the last one, the coordinator flushes
  /// everything that waited for it. Safe to call more than once.
  void release() {
    if (_released) return;
    _released = true;
    _scheduler._release(this);
  }
}
