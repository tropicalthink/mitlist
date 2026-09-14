import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether the in-app notification offer has been answered, so a
/// user who said "not now" is asked exactly once and never nagged.
class PushPromptStore {
  static const key = 'push_prompt_decided';

  static Future<bool> isDecided() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  static Future<void> markDecided() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }
}

/// Decides when to offer push notifications.
///
/// The OS dialog used to fire on the first cold start, before sign-in, when
/// the user had no idea what mitlist would notify them about. Now it waits
/// for the first thing they do inside a household: the first list item,
/// chore, expense, pin or recipe written to the outbox while a household is
/// selected. At that point [showPrompt] runs once, and the answer is
/// persisted through [PushPromptStore] so it never fires again on this
/// device.
///
/// Every dependency is injected so the decision is unit-testable without
/// Firebase, a database or a widget tree.
class PushPromptGate {
  PushPromptGate({
    required this.firstActions,
    required this.hasHousehold,
    required this.isDecided,
    required this.hasSystemPermission,
    required this.showPrompt,
  });

  /// Emits whenever the user makes a change that goes through the outbox.
  final Stream<void> firstActions;

  /// True while a household is selected.
  final bool Function() hasHousehold;

  /// True once the offer has been answered on this device.
  final Future<bool> Function() isDecided;

  /// True when the OS already lets the app notify; asking again is pointless.
  final Future<bool> Function() hasSystemPermission;

  /// Shows the offer. Must persist the decision itself so [isDecided] flips.
  final Future<void> Function() showPrompt;

  StreamSubscription<void>? _sub;
  bool _prompting = false;

  void start() {
    _sub ??= firstActions.listen((_) => unawaited(_onAction()));
  }

  Future<void> _onAction() async {
    // A burst of writes (or an outbox draining and refilling) must not stack
    // several prompts; only the first one through gets to ask.
    if (_prompting || !hasHousehold()) return;
    _prompting = true;
    try {
      if (await isDecided() || await hasSystemPermission()) {
        // Nothing left to ask: stop listening for good.
        await _sub?.cancel();
        _sub = null;
        return;
      }
      await _sub?.cancel();
      _sub = null;
      await showPrompt();
    } finally {
      _prompting = false;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
