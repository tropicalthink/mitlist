import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app's side of the `me.mitlist/widgets` method channel (plans/047,
/// contract C4). Home screen widgets, Siri, Controls and the Android quick
/// add live in native code; this is how the app hands them the widget
/// credential and the snapshot, collects the ops they queued, and drives the
/// shopping-trip Live Activity.
///
/// Every call is best effort. Widgets must never block or break the app, so
/// a missing implementation (web, desktop, tests) or a native failure is
/// logged in debug builds and otherwise ignored.
class WidgetBridge {
  WidgetBridge({MethodChannel? channel, bool? isSupported})
      : _channel = channel ?? const MethodChannel(channelName),
        _supported =
            isSupported ?? (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  static const channelName = 'me.mitlist/widgets';

  /// Shared instance for code without a provider scope (sign-out cleanup).
  static final WidgetBridge instance = WidgetBridge();

  final MethodChannel _channel;
  final bool _supported;
  _PendingClear? _clearing;

  /// [clearAll]'s reason when the session is not remembered ("Remember me"
  /// off): widgets then say they need Remember me instead of "Sign in".
  static const clearReasonNotRemembered = 'not_remembered';

  /// Whether this platform has home screen widgets at all.
  bool get isSupported => _supported;

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('WidgetBridge.$method failed: ${e.code}');
      return null;
    }
  }

  /// Stores the widget credential natively. [credential] is the C4 JSON:
  /// token, expires_at, api_base_url, user_id, device_id.
  Future<void> setCredential(Map<String, Object?> credential) =>
      _invoke<void>('setCredential', credential);

  /// Whether a readable, unexpired credential is stored.
  Future<bool> hasCredential() async =>
      await _invoke<bool>('hasCredential') ?? false;

  /// Removes the credential, snapshot, queued ops and flags; widgets then
  /// show their signed-out state, or the one [reason] names (see
  /// [clearReasonNotRemembered]). Sign-out passes no reason.
  ///
  /// A sign-out cascade can ask several times at once; calls with the same
  /// reason share one native call. A call with another reason is not folded
  /// into the one in flight (its reason would be lost): it runs after it, so
  /// the widgets end on the state the last caller asked for.
  Future<void> clearAll({String? reason}) {
    final pending = _clearing;
    if (pending != null && pending.reason == reason) return pending.future;
    final before =
        pending?.future.catchError((Object _) {}) ?? Future<void>.value();
    late final _PendingClear entry;
    final future = before
        .then((_) => _invoke<void>(
              'clearAll',
              reason == null ? null : <String, Object?>{'reason': reason},
            ))
        .whenComplete(() {
      if (identical(_clearing, entry)) _clearing = null;
    });
    entry = _PendingClear(reason, future);
    _clearing = entry;
    return future;
  }

  /// Writes a server snapshot (C1) and reloads every widget.
  Future<void> writeSnapshot(String json) =>
      _invoke<void>('writeSnapshot', {'json': json});

  /// Raw lines of the pending-ops queue (C2), oldest first.
  Future<List<String>> readPendingOps() async {
    final lines = await _invoke<List<Object?>>('readPendingOps');
    return [
      for (final line in lines ?? const <Object?>[])
        if (line is String && line.trim().isNotEmpty) line,
    ];
  }

  /// Removes the given ops from the queue once the app has taken them over.
  Future<void> ackPendingOps(List<String> opIds) async {
    if (opIds.isEmpty) return;
    await _invoke<void>('ackPendingOps', {'op_ids': opIds});
  }

  /// Whether a widget got a 401 since the last call (then the credential
  /// needs re-issuing). Clears the flag.
  Future<bool> consumeAuthFailure() async =>
      await _invoke<bool>('consumeAuthFailure') ?? false;

  Future<void> reloadWidgets() => _invoke<void>('reloadWidgets');

  /// Kinds of mitlist widgets on the home screen right now, each one of
  /// `HomeWidgetKind`'s ids (duplicates when a kind is placed twice; empty
  /// when there are none). Null when native code cannot tell: unsupported
  /// platform, an app build without the method, or a native failure.
  Future<List<String>?> installedWidgets() async {
    final kinds = await _invoke<List<Object?>>('installedWidgets');
    if (kinds == null) return null;
    return [
      for (final kind in kinds)
        if (kind is String) kind,
    ];
  }

  /// Whether the launcher can pin a widget in one tap (Android 8+ launchers
  /// that support it). Always false on iOS.
  Future<bool> isPinWidgetSupported() async =>
      await _invoke<bool>('isPinWidgetSupported') ?? false;

  /// Asks the launcher to pin a widget of [kind] (a `HomeWidgetKind` id).
  /// True when the launcher showed its request; false when it could not.
  Future<bool> pinWidget(String kind) async =>
      await _invoke<bool>('pinWidget', {'kind': kind}) ?? false;

  /// Lets native code deliver its queue and refetch the snapshot with the
  /// widget credential in the background.
  Future<void> requestRefresh() => _invoke<void>('requestRefresh');

  /// Starts the shopping-trip Live Activity (iOS 16.2+). Null elsewhere.
  Future<String?> startShoppingTrip({
    required String householdName,
    required int itemsLeft,
    required int itemsTotal,
    required int totalCents,
    required String currency,
  }) =>
      _invoke<String>('startShoppingTrip', {
        'household_name': householdName,
        'items_left': itemsLeft,
        'items_total': itemsTotal,
        'total_cents': totalCents,
        'currency': currency,
      });

  Future<void> updateShoppingTrip({
    required int itemsLeft,
    required int itemsTotal,
    required int totalCents,
  }) =>
      _invoke<void>('updateShoppingTrip', {
        'items_left': itemsLeft,
        'items_total': itemsTotal,
        'total_cents': totalCents,
      });

  /// Ends the Live Activity on a final "Add expense" state that opens
  /// [addExpenseUrl].
  Future<void> endShoppingTrip({
    required int totalCents,
    required String currency,
    required String addExpenseUrl,
  }) =>
      _invoke<void>('endShoppingTrip', {
        'total_cents': totalCents,
        'currency': currency,
        'add_expense_url': addExpenseUrl,
      });
}

/// A [WidgetBridge.clearAll] in flight, with the reason it was sent with.
class _PendingClear {
  _PendingClear(this.reason, this.future);

  final String? reason;
  final Future<void> future;
}
