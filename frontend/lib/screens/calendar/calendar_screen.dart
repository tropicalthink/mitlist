import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/calendar_models.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/chore_provider.dart';
import '../../providers/group_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../services/group_id_validator.dart';
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
  };
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _weekAnchor = today;
    _monthStart = DateTime(now.year, now.month, 1);
    _agendaAnchor = today;
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString('calendar_view_mode');
      if (!mounted) return;
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
    setState(() {
      _weekAnchor = DateTime(day.year, day.month, day.day);
      _viewMode = _CalendarView.week;
    });
  }

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
    return Column(
      children: [
        _buildViewToggle(),
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
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        _weekHeader(l10n),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: 7,
            itemBuilder: (context, index) {
              final day = ws.add(Duration(days: index));
              final dayEvents = _eventsByDay[day] ?? const [];
              return _DayCard(
                day: day,
                events: dayEvents,
                isToday: _isToday(day),
                onEventTap: (e) => _showEventDetail(context, e),
              );
            },
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
            final label = e.title.isNotEmpty ? e.title : e.type.name;
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
          ChoreCreationSheet.show(context);
        case 'add_expense':
          ExpenseCreationSheet.show(context);
      }
    });
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
              description: l10n.calendarNothingAheadDesc,
              actions: [
                AppButton(
                  text: l10n.choreAppBarTitle,
                  variant: AppButtonVariant.outline,
                  onPressed: () => context.pushNamed('chores'),
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
              ..._agendaDayEvents(dayEvents, l10n),
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
      List<CalendarEvent> events, AppLocalizations l10n) {
    return events.map((e) {
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
            onDelete: () => _deleteChore(event.chore!.choreId),
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
    }
  }

  /// Runs once the detail sheet has already confirmed the delete with the
  /// user, so it closes the sheet and deletes without asking again.
  Future<void> _deleteChore(String choreId) async {
    if (_isSaving) return;
    _isSaving = true;
    Navigator.of(context).pop();
    try {
      final service = await ref.read(choreServiceProviderAsync.future);
      await service.deleteChore(choreId);
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

  const _EmptyRange({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppEmptyState(
        lottieAsset: 'assets/animations/lottie/Calendar.lottie',
        icon: AppIcon(name: 'eventNote', size: 56),
        title: title,
        description: description,
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final DateTime day;
  final List<CalendarEvent> events;
  final bool isToday;
  final void Function(CalendarEvent)? onEventTap;

  const _DayCard({
    required this.day,
    required this.events,
    required this.isToday,
    this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final localeName = Localizations.localeOf(context).toString();
    final weekday = DateFormat.EEEE(localeName).format(day);

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
      child: AppCard(
        variant: isToday ? AppCardVariant.filled : AppCardVariant.outlined,
        padding: AppCardPadding.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
              ...events.map((e) => _EventRow(
                    event: e,
                    onTap: onEventTap != null ? () => onEventTap!(e) : null,
                  )),
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
