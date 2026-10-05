import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';

/// The event names the API accepts (the backend's `productEventNames`
/// allowlist). Anything else is dropped server-side.
abstract final class ProductEventName {
  static const welcomeShown = 'welcome_shown';
  static const tourStarted = 'tour_started';
  static const tourSkipped = 'tour_skipped';
  static const tourCompleted = 'tour_completed';
  static const signupCompleted = 'signup_completed';
  static const householdCreated = 'household_created';
  static const householdJoined = 'household_joined';
  static const intentAnswered = 'intent_answered';
  static const firstItemAdded = 'first_item_added';
  static const checklistStepDone = 'checklist_step_done';
  static const homeNeedsYouAction = 'home_needs_you_action';
}

/// First-party product events (plans/048 stage 8): the onboarding funnel and
/// Home actions, sent to mitlist's own API (`POST /events`), never to a third
/// party. Before sign-up an event carries only a random install id kept on
/// the device; after it, the session attributes it to the account.
///
/// Recording never blocks or throws. Events tracked in the same frame go out
/// as one small batch; a failed send keeps them (bounded) for the next one.
/// Prop values must be identifiers (`[A-Za-z0-9_.:-]`, ≤ 64 chars), never
/// names or other free text: the server drops anything else.
class ProductEvents {
  ProductEvents({
    bool? enabled,
    Future<void> Function(Map<String, Object?> body)? send,
    Future<SharedPreferences> Function()? prefs,
  })  : _enabled = enabled ?? _enabledByDefault,
        _send = send ?? _post,
        _prefs = prefs ?? SharedPreferences.getInstance;

  static final ProductEvents instance = ProductEvents();

  /// Off unless the build passes `--dart-define=MITLIST_PRODUCT_EVENTS=true`.
  /// The published privacy policy says the apps carry no analytics, so no
  /// build may send these until the policy describes them; being off also
  /// keeps a dev API free of test taps and widget tests free of requests and
  /// timers.
  static const bool _enabledByDefault =
      bool.fromEnvironment('MITLIST_PRODUCT_EVENTS');

  static const int _maxBatch = 20;
  static const int _maxQueued = 60;
  static const String _installIdKey = 'product_events_install_id';
  static const String _newHouseholdPrefix = 'product_events_new_household:';

  final bool _enabled;

  /// Whether events are sent at all; callers skip work that only feeds
  /// an event (a lookup for its household) when this is false.
  bool get isEnabled => _enabled;
  final Future<void> Function(Map<String, Object?> body) _send;
  final Future<SharedPreferences> Function() _prefs;
  final List<Map<String, Object?>> _queue = [];
  bool _flushScheduled = false;
  bool _sending = false;
  String? _installId;

  /// Records [name]. [groupId] attaches the household (the server keeps it
  /// only when the caller is a member, and derives creator vs invitee).
  void track(
    String name, {
    String? groupId,
    Map<String, String> props = const {},
  }) {
    if (!_enabled) return;
    _queue.add({
      'name': name,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      if (groupId != null) 'group_id': groupId,
      if (props.isNotEmpty) 'props': props,
    });
    if (_queue.length > _maxQueued) {
      _queue.removeRange(0, _queue.length - _maxQueued);
    }
    if (_flushScheduled) return;
    _flushScheduled = true;
    scheduleMicrotask(() {
      _flushScheduled = false;
      unawaited(flush());
    });
  }

  /// A household was created or joined on this install: report the household
  /// event and arm [noteItemAdded] for it.
  void householdStarted(String name, String groupId, {String? source}) {
    track(name,
        groupId: groupId, props: {if (source != null) 'source': source});
    if (!_enabled) return;
    unawaited(() async {
      try {
        final prefs = await _prefs();
        await prefs.setBool('$_newHouseholdPrefix$groupId', true);
      } catch (_) {}
    }());
  }

  /// Reports `first_item_added` the first time something ([kind]:
  /// `list_item`, `chore` or `expense`) is added in a household that was
  /// created or joined on this install. Households that existed before stay
  /// silent, so an app update does not report a burst of false "firsts".
  Future<void> noteItemAdded(String? groupId, String kind) async {
    if (!_enabled || groupId == null) return;
    try {
      final prefs = await _prefs();
      final key = '$_newHouseholdPrefix$groupId';
      if (prefs.getBool(key) != true) return;
      await prefs.remove(key);
      track(ProductEventName.firstItemAdded,
          groupId: groupId, props: {'kind': kind});
    } catch (_) {}
  }

  /// Sends what is queued. Safe to call any time; a failure keeps the events
  /// for the next attempt.
  @visibleForTesting
  Future<void> flush() async {
    if (!_enabled || _sending || _queue.isEmpty) return;
    _sending = true;
    final batch = _queue.take(_maxBatch).toList();
    var sent = false;
    try {
      await _send({'install_id': await _ensureInstallId(), 'events': batch});
      sent = true;
    } catch (_) {
      // Offline or the API is unreachable: keep them for the next event.
    } finally {
      _sending = false;
    }
    if (!sent) return;
    _queue.removeWhere((e) => batch.any((b) => identical(b, e)));
    if (_queue.isNotEmpty) unawaited(flush());
  }

  Future<String> _ensureInstallId() async {
    final cached = _installId;
    if (cached != null) return cached;
    final prefs = await _prefs();
    var id = prefs.getString(_installIdKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_installIdKey, id);
    }
    return _installId = id;
  }

  /// Built on the first send, never in tests (see [_enabledByDefault]).
  static Dio? _dio;

  static Future<void> _post(Map<String, Object?> body) async {
    // The API client attaches the session when there is one; the endpoint
    // accepts both.
    await (_dio ??= createApiClient()).post<void>('/events', data: body);
  }
}
