import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/external_calendar_models.dart';
import '../../models/group_models.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/external_calendar_provider.dart';
import '../../providers/group_provider.dart' show cachedGroupsProvider;
import '../../services/api_error_mapper.dart';
import '../../services/device_calendar/device_calendar_source.dart';
import '../../services/device_calendar/device_calendar_sync.dart';
import '../../sheets/add_calendar_link_sheet.dart';
import '../../theme/spacing.dart';
import '../../utils/external_calendar_visibility.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/calendar_tour.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';

/// What the owner picks for a calendar in one household: the first choice
/// offered is busy only; "not shared" is the default.
enum ShareChoice { busy, details, none }

ShareChoice shareChoiceOf(ExternalCalendar calendar, String groupId) =>
    switch (calendar.shareFor(groupId)) {
      ShareVisibility.busy => ShareChoice.busy,
      ShareVisibility.details => ShareChoice.details,
      null => ShareChoice.none,
    };

/// [calendar]'s shares with [groupId] set to [choice], every other household
/// left as it was (the endpoint replaces the whole list).
List<CalendarShare> sharesWith(
  ExternalCalendar calendar,
  String groupId,
  ShareChoice choice,
) {
  return [
    for (final s in calendar.shares)
      if (s.groupId != groupId) s,
    if (choice == ShareChoice.busy)
      CalendarShare(groupId: groupId, visibility: ShareVisibility.busy),
    if (choice == ShareChoice.details)
      CalendarShare(groupId: groupId, visibility: ShareVisibility.details),
  ];
}

/// "Synced just now / 5 min ago / 3 h ago / yesterday / on Nov 24", like
/// the chores ledger's relative times.
String syncedLabel(
  DateTime syncedAt,
  AppLocalizations l10n,
  String localeName, {
  DateTime? now,
}) {
  final t = syncedAt.toLocal();
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inMinutes < 1) return l10n.sharedCalendarsSyncedJustNow;
  if (diff.inHours < 1) {
    return l10n.sharedCalendarsSyncedMinutes(diff.inMinutes);
  }
  if (diff.inHours < 24) return l10n.sharedCalendarsSyncedHours(diff.inHours);
  if (diff.inHours < 48) return l10n.sharedCalendarsSyncedYesterday;
  return l10n.sharedCalendarsSyncedAt(DateFormat.MMMd(localeName).format(t));
}

/// The friendly words for a connection's `last_error`.
String connectionErrorText(ConnectionError error, AppLocalizations l10n) =>
    switch (error) {
      ConnectionError.fetchFailed => l10n.calendarConnectionErrorFetchFailed,
      ConnectionError.notCalendar => l10n.calendarConnectionErrorNotCalendar,
      ConnectionError.tooLarge => l10n.calendarConnectionErrorTooLarge,
      ConnectionError.unauthorized => l10n.calendarConnectionErrorUnauthorized,
      ConnectionError.other => l10n.calendarConnectionErrorOther,
    };

/// An event in a shared calendar, from the server (iCal links) or from this
/// phone (its own calendars: hidden events are never uploaded, so only the
/// phone knows them).
class UpcomingSharedEvent {
  final CalendarConnection connection;
  final ExternalCalendar calendar;
  final String uid;

  /// Local wall-clock times; for all-day events the local dates.
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String? title;
  final bool sourcePrivate;
  final bool free;
  final EventOverride? override;

  const UpcomingSharedEvent({
    required this.connection,
    required this.calendar,
    required this.uid,
    required this.start,
    required this.end,
    required this.allDay,
    required this.title,
    required this.sourcePrivate,
    required this.free,
    required this.override,
  });

  bool get hasTitle => (title ?? '').trim().isNotEmpty;

  UpcomingSharedEvent withOverride(EventOverride? value) => UpcomingSharedEvent(
        connection: connection,
        calendar: calendar,
        uid: uid,
        start: start,
        end: end,
        allDay: allDay,
        title: title,
        sourcePrivate: sourcePrivate,
        free: free,
        override: value,
      );

  /// What each household sees of this event, by the visibility rules.
  Map<HousemateView, List<Group>> viewsIn(List<Group> groups) {
    final out = <HousemateView, List<Group>>{};
    for (final g in groups) {
      final view = housemateView(
        share: calendar.shareFor(g.id),
        override: override,
        sourcePrivate: sourcePrivate,
        hasTitle: hasTitle,
      );
      out.putIfAbsent(view, () => []).add(g);
    }
    return out;
  }
}

/// You > Shared calendars (`/you/calendars`): the person's connected
/// calendars, how much each household sees of each, single-event choices,
/// and adding, renaming or removing connections.
class SharedCalendarsScreen extends ConsumerStatefulWidget {
  const SharedCalendarsScreen({super.key});

  static const upcomingWindow = Duration(days: 14);
  static const maxUpcoming = 60;

  @override
  ConsumerState<SharedCalendarsScreen> createState() =>
      _SharedCalendarsScreenState();
}

class _SharedCalendarsScreenState extends ConsumerState<SharedCalendarsScreen> {
  List<CalendarConnection>? _connections;
  Object? _loadError;
  bool _adding = false;
  final Set<String> _savingCalendars = {};
  final Set<String> _syncingConnections = {};

  // Coach mark targets (the tour, and "Show me how").
  final _addKey = GlobalKey(debugLabel: 'sharedCalendars-add');
  final _choicesKey = GlobalKey(debugLabel: 'sharedCalendars-choices');
  final _upcomingKey = GlobalKey(debugLabel: 'sharedCalendars-upcoming');
  final _firstHideKey = GlobalKey(debugLabel: 'sharedCalendars-first-hide');
  bool _tourChecked = false;

  Future<void> _runTour({required bool replay}) async {
    final connections = _connections ?? const <CalendarConnection>[];
    final hasCalendar = connections.any((c) => c.calendars.isNotEmpty);
    final hasUpcoming =
        (_upcoming?.isNotEmpty ?? false) && _upcomingKey.currentContext != null;
    await runSharedCalendarsTour(
      context,
      ref,
      addButtons: _addKey,
      choices: hasCalendar ? _choicesKey : null,
      upcoming: hasUpcoming ? _firstHideKey : null,
      replay: replay,
    );
  }

  /// Picks up the tour when the calendar screen just handed it over.
  void _maybeContinueTour() {
    if (_tourChecked) return;
    _tourChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_runTour(replay: false));
    });
  }

  List<UpcomingSharedEvent>? _upcoming;
  bool _upcomingLoading = false;
  bool _upcomingFailed = false;
  int _upcomingGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final service = await ref.read(externalCalendarServiceProvider.future);
      final list = await service.listConnections();
      if (!mounted) return;
      setState(() {
        _connections = list;
        _loadError = null;
      });
      unawaited(_rememberThisPhone(list));
      unawaited(_loadUpcoming());
      _maybeContinueTour();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  String? get _installId => ref.read(deviceInstallIdProvider).valueOrNull;

  bool _isThisPhone(CalendarConnection c) =>
      c.isDevice && c.deviceId != null && c.deviceId == _installId;

  CalendarConnection? get _thisPhone {
    for (final c in _connections ?? const <CalendarConnection>[]) {
      if (_isThisPhone(c)) return c;
    }
    return null;
  }

  /// Keeps start/resume syncing in step with the server's list.
  Future<void> _rememberThisPhone(List<CalendarConnection> list) async {
    final userId = await ref.read(currentUserIdProvider.future);
    final installId = await ref.read(deviceInstallIdProvider.future);
    if (userId == null) return;
    final sync = ref.read(deviceCalendarSyncProvider);
    CalendarConnection? mine;
    for (final c in list) {
      if (c.isDevice && c.deviceId == installId) mine = c;
    }
    if (mine != null) {
      await sync.rememberConnection(userId, mine.id);
    } else {
      await sync.forgetConnection(userId);
    }
  }

  void _replaceConnection(CalendarConnection updated) {
    final list = _connections;
    if (list == null) return;
    setState(() {
      _connections = [
        for (final c in list) c.id == updated.id ? updated : c,
      ];
    });
  }

  void _afterChange() {
    // The household calendar shows the person's own blocks too.
    ref.invalidate(calendarEventsProvider);
    ref.invalidate(calendarConnectionsProvider);
  }

  Future<void> _syncThisPhone() async {
    if (_thisPhone == null) return;
    final outcome = await ref.read(deviceCalendarSyncProvider).syncNow();
    if (!mounted) return;
    if (outcome == DeviceSyncOutcome.failed) {
      AppToast.error(
          context, AppLocalizations.of(context)!.sharedCalendarsSyncFailed);
    }
  }

  // ── Sharing ──────────────────────────────────────────────────────────────

  Future<void> _setShare(
    CalendarConnection connection,
    ExternalCalendar calendar,
    String groupId,
    ShareChoice choice,
  ) async {
    if (shareChoiceOf(calendar, groupId) == choice) return;
    if (_savingCalendars.contains(calendar.id)) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _savingCalendars.add(calendar.id));
    try {
      final service = await ref.read(externalCalendarServiceProvider.future);
      final saved = await service.setShares(
          calendar.id, sharesWith(calendar, groupId, choice));
      if (!mounted) return;
      _replaceConnection(connection.copyWith(calendars: [
        for (final c in connection.calendars)
          c.id == calendar.id ? c.copyWith(shares: saved.shares) : c,
      ]));
      _afterChange();
      // This phone filters before uploading: send what the new choice allows.
      if (_isThisPhone(connection)) await _syncThisPhone();
      unawaited(_loadUpcoming());
    } catch (e) {
      if (mounted) AppToast.error(context, friendlyErrorMessage(e, l10n));
    } finally {
      if (mounted) setState(() => _savingCalendars.remove(calendar.id));
    }
  }

  // ── Adding ───────────────────────────────────────────────────────────────

  Future<void> _addThisPhone() async {
    if (_adding || _atLimit()) return;
    final l10n = AppLocalizations.of(context)!;
    final source = ref.read(deviceCalendarSourceProvider);
    setState(() => _adding = true);
    try {
      var permission = await source.permission();
      if (permission == DeviceCalendarPermission.notDetermined) {
        permission = await source.requestPermission();
      }
      if (!mounted) return;
      if (permission != DeviceCalendarPermission.granted) {
        // Not "adding" any more: the button must not spin behind the dialog.
        setState(() => _adding = false);
        await _explainPermission(permission);
        return;
      }
      final service = await ref.read(externalCalendarServiceProvider.future);
      final installId = await ref.read(deviceInstallIdProvider.future);
      final userId = await ref.read(currentUserIdProvider.future);
      final created = await service.addDeviceConnection(
        name: l10n.sharedCalendarsPhoneDefaultName,
        deviceId: installId,
      );
      if (userId != null) {
        await ref
            .read(deviceCalendarSyncProvider)
            .rememberConnection(userId, created.id);
      }
      if (!mounted) return;
      setState(() {
        _connections = [
          for (final c in _connections ?? const <CalendarConnection>[])
            if (c.id != created.id) c,
          created,
        ];
      });
      // Lists the phone's calendars (no events yet: nothing is shared).
      await ref.read(deviceCalendarSyncProvider).syncNow();
      await _load();
      _afterChange();
    } catch (e) {
      if (mounted) AppToast.error(context, friendlyErrorMessage(e, l10n));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _explainPermission(DeviceCalendarPermission permission) async {
    final l10n = AppLocalizations.of(context)!;
    final restricted = permission == DeviceCalendarPermission.restricted;
    await showAppDialog<void>(
      context: context,
      title: l10n.sharedCalendarsPermissionDeniedTitle,
      body: Text(restricted
          ? l10n.sharedCalendarsPermissionRestricted
          : l10n.sharedCalendarsPermissionDeniedBody),
      actions: [
        AppButton(
          text: l10n.calendarLinkAddAction,
          variant: AppButtonVariant.outline,
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            unawaited(_addLink());
          },
        ),
        if (!restricted)
          AppButton(
            text: l10n.sharedCalendarsOpenSettings,
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              unawaited(ref.read(deviceCalendarSourceProvider).openSettings());
            },
          ),
      ],
    );
  }

  /// The server keeps at most this many connections per person.
  static const _maxConnections = 10;

  bool _atLimit() {
    if ((_connections?.length ?? 0) < _maxConnections) return false;
    AppToast.info(
        context, AppLocalizations.of(context)!.sharedCalendarsLimitReached);
    return true;
  }

  Future<void> _addLink() async {
    if (_atLimit()) return;
    final created = await showAddCalendarLinkSheet(context);
    if (created == null || !mounted) return;
    setState(() {
      _connections = [...?_connections, created];
    });
    AppToast.success(
        context, AppLocalizations.of(context)!.sharedCalendarsAddedNotShared);
    _afterChange();
    unawaited(_loadUpcoming());
  }

  // ── Rename / remove / sync ───────────────────────────────────────────────

  Future<void> _rename(CalendarConnection connection) async {
    final l10n = AppLocalizations.of(context)!;
    var typed = connection.name;
    final name = await showAppDialog<String>(
      context: context,
      title: l10n.sharedCalendarsRenameTitle,
      body: _RenameField(
        initial: connection.name,
        label: l10n.commonName,
        onChanged: (value) => typed = value,
      ),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        AppButton(
          text: l10n.commonSave,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(typed.trim()),
        ),
      ],
    );
    if (name == null || name.isEmpty || name == connection.name || !mounted) {
      return;
    }
    try {
      final service = await ref.read(externalCalendarServiceProvider.future);
      final updated = await service.renameConnection(connection.id, name);
      if (mounted) _replaceConnection(updated);
    } catch (e) {
      if (mounted) AppToast.error(context, friendlyErrorMessage(e, l10n));
    }
  }

  Future<void> _remove(CalendarConnection connection) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.sharedCalendarsRemoveTitle(connection.name),
      body: Text(l10n.sharedCalendarsRemoveBody),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        AppButton(
          text: l10n.commonRemove,
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    try {
      final service = await ref.read(externalCalendarServiceProvider.future);
      await service.deleteConnection(connection.id);
      if (_isThisPhone(connection)) {
        final userId = await ref.read(currentUserIdProvider.future);
        if (userId != null) {
          await ref.read(deviceCalendarSyncProvider).forgetConnection(userId);
        }
      }
      if (!mounted) return;
      setState(() {
        _connections = [
          for (final c in _connections ?? const <CalendarConnection>[])
            if (c.id != connection.id) c,
        ];
      });
      _afterChange();
      unawaited(_loadUpcoming());
    } catch (e) {
      if (mounted) AppToast.error(context, friendlyErrorMessage(e, l10n));
    }
  }

  Future<void> _syncNow(CalendarConnection connection) async {
    if (_syncingConnections.contains(connection.id)) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _syncingConnections.add(connection.id));
    try {
      if (connection.isDevice) {
        await _syncThisPhone();
        await _load();
      } else {
        final service = await ref.read(externalCalendarServiceProvider.future);
        final updated = await service.syncIcs(connection.id);
        if (mounted) _replaceConnection(updated);
        unawaited(_loadUpcoming());
      }
      _afterChange();
    } catch (e) {
      if (!mounted) return;
      // 429 rate_limited: it was fetched under a minute ago, which is not
      // a failure.
      final tooSoon = e is ApiException &&
          (e.code == 'rate_limited' || e.cause?.response?.statusCode == 429);
      if (tooSoon) {
        AppToast.info(context, l10n.sharedCalendarsSyncTooSoon);
      } else {
        AppToast.error(context, friendlyErrorMessage(e, l10n));
      }
    } finally {
      if (mounted) setState(() => _syncingConnections.remove(connection.id));
    }
  }

  // ── Upcoming events ──────────────────────────────────────────────────────

  Future<void> _loadUpcoming() async {
    final connections = _connections;
    if (connections == null) return;
    final gen = ++_upcomingGeneration;
    setState(() {
      _upcomingLoading = true;
      _upcomingFailed = false;
    });
    final now = DateTime.now();
    final until = now.add(SharedCalendarsScreen.upcomingWindow);
    final out = <UpcomingSharedEvent>[];
    var failed = false;

    // iCal links: the server's copy.
    final calendarsById = <String, (CalendarConnection, ExternalCalendar)>{
      for (final c in connections)
        if (!c.isDevice)
          for (final cal in c.calendars) cal.id: (c, cal),
    };
    if (calendarsById.values.any((p) => p.$2.isShared)) {
      try {
        final service = await ref.read(externalCalendarServiceProvider.future);
        final mine = await service.myEvents(now, until);
        for (final e in mine) {
          final pair = calendarsById[e.calendarId];
          if (pair == null || !pair.$2.isShared) continue;
          out.add(UpcomingSharedEvent(
            connection: pair.$1,
            calendar: pair.$2,
            uid: e.externalUid,
            start: e.allDay ? _floating(e.startsAt) : e.startsAt.toLocal(),
            end: e.allDay ? _floating(e.endsAt) : e.endsAt.toLocal(),
            allDay: e.allDay,
            title: e.title,
            sourcePrivate: e.sourcePrivate,
            free: e.free,
            override: e.override,
          ));
        }
      } catch (_) {
        failed = true;
      }
    }

    // This phone: read from the phone itself, never prompting from here.
    final phone = _thisPhone;
    final source = ref.read(deviceCalendarSourceProvider);
    if (phone != null &&
        phone.calendars.any((c) => c.isShared) &&
        source.isSupported) {
      try {
        if (await source.permission() == DeviceCalendarPermission.granted) {
          final userId = await ref.read(currentUserIdProvider.future);
          if (userId == null) throw StateError('signed out');
          // The same merged set the upload uses (server first, pending
          // choices from this phone sent and applied); a failure shows the
          // retry state rather than a guess.
          final stored = await ref
              .read(deviceCalendarSyncProvider)
              .resolveOverrides(userId);
          final byDeviceId = {
            for (final c in phone.calendars) c.externalId: c,
          };
          for (final e in await source.events(now, until)) {
            final cal = byDeviceId[e.calendarId];
            if (cal == null || !cal.isShared || e.cancelled) continue;
            out.add(UpcomingSharedEvent(
              connection: phone,
              calendar: cal,
              uid: e.uid,
              start: e.start,
              end: e.end,
              allDay: e.allDay,
              title: e.title,
              sourcePrivate: e.sourcePrivate,
              free: e.free,
              override: stored[DeviceOverrideStore.entryKey(cal.id, e.uid)],
            ));
          }
        }
      } catch (_) {
        failed = true;
      }
    }

    out.sort((a, b) => a.start.compareTo(b.start));
    if (!mounted || gen != _upcomingGeneration) return;
    setState(() {
      _upcoming = out.take(SharedCalendarsScreen.maxUpcoming).toList();
      _upcomingLoading = false;
      _upcomingFailed = failed;
    });
  }

  static DateTime _floating(DateTime utcMidnight) {
    final u = utcMidnight.toUtc();
    return DateTime(u.year, u.month, u.day);
  }

  Future<void> _chooseOverride(UpcomingSharedEvent event) async {
    final l10n = AppLocalizations.of(context)!;
    const keep = Object();
    final picked = await showAppBottomSheet<Object>(
      context: context,
      title: event.hasTitle ? event.title! : l10n.sharedCalendarsEventNoTitle,
      body: _OverridePicker(
        current: event.override,
        onPick: (value) => Navigator.of(context).pop<Object>(value ?? keep),
      ),
    );
    if (picked == null || !mounted) return;
    final EventOverride? value = picked is EventOverride ? picked : null;
    if (value == event.override) return;
    await _setOverride(event, value);
  }

  Future<void> _setOverride(
      UpcomingSharedEvent event, EventOverride? value) async {
    final l10n = AppLocalizations.of(context)!;
    final previous = _upcoming;
    setState(() {
      _upcoming = [
        for (final e in previous ?? const <UpcomingSharedEvent>[])
          identical(e, event) ||
                  (e.calendar.id == event.calendar.id && e.uid == event.uid)
              ? e.withOverride(value)
              : e,
      ];
    });
    try {
      if (event.connection.isDevice) {
        // Kept on the phone first: a hidden event must stop being uploaded
        // even if the server is unreachable right now.
        final userId = await ref.read(currentUserIdProvider.future);
        if (userId != null) {
          await const DeviceOverrideStore().set(
            userId,
            calendarId: event.calendar.id,
            uid: event.uid,
            visibility: value,
          );
        }
      }
      final service = await ref.read(externalCalendarServiceProvider.future);
      await service.setOverride(
        calendarId: event.calendar.id,
        externalUid: event.uid,
        visibility: value,
      );
      if (event.connection.isDevice) {
        final userId = await ref.read(currentUserIdProvider.future);
        if (userId != null) {
          await const DeviceOverrideStore().confirm(
            userId,
            DeviceOverrideStore.entryKey(event.calendar.id, event.uid),
            value,
          );
        }
        await _syncThisPhone();
      }
      _afterChange();
    } catch (e) {
      if (!mounted) return;
      if (!event.connection.isDevice) setState(() => _upcoming = previous);
      AppToast.error(context, friendlyErrorMessage(e, l10n));
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // Read eagerly so [_isThisPhone] knows this install's id.
    ref.watch(deviceInstallIdProvider);
    final groups =
        ref.watch(cachedGroupsProvider).valueOrNull ?? const <Group>[];
    final connections = _connections;
    final supportsPhone = ref.watch(deviceCalendarSourceProvider).isSupported;
    // iPhone calendars have no "private" flag: nothing is turned into busy
    // on its own there, so say so and point at hiding single events.
    String? firstCalendarConnection;
    for (final c in connections ?? const <CalendarConnection>[]) {
      if (c.calendars.isNotEmpty) {
        firstCalendarConnection = c.id;
        break;
      }
    }
    final showIosNote =
        ref.watch(deviceCalendarPlatformProvider) == TargetPlatform.iOS &&
            _thisPhone != null;

    Widget body;
    if (connections == null) {
      body = _loadError != null
          ? _ErrorState(error: _loadError!, onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(MitlistSpacing.md),
              children: const [
                AppSkeleton(width: double.infinity, height: 120),
                SizedBox(height: MitlistSpacing.md),
                AppSkeleton(width: double.infinity, height: 120),
              ],
            );
    } else {
      final anyShared =
          connections.any((c) => c.calendars.any((cal) => cal.isShared));
      body = RefreshIndicator(
        onRefresh: _load,
        // Every section is built (not lazily), so coach marks can find and
        // scroll to any of them.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.sharedCalendarsIntro,
                  style: theme.textTheme.bodyMedium),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  key: const ValueKey('shared-calendars-show-me-how'),
                  text: l10n.sharedCalendarsShowMeHow,
                  icon: const AppIcon(name: 'lightbulb', size: 18),
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.ghost,
                  onPressed: () => _runTour(replay: true),
                ),
              ),
              if (groups.isEmpty) ...[
                const SizedBox(height: MitlistSpacing.sm),
                Text(
                  l10n.sharedCalendarsNoHouseholds,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: MitlistSpacing.lg),
              if (connections.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
                  child: Text(
                    l10n.sharedCalendarsEmpty,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              for (final c in connections) ...[
                _ConnectionCard(
                  connection: c,
                  isThisPhone: _isThisPhone(c),
                  groups: groups,
                  savingCalendars: _savingCalendars,
                  syncing: _syncingConnections.contains(c.id),
                  onShare: (cal, groupId, choice) =>
                      _setShare(c, cal, groupId, choice),
                  onRename: () => _rename(c),
                  onRemove: () => _remove(c),
                  onSync: (!c.isDevice || _isThisPhone(c))
                      ? () => _syncNow(c)
                      : null,
                  iosNote: showIosNote && _isThisPhone(c),
                  firstCalendarKey:
                      c.id == firstCalendarConnection ? _choicesKey : null,
                ),
                const SizedBox(height: MitlistSpacing.md),
              ],
              _AddCard(
                key: _addKey,
                showPhone: supportsPhone && _thisPhone == null,
                busy: _adding,
                onAddPhone: _addThisPhone,
                onAddLink: _addLink,
              ),
              if (anyShared) ...[
                const SizedBox(height: MitlistSpacing.lg),
                _UpcomingSection(
                  key: _upcomingKey,
                  events: _upcoming,
                  loading: _upcomingLoading,
                  failed: _upcomingFailed,
                  groups: groups,
                  iosNote: showIosNote,
                  onRetry: _loadUpcoming,
                  onChoose: _chooseOverride,
                  onQuickHide: _setOverride,
                  firstHideKey: _firstHideKey,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.sharedCalendarsTitle,
        showStandardActions: false,
      ),
      body: body,
    );
  }
}

/// Owns its controller, so it lives exactly as long as the dialog does
/// (including the closing animation).
class _RenameField extends StatefulWidget {
  const _RenameField({
    required this.initial,
    required this.label,
    required this.onChanged,
  });

  final String initial;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  State<_RenameField> createState() => _RenameFieldState();
}

class _RenameFieldState extends State<_RenameField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppInput(
      key: const ValueKey('calendar-rename-input'),
      controller: _controller,
      label: widget.label,
      maxLength: 60,
      onChanged: widget.onChanged,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              friendlyErrorMessage(error, l10n),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: MitlistSpacing.md),
            AppButton(
              text: l10n.commonRetry,
              variant: AppButtonVariant.outline,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.connection,
    required this.isThisPhone,
    required this.groups,
    required this.savingCalendars,
    required this.syncing,
    required this.onShare,
    required this.onRename,
    required this.onRemove,
    required this.onSync,
    this.iosNote = false,
    this.firstCalendarKey,
  });

  /// Coach mark target: this connection's first calendar's choices.
  final GlobalKey? firstCalendarKey;

  final bool iosNote;
  final CalendarConnection connection;
  final bool isThisPhone;
  final List<Group> groups;
  final Set<String> savingCalendars;
  final bool syncing;
  final void Function(ExternalCalendar, String groupId, ShareChoice) onShare;
  final VoidCallback onRename;
  final VoidCallback onRemove;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final localeName = Localizations.localeOf(context).toString();
    final kind = connection.isDevice
        ? (isThisPhone
            ? l10n.sharedCalendarsKindThisPhone
            : l10n.sharedCalendarsKindOtherPhone)
        : l10n.sharedCalendarsKindLink;
    final synced = connection.lastSyncedAt;
    final syncText = syncing
        ? l10n.sharedCalendarsSyncing
        : synced == null
            ? l10n.sharedCalendarsNeverSynced
            : syncedLabel(synced, l10n, localeName);
    final error = connection.error;

    return AppCard(
      key: ValueKey('calendar-connection-${connection.id}'),
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                name: connection.isDevice ? 'devicePhoneMobile' : 'link',
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      '$kind · $syncText',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (onSync != null)
                IconButton(
                  icon: const AppIcon(name: 'arrowPath'),
                  tooltip: l10n.sharedCalendarsSyncNow,
                  onPressed: syncing ? null : onSync,
                ),
              IconButton(
                icon: const AppIcon(name: 'pencil'),
                tooltip: l10n.commonRename,
                onPressed: onRename,
              ),
              IconButton(
                icon: AppIcon(name: 'trashOutline', color: cs.error),
                tooltip: l10n.commonRemove,
                onPressed: onRemove,
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: MitlistSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(name: 'alertCircleOutline', size: 16, color: cs.error),
                const SizedBox(width: MitlistSpacing.xs),
                Expanded(
                  child: Text(
                    connectionErrorText(error, l10n),
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                  ),
                ),
              ],
            ),
          ],
          if (connection.isDevice && !isThisPhone) ...[
            const SizedBox(height: MitlistSpacing.sm),
            Text(
              l10n.sharedCalendarsOtherPhoneNote,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          if (iosNote) ...[
            const SizedBox(height: MitlistSpacing.sm),
            const IosPrivacyNote(key: ValueKey('connection-ios-note')),
          ],
          if (connection.calendars.isEmpty) ...[
            const SizedBox(height: MitlistSpacing.sm),
            Text(
              l10n.sharedCalendarsNoCalendars,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          for (final (i, cal) in connection.calendars.indexed) ...[
            const SizedBox(height: MitlistSpacing.md),
            _CalendarShares(
              key: i == 0 ? firstCalendarKey : null,
              privateFlag: !iosNote,
              calendar: cal,
              groups: groups,
              saving: savingCalendars.contains(cal.id),
              onShare: (groupId, choice) => onShare(cal, groupId, choice),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalendarShares extends StatelessWidget {
  const _CalendarShares({
    super.key,
    this.privateFlag = true,
    required this.calendar,
    required this.groups,
    required this.saving,
    required this.onShare,
  });

  final ExternalCalendar calendar;
  final List<Group> groups;
  final bool saving;
  final void Function(String groupId, ShareChoice choice) onShare;

  /// Whether the source marks private events (iPhone calendars do not, so
  /// the "private events still show as busy" promise is left out there).
  final bool privateFlag;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // One plain sentence per household that sees something; nothing for the
    // ones that see nothing, unless no household sees anything.
    final explanations = <String>[
      for (final g in groups)
        if (shareChoiceOf(calendar, g.id) != ShareChoice.none)
          _explain(shareChoiceOf(calendar, g.id), g.name, l10n, privateFlag),
    ];
    return Column(
      key: ValueKey('calendar-shares-${calendar.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppIcon(name: 'calendarDays', size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: MitlistSpacing.xs),
            Expanded(
              child: Text(
                calendar.name.isEmpty
                    ? l10n.sharedCalendarsUnnamed
                    : calendar.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
        for (final g in groups)
          Padding(
            padding: const EdgeInsets.only(top: MitlistSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 84,
                  child: Text(
                    g.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: ShareSegmentedChoice(
                    keyPrefix: 'share-${calendar.id}-${g.id}',
                    household: g.name,
                    value: shareChoiceOf(calendar, g.id),
                    enabled: !saving,
                    onChanged: (choice) => onShare(g.id, choice),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: MitlistSpacing.xs),
        Text(
          explanations.isEmpty
              ? l10n.sharedCalendarsNotSharedAnywhere
              : explanations.join(' '),
          style:
              theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  static String _explain(ShareChoice c, String household, AppLocalizations l10n,
          bool privateFlag) =>
      switch (c) {
        ShareChoice.busy => l10n.sharedCalendarsExplainBusy(household),
        ShareChoice.details => privateFlag
            ? l10n.sharedCalendarsExplainDetails(household)
            : l10n.sharedCalendarsExplainDetailsNoPrivate(household),
        ShareChoice.none => l10n.sharedCalendarsExplainNone(household),
      };
}

String shareChoiceLabel(ShareChoice c, AppLocalizations l10n) => switch (c) {
      ShareChoice.busy => l10n.sharedCalendarsShareBusy,
      ShareChoice.details => l10n.sharedCalendarsShareDetails,
      ShareChoice.none => l10n.sharedCalendarsShareNone,
    };

/// Busy only / With titles / Not shared for one household, as one
/// square segmented control (2px outline, the selected segment filled).
class ShareSegmentedChoice extends StatelessWidget {
  const ShareSegmentedChoice({
    super.key,
    required this.keyPrefix,
    required this.household,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String keyPrefix;
  final String household;
  final ShareChoice value;
  final bool enabled;
  final ValueChanged<ShareChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outline, width: 2),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, choice) in ShareChoice.values.indexed) ...[
              if (i > 0)
                VerticalDivider(width: 2, thickness: 2, color: cs.outline),
              Expanded(
                child: Semantics(
                  button: true,
                  inMutuallyExclusiveGroup: true,
                  selected: value == choice,
                  label: '$household: ${shareChoiceLabel(choice, l10n)}',
                  excludeSemantics: true,
                  child: InkWell(
                    key: ValueKey('$keyPrefix-${choice.name}'),
                    onTap: enabled && value != choice
                        ? () => onChanged(choice)
                        : null,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: MitlistSpacing.xs,
                        vertical: MitlistSpacing.xs,
                      ),
                      color: value == choice ? cs.onSurface : null,
                      child: Text(
                        shareChoiceLabel(choice, l10n),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: value == choice ? cs.surface : cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  const _AddCard({
    super.key,
    required this.showPhone,
    required this.busy,
    required this.onAddPhone,
    required this.onAddLink,
  });

  final bool showPhone;
  final bool busy;
  final VoidCallback onAddPhone;
  final VoidCallback onAddLink;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.sharedCalendarsAdd,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          if (showPhone) ...[
            const SizedBox(height: MitlistSpacing.md),
            AppButton(
              key: const ValueKey('add-phone-calendars'),
              text: l10n.sharedCalendarsAddPhone,
              icon: const AppIcon(name: 'devicePhoneMobile', size: 18),
              isLoading: busy,
              onPressed: busy ? null : onAddPhone,
            ),
            const SizedBox(height: MitlistSpacing.xs),
            Text(l10n.sharedCalendarsAddPhoneDesc, style: muted),
          ],
          const SizedBox(height: MitlistSpacing.md),
          AppButton(
            key: const ValueKey('add-calendar-link'),
            text: l10n.calendarLinkAddAction,
            variant: AppButtonVariant.outline,
            icon: const AppIcon(name: 'link', size: 18),
            onPressed: onAddLink,
          ),
          const SizedBox(height: MitlistSpacing.xs),
          Text(l10n.sharedCalendarsAddLinkDesc, style: muted),
        ],
      ),
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({
    super.key,
    required this.events,
    required this.loading,
    required this.failed,
    required this.groups,
    required this.iosNote,
    required this.onRetry,
    required this.onChoose,
    required this.onQuickHide,
    this.firstHideKey,
  });

  /// Coach mark target: the first event's one-tap hide.
  final GlobalKey? firstHideKey;
  final List<UpcomingSharedEvent>? events;
  final bool loading;
  final bool failed;
  final List<Group> groups;

  /// iPhone calendars carry no "private" flag: say so here.
  final bool iosNote;
  final Future<void> Function() onRetry;
  final void Function(UpcomingSharedEvent) onChoose;
  final void Function(UpcomingSharedEvent, EventOverride?) onQuickHide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final list = events;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sharedCalendarsUpcomingTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: MitlistSpacing.xs),
        Text(l10n.sharedCalendarsUpcomingIntro, style: muted),
        if (iosNote) ...[
          const SizedBox(height: MitlistSpacing.sm),
          IosPrivacyNote(key: const ValueKey('upcoming-ios-note')),
        ],
        const SizedBox(height: MitlistSpacing.sm),
        if (failed)
          Row(
            children: [
              Expanded(
                child: Text(l10n.sharedCalendarsUpcomingFailed, style: muted),
              ),
              AppButton(
                text: l10n.commonRetry,
                size: AppButtonSize.sm,
                variant: AppButtonVariant.ghost,
                onPressed: onRetry,
              ),
            ],
          ),
        if (list == null && loading)
          const AppSkeleton(width: double.infinity, height: 64)
        else if (list != null && list.isEmpty && !failed)
          Text(l10n.sharedCalendarsUpcomingEmpty, style: muted)
        else if (list != null)
          for (final (i, e) in list.indexed)
            _UpcomingRow(
              event: e,
              groups: groups,
              hideKey: i == 0 ? firstHideKey : null,
              onTap: () => onChoose(e),
              onQuickHide: (v) => onQuickHide(e, v),
            ),
      ],
    );
  }
}

/// "iPhone can't tell which events are private. Hide any event below."
class IosPrivacyNote extends StatelessWidget {
  const IosPrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(MitlistSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outline, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(name: 'informationCircle', size: 18, color: cs.onSurface),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Text(
              l10n.sharedCalendarsIosPrivateNote,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// One upcoming event: when, which calendar, what each household sees of it
/// right now, and a one-tap hide (or show again). Tapping the row opens
/// every choice.
class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({
    required this.event,
    required this.groups,
    required this.onTap,
    required this.onQuickHide,
    this.hideKey,
  });

  final GlobalKey? hideKey;
  final UpcomingSharedEvent event;
  final List<Group> groups;
  final VoidCallback onTap;
  final ValueChanged<EventOverride?> onQuickHide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final localeName = Localizations.localeOf(context).toString();
    final date = DateFormat.MMMEd(localeName).format(event.start);
    final when = event.allDay
        ? '$date · ${l10n.calendarExternalAllDay}'
        : '$date · ${DateFormat.jm(localeName).format(event.start)}';
    final views = event.viewsIn(groups);
    String names(HousemateView v) =>
        (views[v] ?? const <Group>[]).map((g) => g.name).join(', ');
    final seeLines = <String>[
      if (views.containsKey(HousemateView.details))
        l10n.sharedCalendarsSeesDetails(names(HousemateView.details)),
      if (views.containsKey(HousemateView.busy))
        l10n.sharedCalendarsSeesBusy(names(HousemateView.busy)),
    ];
    final sees = seeLines.isEmpty
        ? l10n.sharedCalendarsSeesNothing
        : seeLines.join('\n');
    final choice = switch (event.override) {
      null => l10n.sharedCalendarsOverrideCalendar,
      EventOverride.hidden => l10n.sharedCalendarsOverrideHidden,
      EventOverride.busy => l10n.sharedCalendarsOverrideBusy,
      EventOverride.details => l10n.sharedCalendarsOverrideDetails,
    };
    final title =
        event.hasTitle ? event.title!.trim() : l10n.sharedCalendarsEventNoTitle;
    final notes = [
      if (event.sourcePrivate) l10n.sharedCalendarsEventPrivateNote,
      if (event.free) l10n.sharedCalendarsEventFreeNote,
    ];
    final hidden = event.override == EventOverride.hidden;
    final muted =
        theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: [
              title,
              when,
              ...notes,
              sees,
              l10n.sharedCalendarsEventChoice(choice),
            ].join('. '),
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey(
                  'upcoming-${event.calendar.id}-${event.uid}-${event.start.millisecondsSinceEpoch}'),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppIcon(
                        name: seeLines.isEmpty ? 'eyeSlash' : 'eye',
                        size: 18,
                        color: seeLines.isEmpty
                            ? cs.onSurfaceVariant
                            : cs.onSurface,
                      ),
                      const SizedBox(width: MitlistSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '$when · ${event.calendar.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: muted,
                            ),
                            // Never cut: the reason something is busy.
                            for (final n in notes)
                              Text(n,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurface,
                                      fontStyle: FontStyle.italic)),
                            Text(
                              sees,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: seeLines.isEmpty
                                    ? cs.onSurfaceVariant
                                    : cs.onSurface,
                              ),
                            ),
                            Text(
                              l10n.sharedCalendarsEventChoice(choice),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: cs.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        KeyedSubtree(
          key: hideKey,
          child: IconButton(
            key: ValueKey('quick-hide-${event.calendar.id}-${event.uid}'),
            tooltip: hidden
                ? l10n.sharedCalendarsShowAgain
                : l10n.sharedCalendarsHideEvent,
            icon: AppIcon(
              name: hidden ? 'eye' : 'eyeSlash',
              color: cs.onSurface,
            ),
            onPressed: () => onQuickHide(hidden ? null : EventOverride.hidden),
          ),
        ),
      ],
    );
  }
}

/// Hidden / Busy / With title, or back to the calendar's setting.
class _OverridePicker extends StatelessWidget {
  const _OverridePicker({required this.current, required this.onPick});

  final EventOverride? current;
  final void Function(EventOverride?) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final options = <(EventOverride?, String, String)>[
      (
        null,
        l10n.sharedCalendarsOverrideCalendar,
        l10n.sharedCalendarsOverrideCalendarDesc
      ),
      (
        EventOverride.hidden,
        l10n.sharedCalendarsOverrideHidden,
        l10n.sharedCalendarsOverrideHiddenDesc
      ),
      (
        EventOverride.busy,
        l10n.sharedCalendarsOverrideBusy,
        l10n.sharedCalendarsOverrideBusyDesc
      ),
      (
        EventOverride.details,
        l10n.sharedCalendarsOverrideDetails,
        l10n.sharedCalendarsOverrideDetailsDesc
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (value, label, desc) in options)
          Semantics(
            button: true,
            selected: value == current,
            label: '$label. $desc',
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey('override-${value?.name ?? 'calendar'}'),
              onTap: () => onPick(value),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: value == current
                            ? AppIcon(
                                name: 'check',
                                color: theme.colorScheme.primary,
                              )
                            : null,
                      ),
                      const SizedBox(width: MitlistSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium),
                            Text(
                              desc,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
