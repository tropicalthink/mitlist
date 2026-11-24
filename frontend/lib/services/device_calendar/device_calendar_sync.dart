import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/external_calendar_models.dart';
import '../../utils/external_calendar_visibility.dart';
import '../external_calendar_service.dart';
import 'device_calendar_source.dart';

/// Why a sync did or did not upload.
enum DeviceSyncOutcome {
  synced,

  /// Within [DeviceCalendarSync.minInterval] of the last start/resume sync.
  throttled,

  /// No device connection for this install (or signed out, or unsupported).
  skipped,

  /// Calendar access is not granted; the app never prompts from here.
  noPermission,

  /// Signed out or stopped while it ran: nothing was sent after that.
  stopped,
  failed,
}

/// A per-event choice on the phone: [pending] until the server confirmed it.
class OverrideEntry {
  final EventOverride? value;
  final bool pending;

  const OverrideEntry(this.value, {required this.pending});
}

/// The owner's per-event choices for this phone's calendars, mirrored on the
/// phone. The server is the source of truth (`GET /calendar/external/
/// overrides`); a choice made here stays [OverrideEntry.pending] until the
/// server accepted it, so it is re-sent rather than lost. Keyed by user, then
/// server calendar id and event uid.
class DeviceOverrideStore {
  const DeviceOverrideStore();

  static String _key(String userId) => 'device_calendar_overrides.v2.$userId';
  static String _legacyKey(String userId) =>
      'device_calendar_overrides.$userId';

  static String entryKey(String calendarId, String uid) => '$calendarId\n$uid';

  static (String, String) splitKey(String key) {
    final i = key.indexOf('\n');
    return (key.substring(0, i), key.substring(i + 1));
  }

  Future<Map<String, OverrideEntry>> entries(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(userId));
    if (raw == null) {
      // Choices stored by the first build: treat them as not yet confirmed,
      // so they are sent again.
      final legacy = prefs.getString(_legacyKey(userId));
      if (legacy == null) return {};
      try {
        final decoded = jsonDecode(legacy);
        if (decoded is! Map) return {};
        return {
          for (final e in decoded.entries)
            if (EventOverride.fromWire(e.value) case final v?)
              '${e.key}': OverrideEntry(v, pending: true),
        };
      } catch (_) {
        return {};
      }
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, OverrideEntry>{};
      for (final e in decoded.entries) {
        final v = e.value;
        if (v is! Map) continue;
        final value = EventOverride.fromWire(v['v']);
        final pending = v['p'] == true;
        // A confirmed entry always has a value; a pending null is a clear.
        if (value == null && !pending) continue;
        out['${e.key}'] = OverrideEntry(value, pending: pending);
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(String userId, Map<String, OverrideEntry> all) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(userId),
      jsonEncode({
        for (final e in all.entries)
          e.key: {'v': e.value.value?.wire, 'p': e.value.pending},
      }),
    );
    await prefs.remove(_legacyKey(userId));
  }

  /// The person's choice (null: back to the calendar's setting), pending
  /// until [confirm].
  Future<void> set(
    String userId, {
    required String calendarId,
    required String uid,
    required EventOverride? visibility,
  }) async {
    final all = await entries(userId);
    all[entryKey(calendarId, uid)] = OverrideEntry(visibility, pending: true);
    await _save(userId, all);
  }

  /// The server accepted [value] for [key]. A newer choice made meanwhile
  /// stays pending.
  Future<void> confirm(String userId, String key, EventOverride? value) async {
    final all = await entries(userId);
    final current = all[key];
    if (current == null || !current.pending || current.value != value) return;
    if (value == null) {
      all.remove(key);
    } else {
      all[key] = OverrideEntry(value, pending: false);
    }
    await _save(userId, all);
  }

  /// Replaces every confirmed choice with [confirmed] (the server's), keeping
  /// whatever is still pending.
  Future<void> replaceConfirmed(
      String userId, Map<String, EventOverride> confirmed) async {
    final all = await entries(userId);
    final next = <String, OverrideEntry>{
      for (final e in confirmed.entries)
        e.key: OverrideEntry(e.value, pending: false),
      for (final e in all.entries)
        if (e.value.pending) e.key: e.value,
    };
    await _save(userId, next);
  }
}

/// Uploads this phone's calendars, filtered on the phone by the contract's
/// device client upload rule ([buildDeviceUpload]).
///
/// Runs after every settings change ([syncNow]) and on app start and resume
/// at most every [minInterval] ([syncIfDue]), only while signed in and only
/// when this install has a device connection. [stop] (sign-out) makes any
/// run in flight give up before it sends anything. Uses no database.
class DeviceCalendarSync {
  DeviceCalendarSync({
    required Future<ExternalCalendarService> Function() api,
    required DeviceCalendarSource source,
    required bool Function() isSignedIn,
    required Future<String?> Function() currentUserId,
    DeviceOverrideStore overrides = const DeviceOverrideStore(),
    DateTime Function()? now,
  })  : _api = api,
        _source = source,
        _isSignedIn = isSignedIn,
        _currentUserId = currentUserId,
        _overrides = overrides,
        _now = now ?? DateTime.now;

  static const minInterval = Duration(minutes: 15);
  static const lookBehind = Duration(days: 1);
  static const lookAhead = Duration(days: 90);

  final Future<ExternalCalendarService> Function() _api;
  final DeviceCalendarSource _source;
  final bool Function() _isSignedIn;
  final Future<String?> Function() _currentUserId;
  final DeviceOverrideStore _overrides;
  final DateTime Function() _now;

  bool _stopped = false;
  Future<DeviceSyncOutcome>? _inFlight;
  Completer<DeviceSyncOutcome>? _rerun;

  static String connectionKey(String userId) =>
      'device_calendar_connection.$userId';
  static String lastSyncKey(String userId) =>
      'device_calendar_last_sync.$userId';

  bool get isSupported => _source.isSupported;

  /// Remembers this install's device connection, so start/resume know to
  /// sync. Set when the person adds "Calendars on this phone".
  Future<void> rememberConnection(String userId, String connectionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(connectionKey(userId), connectionId);
  }

  Future<void> forgetConnection(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(connectionKey(userId));
    await prefs.remove(lastSyncKey(userId));
  }

  /// Start/resume: sync unless it ran less than [minInterval] ago.
  Future<DeviceSyncOutcome> syncIfDue() => _schedule(force: false);

  /// A settings change: sync now. A change made while a sync runs gets its
  /// own run right after.
  Future<DeviceSyncOutcome> syncNow() => _schedule(force: true);

  /// Sign-out: nothing more is read or sent by this instance.
  void stop() {
    _stopped = true;
  }

  bool get _live => !_stopped && _isSignedIn();

  Future<DeviceSyncOutcome> _schedule({required bool force}) {
    if (_stopped) return Future.value(DeviceSyncOutcome.stopped);
    final running = _inFlight;
    if (running != null) {
      // A start/resume sync joins the one running; a settings change needs
      // a run that starts after it (it may have read the old settings).
      if (!force) return running;
      return (_rerun ??= Completer<DeviceSyncOutcome>()).future;
    }
    final run = _guarded(force);
    _inFlight = run;
    unawaited(run.then((_) {
      _inFlight = null;
      final rerun = _rerun;
      _rerun = null;
      if (rerun != null) rerun.complete(_schedule(force: true));
    }));
    return run;
  }

  Future<DeviceSyncOutcome> _guarded(bool force) async {
    try {
      return await _run(force);
    } catch (_) {
      return _stopped ? DeviceSyncOutcome.stopped : DeviceSyncOutcome.failed;
    }
  }

  /// The owner's choices to apply: the server's, with any choice made on
  /// this phone that the server has not confirmed sent to it first. Throws
  /// when the server's set cannot be read or a pending choice cannot be
  /// sent; callers must then not act on a partial set.
  Future<Map<String, EventOverride>> resolveOverrides(String userId) async {
    final api = await _api();
    final server = await api.listOverrides();
    final local = await _overrides.entries(userId);
    final sent = <String, EventOverride?>{};
    for (final e in local.entries) {
      if (!e.value.pending) continue;
      final (calendarId, uid) = DeviceOverrideStore.splitKey(e.key);
      await api.setOverride(
        calendarId: calendarId,
        externalUid: uid,
        visibility: e.value.value,
      );
      sent[e.key] = e.value.value;
      await _overrides.confirm(userId, e.key, e.value.value);
    }
    final merged = <String, EventOverride>{
      for (final o in server)
        DeviceOverrideStore.entryKey(o.calendarId, o.externalUid): o.visibility,
    };
    for (final e in sent.entries) {
      final value = e.value;
      if (value == null) {
        merged.remove(e.key);
      } else {
        merged[e.key] = value;
      }
    }
    await _overrides.replaceConfirmed(userId, merged);
    // A choice made while this ran is applied too (and sent next run).
    for (final e in (await _overrides.entries(userId)).entries) {
      if (!e.value.pending) continue;
      final value = e.value.value;
      if (value == null) {
        merged.remove(e.key);
      } else {
        merged[e.key] = value;
      }
    }
    return merged;
  }

  Future<DeviceSyncOutcome> _run(bool force) async {
    if (!_source.isSupported || !_live) return DeviceSyncOutcome.skipped;
    final userId = await _currentUserId();
    if (userId == null || userId.isEmpty || !_live) {
      return DeviceSyncOutcome.skipped;
    }
    final prefs = await SharedPreferences.getInstance();
    final connectionId = prefs.getString(connectionKey(userId));
    if (connectionId == null) return DeviceSyncOutcome.skipped;

    final now = _now();
    if (!force) {
      final last = prefs.getInt(lastSyncKey(userId));
      if (last != null &&
          now.difference(DateTime.fromMillisecondsSinceEpoch(last)) <
              minInterval) {
        return DeviceSyncOutcome.throttled;
      }
    }
    if (await _source.permission() != DeviceCalendarPermission.granted) {
      return DeviceSyncOutcome.noPermission;
    }
    // Counts as an attempt whatever happens next, so a failing server is not
    // asked again on every resume.
    await prefs.setInt(lastSyncKey(userId), now.millisecondsSinceEpoch);

    final api = await _api();
    if (!_live) return DeviceSyncOutcome.stopped;
    final connections = await api.listConnections();
    CalendarConnection? connection;
    for (final c in connections) {
      if (c.id == connectionId && c.isDevice) connection = c;
    }
    if (connection == null) {
      // Removed (here or on another device): stop syncing this install.
      await forgetConnection(userId);
      return DeviceSyncOutcome.skipped;
    }
    if (!_live) return DeviceSyncOutcome.stopped;

    final calendars = await _source.calendars();
    final events =
        await _source.events(now.subtract(lookBehind), now.add(lookAhead));
    if (!_live) return DeviceSyncOutcome.stopped;
    // Fail closed: without the full set of choices (a "hidden" might be
    // missing) nothing is uploaded this run.
    final Map<String, EventOverride> stored;
    try {
      stored = await resolveOverrides(userId);
    } catch (_) {
      return _stopped ? DeviceSyncOutcome.stopped : DeviceSyncOutcome.failed;
    }
    if (!_live) return DeviceSyncOutcome.stopped;

    final serverIdByDeviceId = {
      for (final c in connection.calendars) c.externalId: c.id,
    };
    final upload = buildDeviceUpload(
      calendars: calendars,
      events: events,
      shares: {
        for (final c in connection.calendars) c.externalId: c.shares,
      },
      overrides: (calendarId, uid) {
        final serverId = serverIdByDeviceId[calendarId];
        if (serverId == null) return null;
        return stored[DeviceOverrideStore.entryKey(serverId, uid)];
      },
    );
    // Last check before anything leaves the phone.
    if (!_live) return DeviceSyncOutcome.stopped;
    await api.deviceSync(connection.id, upload.toJson());
    return DeviceSyncOutcome.synced;
  }
}
