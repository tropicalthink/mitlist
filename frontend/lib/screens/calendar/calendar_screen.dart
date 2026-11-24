import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/calendar_models.dart';
import '../../models/group_models.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/external_calendar_provider.dart';
import '../../providers/list_provider.dart' show sseServiceProvider;
import '../../providers/presence_provider.dart' show boardMembersProvider;
import '../../services/sse_service.dart';
import '../../utils/household_availability.dart';
import '../../utils/hub_helpers.dart' show avatarInitials;
import '../../providers/chore_provider.dart';
import '../../providers/finance_provider.dart' show financeServiceProviderAsync;
import '../../providers/group_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../services/group_id_validator.dart';
import '../../theme/colors.dart';
import '../../theme/member_colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../theme/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/active_group_context.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../sheets/expense_creation_sheet.dart';
import '../../sheets/chore_creation_sheet.dart';
import '../../sheets/chore_detail_sheet.dart';
import '../../sheets/create_household_sheet.dart';

import '../../widgets/app_toast.dart';
import '../../widgets/calendar_tour.dart';
import '../../services/calendar_tour.dart' show calendarTourProvider;

enum _CalendarView { week, month, agenda }

/// Single source of truth for how each event type is drawn (icon + accent).
/// Shared by the month dots, the agenda rows, and the week-view event rows so
/// the three never drift apart.
({IconData icon, Color color}) _eventVisual(
    ColorScheme cs, CalendarEventType type) {
  return switch (type) {
    CalendarEventType.mealPlan => (icon: Icons.restaurant, color: cs.primary),
    CalendarEventType.chore => (
        icon: Icons.cleaning_services,
        color: cs.secondary
      ),
    CalendarEventType.recurringExpense => (
        icon: Icons.repeat,
        color: cs.tertiary
      ),
    CalendarEventType.expense => (
        icon: Icons.receipt_outlined,
        color: cs.secondary
      ),
    CalendarEventType.pinwallReminder => (
        icon: Icons.push_pin_outlined,
        color: cs.error
      ),
    CalendarEventType.listReminder => (
        icon: Icons.notifications_active_outlined,
        color: cs.error
      ),
    CalendarEventType.externalEvent => (
        icon: Icons.event_available_outlined,
        color: cs.tertiary
      ),
  };
}

/// The words a housemate's shared event shows: its title when the household
/// may see it, otherwise the localized "Busy". Never anything else.
String _externalEventText(CalendarEvent event, AppLocalizations l10n) {
  final busyOnly = event.external?.busyOnly ?? true;
  if (busyOnly || event.title.trim().isEmpty) return l10n.calendarExternalBusy;
  return event.title;
}

/// When a shared event happens on [day]: "All day", a time range, or "from"
/// / "until" for the first and last day of an event that spans midnight.
String _externalTimeLabel(
  CalendarExternalEvent x,
  DateTime day,
  String localeName,
  AppLocalizations l10n,
) {
  if (x.allDay) return l10n.calendarExternalAllDay;
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = DateTime(day.year, day.month, day.day + 1);
  final start = x.startsAt.toLocal();
  final end = x.endsAt.toLocal();
  final startsBefore = start.isBefore(dayStart);
  final endsAfter = end.isAfter(dayEnd);
  final fmt = DateFormat.jm(localeName);
  if (startsBefore && (endsAfter || end == dayEnd)) {
    return l10n.calendarExternalAllDay;
  }
  if (startsBefore) return l10n.calendarExternalUntil(fmt.format(end));
  if (endsAfter || (end == dayEnd && end.isAfter(start))) {
    return l10n.calendarExternalFrom(fmt.format(start));
  }
  return l10n.calendarExternalTimeRange(fmt.format(start), fmt.format(end));
}

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  bool _isSaving = false;
  _CalendarView _viewMode = _CalendarView.week;

  // Navigation anchors. `_weekAnchor` is any day in the viewed week; the actual
  // week start is derived from the locale's first-day-of-week at build time so
  // it stays correct if the locale changes. `_agendaAnchor` is captured once so
  // the agenda range key is stable across rebuilds (using DateTime.now() in the
  // provider key would refetch every frame).
  late DateTime _weekAnchor;
  late DateTime _monthStart;
  late final DateTime _agendaAnchor;

  // Derived, memoized from the last successfully-loaded events. Rebuilt only
  // when the events list identity changes — not on every cell access.
  List<CalendarEvent>? _lastEvents;
  List<CalendarEvent>? _indexedFrom;
  Map<DateTime, List<CalendarEvent>> _eventsByDay = const {};
  List<MapEntry<DateTime, List<CalendarEvent>>> _sortedDays = const [];
  Object? _lastErrorShown;

  /// The day the "who's around" summary describes (week view).
  late DateTime _selectedDay;

  // Live updates: a housemate's shared calendar changed.
  StreamSubscription<SseEvent>? _liveSub;
  String? _liveGroupId;
  Timer? _liveDebounce;
  bool _shareHintDismissed = true;

  static const _shareHintPref = calendarShareHintPref;

  final _shareButtonKey = GlobalKey(debugLabel: 'calendar-share-button');
  bool _tourChecked = false;

  /// Picks up the tour when Home just handed it over.
  void _maybeContinueTour() {
    if (_tourChecked) return;
    _tourChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(continueCalendarTourOnCalendar(context, ref,
          shareButton: _shareButtonKey));
    });
  }

  // Who is who, for housemates' shared events (refreshed every build).
  Map<String, String> _memberNames = const {};
  String? _meId;

  String _personName(String userId, AppLocalizations l10n) {
    if (userId == _meId) return l10n.calendarExternalYou;
    final name = _memberNames[userId];
    return name == null || name.isEmpty ? l10n.calendarExternalSomeone : name;
  }

  /// Members who share a calendar with this household, in roster order.
  List<String> _sharers(String? groupId) {
    final ids = <String>{
      for (final e in _lastEvents ?? const <CalendarEvent>[])
        if (e.type == CalendarEventType.externalEvent && e.external != null)
          e.external!.userId,
    };
    if (groupId != null && _meId != null && _iShareWith(groupId) == true) {
      ids.add(_meId!);
    }
    final ordered = <String>[
      for (final id in _memberNames.keys)
        if (ids.contains(id)) id,
    ];
    for (final id in ids) {
      if (!ordered.contains(id)) ordered.add(id);
    }
    return ordered;
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _weekAnchor = today;
    _monthStart = DateTime(now.year, now.month, 1);
    _agendaAnchor = today;
    _selectedDay = today;
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString('calendar_view_mode');
      if (!mounted) return;
      final dismissed = prefs.getBool(_shareHintPref) ?? false;
      if (dismissed != _shareHintDismissed) {
        setState(() => _shareHintDismissed = dismissed);
      }
      if (saved == 'month') setState(() => _viewMode = _CalendarView.month);
      if (saved == 'agenda') setState(() => _viewMode = _CalendarView.agenda);
    });
  }

  // ── First-day-of-week (locale-aware) ──────────────────────────────────────

  /// Locale's first weekday in DateTime numbering (1 = Mon .. 7 = Sun).
  int get _firstDow {
    // MaterialLocalizations: 0 = Sunday .. 6 = Saturday.
    final idx = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    return idx == 0 ? DateTime.sunday : idx;
  }

  DateTime _weekStartForDay(DateTime day, int firstDow) {
    final base = DateTime(day.year, day.month, day.day);
    final diff = (base.weekday - firstDow) % 7; // Dart % is always non-negative
    return base.subtract(Duration(days: diff));
  }

  DateTime get _weekStart => _weekStartForDay(_weekAnchor, _firstDow);

  // ── Range + fetch ─────────────────────────────────────────────────────────

  CalendarRange _rangeFor(String groupId) {
    final DateTime from;
    final DateTime to;
    switch (_viewMode) {
      case _CalendarView.month:
        from = DateTime(_monthStart.year, _monthStart.month, 1);
        to = DateTime(_monthStart.year, _monthStart.month + 1, 0);
      case _CalendarView.agenda:
        from = _agendaAnchor.subtract(const Duration(days: 30));
        to = _agendaAnchor.add(const Duration(days: 120));
      case _CalendarView.week:
        final ws = _weekStart;
        from = ws;
        to = ws.add(const Duration(days: 6));
    }
    return (groupId: groupId, from: from, to: to);
  }

  Future<void> _refresh(CalendarRange range) =>
      ref.refresh(calendarEventsProvider(range).future);

  void _rebuildIndex(List<CalendarEvent> events) {
    final map = <DateTime, List<CalendarEvent>>{};
    for (final e in events) {
      // A housemate's shared event arrives once; it belongs on every day it
      // covers (a weekend away, an overnight shift).
      final x = e.external;
      if (e.type == CalendarEventType.externalEvent && x != null) {
        for (final d in x.days) {
          map.putIfAbsent(d, () => []).add(e);
        }
        continue;
      }
      // Bucket by LOCAL day. The server sends full timestamps (often UTC), so
      // without toLocal() an event late in the day lands on the wrong calendar
      // day relative to the local "today".
      final local = e.date.toLocal();
      final d = DateTime(local.year, local.month, local.day);
      map.putIfAbsent(d, () => []).add(e);
    }
    _eventsByDay = map;
    _sortedDays = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  void _maybeShowErrorSnack(AppLocalizations l10n, Object? err) {
    if (err == null || identical(err, _lastErrorShown)) return;
    _lastErrorShown = err;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppToast.error(context, friendlyErrorMessage(err, l10n));
    });
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _liveDebounce?.cancel();
    super.dispose();
  }

  /// Refetch when a housemate's shared calendar changes for [groupId].
  void _attachLive(String groupId) {
    if (_liveGroupId == groupId) return;
    _liveGroupId = groupId;
    unawaited(_liveSub?.cancel());
    final sse = ref.read(sseServiceProvider);
    unawaited(sse.connect(groupId));
    _liveSub = sse.events.listen((event) {
      if (event.type != 'calendar:external_changed' ||
          event.groupId != groupId) {
        return;
      }
      // A sync can touch several households at once; refetch once.
      _liveDebounce?.cancel();
      _liveDebounce = Timer(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        // Drop what the cache knows about shared calendars first, so a
        // refetch that fails (offline) cannot fall back to stale events.
        final repo = ref.read(calendarRepositoryProvider).valueOrNull;
        final forget = repo?.forgetExternal(groupId) ?? Future<void>.value();
        unawaited(forget.catchError((Object _) {}).whenComplete(() {
          if (mounted) ref.invalidate(calendarEventsProvider);
        }));
      });
    });
  }

  /// Whether the person shares any calendar with [groupId] (null: unknown).
  bool? _iShareWith(String groupId) {
    final connections = ref.watch(calendarConnectionsProvider).valueOrNull;
    if (connections == null) return null;
    for (final c in connections) {
      for (final cal in c.calendars) {
        if (cal.shareFor(groupId) != null) return true;
      }
    }
    return false;
  }

  Future<void> _dismissShareHint() async {
    setState(() => _shareHintDismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shareHintPref, true);
  }

  void _openSharedCalendars() {
    unawaited(Haptics.light());
    context.pushNamed('sharedCalendars');
  }

  // ── Navigation (no fetch — the watched provider re-keys and caches) ────────

  void _prevWeek() => setState(
      () => _weekAnchor = _weekAnchor.subtract(const Duration(days: 7)));
  void _nextWeek() =>
      setState(() => _weekAnchor = _weekAnchor.add(const Duration(days: 7)));

  void _prevMonth() => setState(
      () => _monthStart = DateTime(_monthStart.year, _monthStart.month - 1, 1));
  void _nextMonth() => setState(
      () => _monthStart = DateTime(_monthStart.year, _monthStart.month + 1, 1));

  void _next() {
    unawaited(Haptics.light());
    if (_viewMode == _CalendarView.week) {
      _nextWeek();
    } else if (_viewMode == _CalendarView.month) {
      _nextMonth();
    }
  }

  void _prev() {
    unawaited(Haptics.light());
    if (_viewMode == _CalendarView.week) {
      _prevWeek();
    } else if (_viewMode == _CalendarView.month) {
      _prevMonth();
    }
  }

  void _goToToday() {
    unawaited(Haptics.light());
    final now = DateTime.now();
    setState(() {
      _weekAnchor = DateTime(now.year, now.month, now.day);
      _selectedDay = DateTime(now.year, now.month, now.day);
      _monthStart = DateTime(now.year, now.month, 1);
    });
  }

  void _setViewMode(_CalendarView mode) {
    if (mode == _viewMode) return;
    unawaited(Haptics.light());
    setState(() => _viewMode = mode);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('calendar_view_mode', mode.name);
    });
  }

  void _openWeekForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    setState(() {
      _weekAnchor = d;
      _selectedDay = d;
      _viewMode = _CalendarView.week;
    });
    _scrollToDay(d);
  }

  /// Selects [day] for "who's around" (pinned above the week) and brings
  /// its card into view.
  void _selectDay(DateTime day) {
    unawaited(Haptics.light());
    setState(() => _selectedDay = day);
    _scrollToDay(day);
  }

  void _scrollToDay(DateTime day) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _dayKeys[day]?.currentContext;
      if (ctx == null || !mounted) return;
      unawaited(Scrollable.ensureVisible(
        ctx,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 250),
      ));
      unawaited(Scrollable.ensureVisible(
        ctx,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        duration: Duration.zero,
      ));
    });
  }

  final Map<DateTime, GlobalKey> _dayKeys = {};
  GlobalKey _dayKey(DateTime day) => _dayKeys.putIfAbsent(day, GlobalKey.new);

  List<String> get _roster => _memberNames.keys.toList();

  // ── Labels ─────────────────────────────────────────────────────────────────

  String _weekLabel(AppLocalizations l10n) {
    final ws = _weekStart;
    final end = ws.add(const Duration(days: 6));
    final weekStartStr = DateFormat.MMMd(_localeName).format(ws);
    final weekEndStr = DateFormat.yMMMd(_localeName).format(end);
    return l10n.calendarWeekHeader(weekStartStr, weekEndStr);
  }

  String _monthLabel(AppLocalizations l10n) {
    final months = _months(l10n);
    return l10n.calendarMonthHeader(
        months[_monthStart.month - 1], _monthStart.year);
  }

  List<String> _months(AppLocalizations l10n) => [
        l10n.calendarMonthJanuary,
        l10n.calendarMonthFebruary,
        l10n.calendarMonthMarch,
        l10n.calendarMonthApril,
        l10n.calendarMonthMay,
        l10n.calendarMonthJune,
        l10n.calendarMonthJuly,
        l10n.calendarMonthAugust,
        l10n.calendarMonthSeptember,
        l10n.calendarMonthOctober,
        l10n.calendarMonthNovember,
        l10n.calendarMonthDecember,
      ];

  List<String> _weekdayHeaders(AppLocalizations l10n) {
    final base = [
      l10n.calendarShortMon,
      l10n.calendarShortTue,
      l10n.calendarShortWed,
      l10n.calendarShortThu,
      l10n.calendarShortFri,
      l10n.calendarShortSat,
      l10n.calendarShortSun,
    ];
    final start = _firstDow - 1; // 0-based Monday index
    return [for (var i = 0; i < 7; i++) base[(start + i) % 7]];
  }

  String get _localeName => Localizations.localeOf(context).toString();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.calendarAppBarTitle,
        showStandardActions: false,
        actions: [
          IconButton(
            key: _shareButtonKey,
            icon: const AppIcon(name: 'userGroup'),
            tooltip: l10n.sharedCalendarsTitle,
            onPressed: _openSharedCalendars,
          ),
          TextButton(
            onPressed: _goToToday,
            child: Text(l10n.calendarToday),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    final groupsAsync = ref.watch(cachedGroupsProvider);

    final groups = groupsAsync.valueOrNull;
    if (groups == null) {
      if (groupsAsync.hasError) return _errorState(l10n, groupsAsync.error);
      return _skeletonFor(_viewMode);
    }

    final groupId =
        resolveActiveGroupId(groups, ref.watch(currentGroupIdProvider));
    if (!isValidGroupId(groupId)) return _noHouseholdState(l10n);

    final range = _rangeFor(groupId!);
    final eventsAsync = ref.watch(calendarEventsProvider(range));
    _attachLive(groupId);
    final members = ref.watch(boardMembersProvider(groupId)).valueOrNull ??
        const <GroupMemberProfile>[];
    _memberNames = {for (final m in members) m.userId: m.displayName};
    _meId = ref.watch(currentUserIdProvider).valueOrNull;
    final iShare = _iShareWith(groupId);

    // Adopt new data + reindex only when it actually changes.
    final data = eventsAsync.valueOrNull;
    if (data != null && !identical(data, _indexedFrom)) {
      _indexedFrom = data;
      _lastEvents = data;
      _rebuildIndex(data);
    }
    if (eventsAsync.hasError) _maybeShowErrorSnack(l10n, eventsAsync.error);

    final hasData = _lastEvents != null;
    if (!hasData) {
      if (eventsAsync.hasError) return _errorState(l10n, eventsAsync.error);
      return _skeletonFor(_viewMode);
    }

    final refreshing = eventsAsync.isLoading;
    final anyoneShares =
        _lastEvents!.any((e) => e.type == CalendarEventType.externalEvent);
    // The tour points at the same thing: never both.
    final tourRunning = ref.read(calendarTourProvider.notifier).active;
    final showShareHint = !_shareHintDismissed &&
        !tourRunning &&
        iShare == false &&
        !anyoneShares;
    _maybeContinueTour();
    return Column(
      children: [
        _buildViewToggle(),
        if (showShareHint)
          _ShareCalendarHint(
            onOpen: _openSharedCalendars,
            onDismiss: () => unawaited(_dismissShareHint()),
          ),
        // Thin, non-destructive refresh hint: the last-good calendar stays put
        // while the next range loads instead of blanking to skeletons.
        SizedBox(
          height: 2,
          child:
              refreshing ? const LinearProgressIndicator(minHeight: 2) : null,
        ),
        Expanded(child: _buildActiveView(range)),
      ],
    );
  }

  Widget _buildActiveView(CalendarRange range) {
    switch (_viewMode) {
      case _CalendarView.week:
        return _horizontalSwipe(
          RefreshIndicator(
            onRefresh: () => _refresh(range),
            child: _buildWeekView(),
          ),
        );
      case _CalendarView.month:
        return _horizontalSwipe(
          RefreshIndicator(
            onRefresh: () => _refresh(range),
            child: _buildMonthView(),
          ),
        );
      case _CalendarView.agenda:
        return RefreshIndicator(
          onRefresh: () => _refresh(range),
          child: _buildAgendaView(),
        );
    }
  }

  Widget _horizontalSwipe(Widget child) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() < 200) return;
        if (v < 0) {
          _next();
        } else {
          _prev();
        }
      },
      child: child,
    );
  }

  // ── Non-content states ─────────────────────────────────────────────────────

  Widget _skeletonFor(_CalendarView view) {
    if (view == _CalendarView.month) {
      return GridView.builder(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 0.9,
          mainAxisSpacing: MitlistSpacing.xs,
          crossAxisSpacing: MitlistSpacing.xs,
        ),
        itemCount: 35,
        itemBuilder: (_, __) =>
            AppSkeleton(width: double.infinity, height: double.infinity),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      itemCount: 7,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: MitlistSpacing.sm),
        child: AppSkeleton(width: double.infinity, height: 80),
      ),
    );
  }

  Widget _errorState(AppLocalizations l10n, Object? error) {
    return Center(
      child: AppEmptyState(
        lottieAsset: 'assets/animations/lottie/404.lottie',
        icon: AppIcon(name: 'alertCircleOutline'),
        title: l10n.commonSomethingWentWrong,
        description: error == null ? null : friendlyErrorMessage(error, l10n),
        actions: [
          AppButton(
            variant: AppButtonVariant.outline,
            text: l10n.commonRetry,
            onPressed: () {
              // An explicit Retry means the user wants a real network attempt,
              // not the cache we already failed with.
              unawaited(refreshCachedGroups(ref).catchError((_) {}));
              ref.invalidate(calendarEventsProvider);
            },
          ),
        ],
      ),
    );
  }

  Widget _noHouseholdState(AppLocalizations l10n) {
    return Center(
      child: AppEmptyState(
        lottieAsset: 'assets/animations/lottie/House.lottie',
        icon: const AppIcon(name: 'homeOutline'),
        title: l10n.commonNoHousehold,
        description: l10n.calendarNoHouseholdDesc,
        actions: [
          AppButton(
            text: l10n.calendarCreateHousehold,
            onPressed: () async {
              await CreateHouseholdSheet.show(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    final l10n = AppLocalizations.of(context)!;
    final tabs = <(_CalendarView, String, String)>[
      (_CalendarView.week, l10n.calendarViewWeek, l10n.calendarWeekView),
      (_CalendarView.month, l10n.calendarViewMonth, l10n.calendarMonthView),
      (_CalendarView.agenda, l10n.calendarViewAgenda, l10n.calendarAgendaView),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
      child: Row(
        children: [
          for (final (mode, label, semanticLabel) in tabs)
            Expanded(
              child: _ViewTab(
                label: label,
                semanticLabel: semanticLabel,
                selected: _viewMode == mode,
                onTap: () => _setViewMode(mode),
              ),
            ),
        ],
      ),
    );
  }

  // ── Week View ───────────────────────────────────────────────────────────

  bool get _weekHasEvents {
    final ws = _weekStart;
    for (var i = 0; i < 7; i++) {
      final day = ws.add(Duration(days: i));
      if ((_eventsByDay[day]?.isNotEmpty) ?? false) return true;
    }
    return false;
  }

  Widget _weekHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
      child: Row(
        children: [
          IconButton(
            icon: AppIcon(name: 'chevronLeft'),
            tooltip: l10n.calendarPreviousWeek,
            onPressed: _prevWeek,
          ),
          Expanded(
            child: Text(
              _weekLabel(l10n),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          IconButton(
            icon: AppIcon(name: 'chevronRight'),
            tooltip: l10n.calendarNextWeek,
            onPressed: _nextWeek,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekView() {
    final l10n = AppLocalizations.of(context)!;
    final ws = _weekStart;
    if (!_weekHasEvents) {
      // Keep the header (so navigation still works) and offer a single empty
      // affordance instead of seven "Nothing planned" cards. Scrollable so
      // pull-to-refresh still works.
      return Column(
        children: [
          _weekHeader(l10n),
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: MitlistSpacing.xl),
                _EmptyRange(
                  title: l10n.calendarNothingAhead,
                  description: l10n.calendarNothingAheadDesc,
                  onAddChore: _addChore,
                ),
              ],
            ),
          ),
        ],
      );
    }
    final sharers = _sharers(_liveGroupId);
    final weekDays = [for (var i = 0; i < 7; i++) ws.add(Duration(days: i))];
    final now = DateTime.now();
    final todayDay = DateTime(now.year, now.month, now.day);
    final selected = weekDays.contains(_selectedDay)
        ? _selectedDay
        : (weekDays.contains(todayDay) ? todayDay : ws);
    final hasAround = sharers.isNotEmpty;
    final around = hasAround
        ? whosAround(
            selected,
            _eventsByDay[selected] ?? const [],
            sharers,
            members: _memberNames.keys,
            now: selected == todayDay ? now : null,
          )
        : const <MemberAround>[];
    final screenHeight = MediaQuery.sizeOf(context).height;
    return Column(
      children: [
        _weekHeader(l10n),
        if (hasAround)
          // Pinned: picking a day further down keeps its summary in sight.
          Padding(
            padding: const EdgeInsets.fromLTRB(
                MitlistSpacing.md, 0, MitlistSpacing.md, MitlistSpacing.sm),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screenHeight * 0.4),
              child: SingleChildScrollView(
                child: _WhosAroundCard(
                  day: selected,
                  around: around,
                  evening: householdEvening(selected, around,
                      now: selected == todayDay ? now : null),
                  nameFor: (id) => _personName(id, l10n),
                  roster: _roster,
                  expanded: ref.watch(whosAroundExpandedProvider),
                  onToggle: () => ref
                      .read(whosAroundExpandedProvider.notifier)
                      .update((v) => !v),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              for (final day in weekDays)
                _DayCard(
                  key: _dayKey(day),
                  day: day,
                  events: _eventsByDay[day] ?? const [],
                  isToday: _isToday(day),
                  isSelected: hasAround && day == selected,
                  onSelect: hasAround ? () => _selectDay(day) : null,
                  personName: (id) => _personName(id, l10n),
                  roster: _roster,
                  onEventTap: (e) => _showEventDetail(context, e),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Month View ──────────────────────────────────────────────────────────

  Widget _buildMonthView() {
    final l10n = AppLocalizations.of(context)!;
    final daysInMonth =
        DateTime(_monthStart.year, _monthStart.month + 1, 0).day;
    final firstDow = _firstDow;
    final leading = (_monthStart.weekday - firstDow) % 7;
    final totalCells = ((leading + daysInMonth) / 7).ceil() * 7;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
          child: Row(
            children: [
              IconButton(
                icon: AppIcon(name: 'chevronLeft'),
                tooltip: l10n.calendarPreviousMonth,
                onPressed: _prevMonth,
              ),
              Expanded(
                child: Text(
                  _monthLabel(l10n),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              IconButton(
                icon: AppIcon(name: 'chevronRight'),
                tooltip: l10n.calendarNextMonth,
                onPressed: _nextMonth,
              ),
            ],
          ),
        ),
        // Weekday headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
          child: Row(
            children: _weekdayHeaders(l10n)
                .map((h) => Expanded(
                      child: Center(
                        child: Text(
                          h,
                          style: MitlistTypography.labelXSmall(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Expanded(
          child: ListView(
            // A ListView (not a bare Center) so pull-to-refresh works on an
            // empty month too.
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: MitlistSpacing.sm),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: totalCells,
                      itemBuilder: (context, index) {
                        final dayNum = index - leading + 1;
                        if (dayNum < 1 || dayNum > daysInMonth) {
                          return const SizedBox.shrink();
                        }
                        return _buildMonthCell(l10n, dayNum);
                      },
                    ),
                  ),
                ),
              ),
              if (_eventsByDay.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(MitlistSpacing.lg),
                  child: Text(
                    l10n.calendarNothingAhead,
                    textAlign: TextAlign.center,
                    style: MitlistTypography.labelXSmall(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthCell(AppLocalizations l10n, int dayNum) {
    final day = DateTime(_monthStart.year, _monthStart.month, dayNum);
    final dayEvents = _eventsByDay[day] ?? const [];
    final isToday = _isToday(day);
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: dayEvents.isEmpty
          ? l10n.calendarDayLabel(day.day)
          : '${l10n.calendarDayLabel(day.day)}, '
              '${l10n.calendarDayEvents(dayEvents.length)}',
      hint: l10n.calendarDayMenuHint,
      child: GestureDetector(
        // onLongPressStart carries the finger's global position, so the menu
        // anchors to the pressed cell instead of screen-center.
        onLongPressStart: (details) =>
            _showDayMenu(context, day, dayEvents, details.globalPosition),
        child: InkWell(
          onTap: () => _openWeekForDay(day),
          borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
          child: Container(
            margin: const EdgeInsets.all(MitlistSpacing.space0_5),
            decoration: BoxDecoration(
              color: isToday ? cs.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
              border: Border.all(
                color: isToday ? cs.primary : cs.outlineVariant,
                width: isToday ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: MitlistSpacing.xs),
                Text(
                  '$dayNum',
                  style: MitlistTypography.labelXSmall(
                    color: isToday ? cs.primary : cs.onSurface,
                  ),
                ),
                if (dayEvents.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.only(top: MitlistSpacing.space0_5),
                    child: _MonthDots(events: dayEvents),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDayMenu(
    BuildContext ctx,
    DateTime day,
    List<CalendarEvent> events,
    Offset position,
  ) {
    unawaited(Haptics.light());
    final l10n = AppLocalizations.of(context)!;
    final dayLabel = DateFormat.yMMMMEEEEd(_localeName).format(day);

    showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          enabled: false,
          height: 44,
          child: Text(
            dayLabel,
            style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        if (events.isNotEmpty)
          ...events.map((e) {
            final label = e.type == CalendarEventType.externalEvent
                ? '${_personName(e.external!.userId, l10n)}: '
                    '${_externalEventText(e, l10n)}'
                : (e.title.isNotEmpty ? e.title : e.type.name);
            return PopupMenuItem<String>(
              value: 'event_${e.id}',
              onTap: () => _showEventDetail(context, e),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          }),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'add_chore',
          child: Text(l10n.calendarAddChore),
        ),
        PopupMenuItem<String>(
          value: 'add_expense',
          child: Text(l10n.calendarAddExpense),
        ),
        PopupMenuItem<String>(
          value: 'view_week',
          child: Text(l10n.calendarViewInWeek),
        ),
      ],
    ).then((value) {
      if (value == null || !mounted) return;
      switch (value) {
        case 'view_week':
          _openWeekForDay(day);
        case 'add_chore':
          // Don't stuff the date into the chore's title. (Pre-filling the due
          // date is a follow-up once the sheet exposes it.)
          _addChore();
        case 'add_expense':
          unawaited(_addExpense());
      }
    });
  }

  /// The empty calendar's one action: chores are the most common dated item.
  void _addChore() {
    unawaited(Haptics.light());
    ChoreCreationSheet.show(context);
  }

  /// One expense added from the calendar is a complete entry session: release
  /// its notification right away instead of waiting for the fallback window.
  Future<void> _addExpense() async {
    final created = await ExpenseCreationSheet.show(context);
    if (created != true || !mounted) return;
    final groupId = resolveActiveGroupId(
        ref.read(cachedGroupsProvider).valueOrNull ?? const [],
        ref.read(currentGroupIdProvider));
    if (groupId == null) return;
    final service = await ref.read(financeServiceProviderAsync.future);
    unawaited(service.flushExpenseNotifications(groupId));
  }

  // ── Agenda View ─────────────────────────────────────────────────────────

  Widget _buildAgendaView() {
    final l10n = AppLocalizations.of(context)!;
    if (_sortedDays.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: MitlistSpacing.xl),
          Center(
            child: AppEmptyState(
              lottieAsset: 'assets/animations/lottie/Calendar.lottie',
              icon: AppIcon(name: 'eventNote', size: 56),
              title: l10n.calendarNothingAhead,
              description: '${l10n.calendarNothingAheadDesc}\n'
                  '${l10n.calendarLongPressHint}',
              actions: [
                AppButton(
                  text: l10n.calendarAddChore,
                  icon: const AppIcon(name: 'plus'),
                  onPressed: _addChore,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _sortedDays.length,
      itemBuilder: (context, index) {
        final entry = _sortedDays[index];
        final day = entry.key;
        final dayEvents = entry.value;
        final isToday = _isToday(day);

        return Padding(
          padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isToday)
                    Container(
                      width: MitlistSpacing.space2,
                      height: MitlistSpacing.space2,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      margin: const EdgeInsets.only(right: MitlistSpacing.sm),
                    ),
                  Text(
                    _formatAgendaDate(day, l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: isToday
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: MitlistSpacing.sm),
              ..._agendaDayEvents(day, dayEvents, l10n),
            ],
          ),
        );
      },
    );
  }

  String _formatAgendaDate(DateTime day, AppLocalizations l10n) {
    if (_isToday(day)) return l10n.calendarToday;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (day.year == tomorrow.year &&
        day.month == tomorrow.month &&
        day.day == tomorrow.day) {
      return l10n.calendarTomorrow;
    }
    return DateFormat.MMMMEEEEd(_localeName).format(day);
  }

  List<Widget> _agendaDayEvents(
      DateTime day, List<CalendarEvent> events, AppLocalizations l10n) {
    return events.map((e) {
      if (e.type == CalendarEventType.externalEvent && e.external != null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
          child: _ExternalEventRow(
            event: e,
            day: day,
            personName: _personName(e.external!.userId, l10n),
            roster: _roster,
            onTap: () => _showEventDetail(context, e),
          ),
        );
      }
      final (icon, color, label) = _eventMeta(context, e, l10n);
      return Padding(
        padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
        child: InkWell(
          onTap: () => _showEventDetail(context, e),
          borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: MitlistSpacing.xs,
              horizontal: MitlistSpacing.xs,
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: Text(
                    e.title.isNotEmpty ? e.title : label,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (e.type == CalendarEventType.mealPlan && e.mealPlan != null)
                  Text(
                    l10n.calendarServingsPpl(e.mealPlan!.servings),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MitlistTypography.labelXSmall(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (e.type == CalendarEventType.recurringExpense &&
                    e.recurringExpense != null)
                  Text(
                    (e.recurringExpense!.amount / 100).toStringAsFixed(2),
                    style: MitlistTypography.monoBody(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  (IconData, Color, String) _eventMeta(
      BuildContext context, CalendarEvent event, AppLocalizations l10n) {
    final visual = _eventVisual(Theme.of(context).colorScheme, event.type);
    final label = switch (event.type) {
      CalendarEventType.mealPlan =>
        event.mealPlan?.slot ?? l10n.calendarEventMeal,
      CalendarEventType.chore => l10n.calendarEventChore,
      CalendarEventType.recurringExpense => l10n.calendarEventRecurring,
      CalendarEventType.expense => l10n.calendarEventExpense,
      CalendarEventType.pinwallReminder => l10n.calendarEventReminder,
      CalendarEventType.listReminder => l10n.calendarEventListReminder,
      CalendarEventType.externalEvent => l10n.calendarExternalBusy,
    };
    return (visual.icon, visual.color, label);
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  void _showEventDetail(BuildContext context, CalendarEvent event) {
    final l10n = AppLocalizations.of(context)!;
    switch (event.type) {
      case CalendarEventType.chore:
        if (event.chore != null) {
          ChoreDetailSheet.show(
            context,
            choreId: event.chore!.choreId,
            title:
                event.title.isNotEmpty ? event.title : l10n.calendarEventChore,
            statusLabel: event.chore!.status,
            assignee: '',
            dueDate: event.date,
            onDelete: () => _deleteChore(event.chore!.choreId, event.groupId),
          );
        }
      case CalendarEventType.mealPlan:
        context.pushNamed('mealPlan');
      case CalendarEventType.recurringExpense:
        context.pushNamed('recurringExpenses');
      case CalendarEventType.expense:
        context.pushNamed('money');
      case CalendarEventType.pinwallReminder:
        // Reminders live on the pinwall (home tab); take the user there.
        context.goNamed('home');
      case CalendarEventType.listReminder:
        final listId = event.listReminder?.listId;
        if (listId != null && listId.isNotEmpty) {
          context.pushNamed('listDetail', pathParameters: {'listId': listId});
        }
      case CalendarEventType.externalEvent:
        // Only the owner can do anything with it: open their settings.
        // A housemate's block has nothing more to show.
        if (event.external?.userId == _meId) _openSharedCalendars();
    }
  }

  /// Runs once the detail sheet has already confirmed the delete with the
  /// user, so it closes the sheet and deletes without asking again. The
  /// delete is queued (it works offline); the calendar drops the chore's
  /// events while it waits, see `CalendarRepository`.
  Future<void> _deleteChore(String choreId, String groupId) async {
    if (_isSaving) return;
    _isSaving = true;
    Navigator.of(context).pop();
    try {
      final repo = await ref.read(choreRepositoryProvider.future);
      await repo.deleteOfflineFirst(choreId, groupId: groupId);
      // Refetch the affected range(s). Invalidating the whole family is simple
      // and correct — the visible range reloads, others drop their cache.
      ref.invalidate(calendarEventsProvider);
    } catch (e) {
      if (!mounted) return;
      unawaited(Haptics.failure());
      AppToast.error(
          context, friendlyErrorMessage(e, AppLocalizations.of(context)!));
    } finally {
      _isSaving = false;
    }
  }
}

/// Up to four coloured dots (one per distinct event type) with a "+" overflow —
/// a truthful density hint, unlike a single count tinted by the first event.
class _MonthDots extends StatelessWidget {
  final List<CalendarEvent> events;

  const _MonthDots({required this.events});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final types = <CalendarEventType>[];
    for (final e in events) {
      if (!types.contains(e.type)) types.add(e.type);
    }
    const maxDots = 4;
    final shown = types.take(maxDots).toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final t in shown)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: _eventVisual(cs, t).color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        if (types.length > maxDots)
          Text(
            '+',
            style: MitlistTypography.labelXSmall(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// Centered empty affordance for a week/month range with no events.
class _EmptyRange extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onAddChore;

  const _EmptyRange({
    required this.title,
    required this.description,
    required this.onAddChore,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: AppEmptyState(
        lottieAsset: 'assets/animations/lottie/Calendar.lottie',
        icon: AppIcon(name: 'eventNote', size: 56),
        title: title,
        description: '$description\n${l10n.calendarLongPressHint}',
        actions: [
          AppButton(
            text: l10n.calendarAddChore,
            icon: const AppIcon(name: 'plus'),
            onPressed: onAddChore,
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final DateTime day;
  final List<CalendarEvent> events;
  final bool isToday;
  final bool isSelected;

  /// Shows this day in the "who's around" summary; null when nobody shares.
  final VoidCallback? onSelect;
  final String Function(String userId) personName;
  final List<String> roster;
  final void Function(CalendarEvent)? onEventTap;

  const _DayCard({
    super.key,
    required this.day,
    required this.events,
    required this.isToday,
    required this.personName,
    required this.roster,
    this.isSelected = false,
    this.onSelect,
    this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final localeName = Localizations.localeOf(context).toString();
    final weekday = DateFormat.EEEE(localeName).format(day);

    final cs = Theme.of(context).colorScheme;
    // One cue each: today is the "Today" badge only; the selected day (the
    // one "who's around" describes) is the accent bar down its left edge
    // and a filled card.
    return Container(
      margin: const EdgeInsets.only(bottom: MitlistSpacing.sm),
      padding: EdgeInsets.only(left: isSelected ? MitlistSpacing.sm : 0),
      decoration: isSelected
          ? BoxDecoration(
              border: Border(left: BorderSide(color: cs.primary, width: 6)))
          : null,
      child: AppCard(
        variant: isSelected ? AppCardVariant.filled : AppCardVariant.outlined,
        padding: AppCardPadding.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _maybeSelectable(
              context,
              l10n,
              Row(
                children: [
                  if (isSelected) ...[
                    AppIcon(name: 'userGroup', size: 16, color: cs.primary),
                    const SizedBox(width: MitlistSpacing.xs),
                  ],
                  Text(
                    weekday,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: MitlistSpacing.sm),
                  Text(
                    DateFormat.MMMd(localeName).format(day),
                    style: MitlistTypography.labelXSmall(),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: MitlistSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MitlistSpacing.sm,
                        vertical: MitlistSpacing.space1,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius:
                            BorderRadius.circular(MitlistTheme.radiusSm),
                      ),
                      child: Text(
                        l10n.calendarToday,
                        style: MitlistTypography.labelXSmall(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: MitlistSpacing.sm),
                child: Text(
                  l10n.calendarNothingPlanned,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MitlistTypography.labelXSmall(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...events.map((e) {
                final tap = onEventTap != null ? () => onEventTap!(e) : null;
                if (e.type == CalendarEventType.externalEvent &&
                    e.external != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: MitlistSpacing.sm),
                    child: _ExternalEventRow(
                      event: e,
                      day: day,
                      personName: personName(e.external!.userId),
                      roster: roster,
                      onTap: tap,
                    ),
                  );
                }
                return _EventRow(event: e, onTap: tap);
              }),
          ],
        ),
      ),
    );
  }

  Widget _maybeSelectable(
      BuildContext context, AppLocalizations l10n, Widget header) {
    final select = onSelect;
    if (select == null) return header;
    return Semantics(
      button: true,
      selected: isSelected,
      hint: l10n.calendarWhosAroundSelectDay,
      child: InkWell(
        onTap: select,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Align(alignment: Alignment.centerLeft, child: header),
        ),
      ),
    );
  }
}

/// A small initials badge for a household member, in their own colour
/// (distinct within the household, see [MemberColors]).
class _PersonBadge extends StatelessWidget {
  const _PersonBadge({
    required this.userId,
    required this.name,
    required this.roster,
  });

  final String userId;
  final String name;
  final List<String> roster;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = MemberColors.of(userId, theme.brightness, roster);
    return ExcludeSemantics(
      child: Container(
        width: MitlistSpacing.space6,
        height: MitlistSpacing.space6,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.background,
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.outline, width: 1),
        ),
        child: Text(
          name.isEmpty ? '?' : avatarInitials(name),
          maxLines: 1,
          style: MitlistTypography.labelXSmall(color: colors.foreground)
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// The "Busy" tag a busy-only block shows in place of a title.
class _BusyTag extends StatelessWidget {
  const _BusyTag();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.sm,
        vertical: MitlistSpacing.space0_5,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outline, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(name: 'lockClosed', size: 14, color: cs.onSurface),
          const SizedBox(width: MitlistSpacing.xs),
          Text(
            l10n.calendarExternalBusy,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// A housemate's shared event: the title (or a "Busy" tag when the
/// household sees only that they are busy) on the first line, who and when
/// on the second, so neither is squeezed. Events marked free are lighter.
class _ExternalEventRow extends StatelessWidget {
  const _ExternalEventRow({
    required this.event,
    required this.day,
    required this.personName,
    required this.roster,
    this.onTap,
  });

  final CalendarEvent event;
  final DateTime day;
  final String personName;
  final List<String> roster;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final x = event.external!;
    final localeName = Localizations.localeOf(context).toString();
    final what = _externalEventText(event, l10n);
    final when = _externalTimeLabel(x, day, localeName, l10n);
    final busyOnly = x.busyOnly || event.title.trim().isEmpty;
    final label = x.free
        ? l10n.calendarExternalSemanticsFree(personName, what, when)
        : l10n.calendarExternalSemantics(personName, what, when);
    final second = [
      personName,
      when,
      if (x.free) l10n.calendarExternalFree,
    ].join(' · ');

    return Semantics(
      label: label,
      button: onTap != null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: MitlistSpacing.xs,
              horizontal: MitlistSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: MitlistSpacing.space0_5),
                  child: _PersonBadge(
                      userId: x.userId, name: personName, roster: roster),
                ),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (busyOnly)
                        const _BusyTag()
                      else
                        Text(
                          what,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: x.free ? cs.onSurfaceVariant : cs.onSurface,
                            fontWeight:
                                x.free ? FontWeight.w400 : FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: MitlistSpacing.space0_5),
                      Text(
                        second,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: MitlistTypography.labelXSmall(
                            color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The colour of a who's-around status marker (never the brand orange).
Color _aroundColor(BuildContext context, AroundStatus status) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (status) {
    AroundStatus.free =>
      dark ? MitlistColors.success300 : MitlistColors.success700,
    AroundStatus.busy =>
      dark ? MitlistColors.warning300 : MitlistColors.warning700,
    AroundStatus.away => dark ? MitlistColors.error300 : MitlistColors.error700,
    AroundStatus.notSharing => Theme.of(context).colorScheme.outline,
  };
}

/// For the selected day: one line for the household's evening, then each
/// member in a column: free all day, free from a time, busy until a time,
/// away, or not sharing a calendar.
/// Whether "who's around" shows everyone's times (true) or the compact row
/// of badges; remembered for the session.
final whosAroundExpandedProvider = StateProvider<bool>((ref) => false);

class _WhosAroundCard extends StatelessWidget {
  const _WhosAroundCard({
    required this.day,
    required this.around,
    required this.evening,
    required this.nameFor,
    required this.roster,
    required this.expanded,
    required this.onToggle,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final DateTime day;
  final List<MemberAround> around;
  final HouseholdEvening? evening;
  final String Function(String userId) nameFor;
  final List<String> roster;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final localeName = Localizations.localeOf(context).toString();
    final fmt = DateFormat.jm(localeName);
    final dayLabel = DateFormat.MMMEd(localeName).format(day);

    String status(MemberAround m) => switch (m.status) {
          AroundStatus.free => l10n.calendarWhosAroundFreeAllDay,
          AroundStatus.away => l10n.calendarWhosAroundAway,
          AroundStatus.notSharing => l10n.calendarWhosAroundNotSharing,
          AroundStatus.busy => m.busyUntil != null
              ? l10n.calendarWhosAroundBusyUntil(fmt.format(m.busyUntil!))
              : m.freeFrom != null
                  ? l10n.calendarWhosAroundFreeFrom(fmt.format(m.freeFrom!))
                  : l10n.calendarWhosAroundBusyFrom(fmt.format(m.busyFrom!)),
        };
    String? detail(MemberAround m) => m.status == AroundStatus.busy
        ? l10n.calendarWhosAroundBusy(m.busy
            .map((r) => l10n.calendarExternalTimeRange(
                fmt.format(r.start), fmt.format(r.end)))
            .join(', '))
        : null;

    final e = evening;
    final summary = e == null
        ? null
        : switch ((e.kind, e.onlySharers)) {
            (EveningKind.freeAllEvening, false) =>
              l10n.calendarWhosAroundEveningAll,
            (EveningKind.freeAllEvening, true) =>
              l10n.calendarWhosAroundSharersEveningAll,
            (EveningKind.freeFrom, false) =>
              l10n.calendarWhosAroundEveningFrom(fmt.format(e.from!)),
            (EveningKind.freeFrom, true) =>
              l10n.calendarWhosAroundSharersEveningFrom(fmt.format(e.from!)),
            (EveningKind.freeBetween, false) =>
              l10n.calendarWhosAroundEveningBetween(
                  fmt.format(e.from!), fmt.format(e.until!)),
            (EveningKind.freeBetween, true) =>
              l10n.calendarWhosAroundSharersEveningBetween(
                  fmt.format(e.from!), fmt.format(e.until!)),
            (EveningKind.notEveryoneFree, false) =>
              l10n.calendarWhosAroundEveningNone,
            (EveningKind.notEveryoneFree, true) =>
              l10n.calendarWhosAroundSharersEveningNone,
          };
    final eveningFree = e != null && e.kind != EveningKind.notEveryoneFree;

    final header = Row(
      children: [
        Expanded(
          child: Text(
            l10n.calendarWhosAroundTitle(dayLabel),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          key: const ValueKey('calendar-whos-around-toggle'),
          tooltip: expanded
              ? l10n.calendarWhosAroundCollapse
              : l10n.calendarWhosAroundExpand,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: AppIcon(name: expanded ? 'chevronUp' : 'chevronDown'),
          onPressed: onToggle,
        ),
      ],
    );

    final summaryLine = summary == null
        ? null
        : Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(
                  name: eveningFree ? 'checkCircle' : 'clockOutline',
                  size: 18,
                  color: _aroundColor(context,
                      eveningFree ? AroundStatus.free : AroundStatus.busy),
                ),
                const SizedBox(width: MitlistSpacing.xs),
                Expanded(
                  child: Text(
                    summary,
                    key: const ValueKey('calendar-whos-around-evening'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );

    // Compact: one row of badges, each marked with its status colour and
    // announced with the person's status.
    final compact = InkWell(
      onTap: onToggle,
      excludeFromSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.xs),
        child: Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.xs,
          children: [
            for (final m in around)
              Semantics(
                key: ValueKey('whos-around-badge-${m.userId}'),
                container: true,
                label: '${nameFor(m.userId)}: ${status(m)}',
                excludeSemantics: true,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _PersonBadge(
                        userId: m.userId,
                        name: nameFor(m.userId),
                        roster: roster),
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: _aroundColor(context, m.status),
                          border: Border.all(color: cs.surface, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    final full = <Widget>[
      for (final m in around)
        Semantics(
          label: [
            nameFor(m.userId),
            status(m),
            if (detail(m) != null) detail(m)
          ].join(', '),
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.only(top: MitlistSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PersonBadge(
                    userId: m.userId, name: nameFor(m.userId), roster: roster),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding:
                        const EdgeInsets.only(top: MitlistSpacing.space0_5),
                    child: Text(
                      nameFor(m.userId),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(width: MitlistSpacing.sm),
                // The status column: every status starts at the same x.
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding:
                        const EdgeInsets.only(top: MitlistSpacing.space0_5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: MitlistSpacing.sm,
                              height: MitlistSpacing.sm,
                              color: _aroundColor(context, m.status),
                            ),
                            const SizedBox(width: MitlistSpacing.xs),
                            Expanded(
                              child: Text(
                                status(m),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: m.status == AroundStatus.notSharing
                                      ? cs.onSurfaceVariant
                                      : cs.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (detail(m) != null)
                          Padding(
                            padding: const EdgeInsets.only(
                                left: MitlistSpacing.sm + MitlistSpacing.xs),
                            child: Text(
                              detail(m)!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: MitlistTypography.labelXSmall(
                                  color: cs.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: MitlistSpacing.sm),
      Text(
        l10n.calendarWhosAroundTapHint,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: MitlistTypography.labelXSmall(color: cs.onSurfaceVariant),
      ),
    ];

    return AppCard(
      key: const ValueKey('calendar-whos-around'),
      variant: AppCardVariant.outlined,
      padding: AppCardPadding.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (summaryLine != null) summaryLine,
          const SizedBox(height: MitlistSpacing.xs),
          if (expanded) ...full else compact,
        ],
      ),
    );
  }
}

/// First run: nobody in the household shares a calendar yet.
class _ShareCalendarHint extends StatelessWidget {
  const _ShareCalendarHint({required this.onOpen, required this.onDismiss});

  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          MitlistSpacing.md, MitlistSpacing.sm, MitlistSpacing.md, 0),
      child: AppCard(
        key: const ValueKey('calendar-share-hint'),
        variant: AppCardVariant.outlined,
        padding: AppCardPadding.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.calendarShareHintTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: MitlistSpacing.xs),
            Text(
              l10n.calendarShareHintBody,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            Wrap(
              spacing: MitlistSpacing.sm,
              runSpacing: MitlistSpacing.sm,
              children: [
                AppButton(
                  text: l10n.calendarShareHintAction,
                  size: AppButtonSize.sm,
                  onPressed: onOpen,
                ),
                AppButton(
                  text: l10n.commonNotNow,
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.ghost,
                  onPressed: onDismiss,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback? onTap;

  const _EventRow({required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final visual = _eventVisual(Theme.of(context).colorScheme, event.type);
    final icon = visual.icon;
    final color = visual.color;
    final label = switch (event.type) {
      CalendarEventType.mealPlan =>
        event.mealPlan?.slot ?? l10n.calendarEventMeal,
      CalendarEventType.chore => l10n.calendarEventChore,
      CalendarEventType.recurringExpense => l10n.calendarEventRecurring,
      CalendarEventType.expense => l10n.calendarEventExpense,
      CalendarEventType.pinwallReminder => l10n.calendarEventReminder,
      CalendarEventType.listReminder => l10n.calendarEventListReminder,
      CalendarEventType.externalEvent => l10n.calendarExternalBusy,
    };

    return Padding(
      padding: const EdgeInsets.only(top: MitlistSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: MitlistSpacing.xs,
            horizontal: MitlistSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: Text(
                  event.title.isNotEmpty ? event.title : label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (event.type == CalendarEventType.mealPlan &&
                  event.mealPlan != null)
                Text(
                  l10n.calendarServingsPpl(event.mealPlan!.servings),
                  style: MitlistTypography.labelXSmall(),
                ),
              if (event.type == CalendarEventType.recurringExpense &&
                  event.recurringExpense != null)
                Text(
                  (event.recurringExpense!.amount / 100).toStringAsFixed(2),
                  style: MitlistTypography.labelXSmall(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single calendar view-mode tab. Keeps a 44px touch target, gives ink
/// feedback on press, and exposes button/selected state to assistive tech.
class _ViewTab extends StatelessWidget {
  final String label;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  const _ViewTab({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? cs.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                ),
          ),
        ),
      ),
    );
  }
}
