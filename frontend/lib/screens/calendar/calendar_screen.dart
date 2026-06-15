import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../widgets/app_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../sheets/expense_creation_sheet.dart';
import '../../sheets/chore_creation_sheet.dart';
import '../../sheets/chore_detail_sheet.dart';
import '../../sheets/create_household_sheet.dart';

enum _CalendarView { week, month, agenda }

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  bool _hasHousehold = true;
  final List<CalendarEvent> _events = [];
  _CalendarView _viewMode = _CalendarView.week;

  late DateTime _weekStart;
  late DateTime _monthStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _monthStart = DateTime(now.year, now.month, 1);
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getString('calendar_view_mode');
      if (saved == 'month') setState(() => _viewMode = _CalendarView.month);
      if (saved == 'agenda') setState(() => _viewMode = _CalendarView.agenda);
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final groups = await ref.read(cachedGroupsProvider.future);
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (!isValidGroupId(groupId)) {
        setState(() {
          _hasHousehold = false;
          _isLoading = false;
        });
        return;
      }

      DateTime from, to;
      if (_viewMode == _CalendarView.month) {
        from = DateTime(_monthStart.year, _monthStart.month, 1);
        to = DateTime(_monthStart.year, _monthStart.month + 1, 0);
      } else if (_viewMode == _CalendarView.agenda) {
        from = DateTime.now().subtract(Duration(days: 7));
        to = DateTime.now().add(Duration(days: 30));
      } else {
        from = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
        to = from.add(Duration(days: 6));
      }

      final calendarService =
          await ref.read(calendarServiceProviderAsync.future);
      final events =
          await calendarService.getCalendar(groupId!, from, to);
      setState(() {
        _events
          ..clear()
          ..addAll(events);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyErrorMessage(e, AppLocalizations.of(context)!);
        _isLoading = false;
      });
    }
  }

  void _prevWeek() {
    setState(() => _weekStart = _weekStart.subtract(Duration(days: 7)));
    _load();
  }

  void _nextWeek() {
    setState(() => _weekStart = _weekStart.add(Duration(days: 7)));
    _load();
  }

  void _prevMonth() {
    setState(() {
      _monthStart =
          DateTime(_monthStart.year, _monthStart.month - 1, 1);
    });
    _load();
  }

  void _nextMonth() {
    setState(() {
      _monthStart =
          DateTime(_monthStart.year, _monthStart.month + 1, 1);
    });
    _load();
  }

  void _setViewMode(_CalendarView mode) {
    if (mode == _viewMode) return;
    unawaited(Haptics.light());
    setState(() => _viewMode = mode);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('calendar_view_mode', mode.name);
    });
    _load();
  }

  String _weekLabel(AppLocalizations l10n) {
    final end = _weekStart.add(const Duration(days: 6));
    final weekStartStr = '${_weekStart.day}.${_weekStart.month}.';
    final weekEndStr = '${end.day}.${end.month}.${end.year}';
    return l10n.calendarWeekHeader(weekStartStr, weekEndStr);
  }

  String _monthLabel(AppLocalizations l10n) {
    final months = _months(l10n);
    return l10n.calendarMonthHeader(months[_monthStart.month - 1], _monthStart.year);
  }

  List<String> _months(AppLocalizations l10n) => [
    l10n.calendarMonthJanuary, l10n.calendarMonthFebruary, l10n.calendarMonthMarch,
    l10n.calendarMonthApril, l10n.calendarMonthMay, l10n.calendarMonthJune,
    l10n.calendarMonthJuly, l10n.calendarMonthAugust, l10n.calendarMonthSeptember,
    l10n.calendarMonthOctober, l10n.calendarMonthNovember, l10n.calendarMonthDecember,
  ];

  List<String> _weekdayHeaders(AppLocalizations l10n) => [
    l10n.calendarShortMon, l10n.calendarShortTue, l10n.calendarShortWed,
    l10n.calendarShortThu, l10n.calendarShortFri, l10n.calendarShortSat, l10n.calendarShortSun,
  ];

  Map<DateTime, List<CalendarEvent>> get _eventsByDay {
    final map = <DateTime, List<CalendarEvent>>{};
    for (final e in _events) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      map.putIfAbsent(d, () => []).add(e);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.calendarAppBarTitle,
        showStandardActions: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        itemCount: 7,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
          child: AppSkeleton(width: double.infinity, height: 80),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/404.lottie',
          icon: AppIcon(name: 'alertCircleOutline'),
          title: l10n.commonSomethingWentWrong,
          description: _error,
          actions: [
            AppButton(
              variant: AppButtonVariant.outline,
              text: l10n.commonRetry,
              onPressed: _load,
            ),
          ],
        ),
      );
    }
    if (!_hasHousehold) {
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

    return Column(
      children: [
        _buildViewToggle(),
        if (_viewMode == _CalendarView.week)
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildWeekView(),
            ),
          ),
        if (_viewMode == _CalendarView.month)
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildMonthView(),
            ),
          ),
        // Agenda wraps itself in Expanded + RefreshIndicator.
        if (_viewMode == _CalendarView.agenda) _buildAgendaView(),
      ],
    );
  }

  Widget _buildViewToggle() {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              selected: _viewMode == _CalendarView.week,
              label: l10n.calendarWeekView,
              child: GestureDetector(
                onTap: () => _setViewMode(_CalendarView.week),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: MitlistSpacing.sm),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _viewMode == _CalendarView.week
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    l10n.calendarViewWeek,
                    textAlign: TextAlign.center,
                    style: textTheme.labelMedium?.copyWith(
                      color: _viewMode == _CalendarView.week
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              button: true,
              selected: _viewMode == _CalendarView.month,
              label: l10n.calendarMonthView,
              child: GestureDetector(
                onTap: () => _setViewMode(_CalendarView.month),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: MitlistSpacing.sm),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _viewMode == _CalendarView.month
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    l10n.calendarViewMonth,
                    textAlign: TextAlign.center,
                    style: textTheme.labelMedium?.copyWith(
                      color: _viewMode == _CalendarView.month
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              button: true,
              selected: _viewMode == _CalendarView.agenda,
              label: l10n.calendarAgendaView,
              child: GestureDetector(
                onTap: () => _setViewMode(_CalendarView.agenda),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: MitlistSpacing.sm),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _viewMode == _CalendarView.agenda
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    l10n.calendarViewAgenda,
                    textAlign: TextAlign.center,
                    style: textTheme.labelMedium?.copyWith(
                      color: _viewMode == _CalendarView.agenda
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Week View ───────────────────────────────────────────────────────────

  Widget _buildWeekView() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
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
        ),
        Expanded(
          child: ListView.builder(
            padding:
                const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
            itemCount: 7,
            itemBuilder: (context, index) {
              final day = _weekStart.add(Duration(days: index));
              final dayEvents = _eventsByDay[day] ?? [];
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
    final firstWeekday = _monthStart.weekday;
    final totalCells = ((firstWeekday - 1 + daysInMonth) / 7).ceil() * 7;

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
          padding:
              const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
          child: Row(
            children: _weekdayHeaders(l10n)
                .map((h) => Expanded(
                      child: Center(
                        child: Text(
                          h,
                          style: MitlistTypography.labelXSmall(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: MitlistSpacing.sm),
            child: GridView.builder(
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.9,
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                final dayNum = index - (firstWeekday - 1) + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const SizedBox.shrink();
                }

                final day = DateTime(
                    _monthStart.year, _monthStart.month, dayNum);
                final dayEvents = _eventsByDay[day] ?? [];
                final isToday = _isToday(day);

                return Semantics(
                  button: true,
                  label: l10n.calendarDayLabel(day.day),
                  child: GestureDetector(
                    onTapDown: (details) => _showDayMenu(
                        context, day, dayEvents, details.globalPosition),
                    onTap: () {
                      setState(() {
                        _weekStart = _weekStartForDay(day);
                        _viewMode = _CalendarView.week;
                      });
                      _load();
                    },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isToday
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.transparent,
                      border: Border.all(
                        color: isToday
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(height: MitlistSpacing.xs),
                        Text(
                          '$dayNum',
                          style:
                              MitlistTypography.labelXSmall(
                            color: isToday
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (dayEvents.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${dayEvents.length}',
                              style: MitlistTypography.labelXSmall(
                                color: _dotColor(context, dayEvents.first.type),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
              },
            ),
          ),
        ),
      ],
    );
  }

  DateTime _weekStartForDay(DateTime day) {
    return day.subtract(Duration(days: day.weekday - 1));
  }

  Color _dotColor(BuildContext context, CalendarEventType type) {
    return switch (type) {
      CalendarEventType.mealPlan => Theme.of(context).colorScheme.primary,
      CalendarEventType.chore => Theme.of(context).colorScheme.secondary,
      CalendarEventType.recurringExpense => Theme.of(context).colorScheme.tertiary,
      CalendarEventType.expense => Theme.of(context).colorScheme.secondary,
      CalendarEventType.pinwallReminder => Theme.of(context).colorScheme.errorContainer,
    };
  }

  void _showDayMenu(
    BuildContext ctx,
    DateTime day,
    List<CalendarEvent> events,
    Offset position,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final dayLabel =
        '${_weekdayName(day.weekday, l10n)}, ${day.day}.${day.month}.${day.year}';

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
          setState(() {
            _weekStart = _weekStartForDay(day);
            _viewMode = _CalendarView.week;
          });
          _load();
        case 'add_chore':
          ChoreCreationSheet.show(context,
              initialTitle: '${day.day}.${day.month}.');
        case 'add_expense':
          ExpenseCreationSheet.show(context);
      }
    });
  }

  // ── Agenda View ─────────────────────────────────────────────────────────

  Widget _buildAgendaView() {
    final l10n = AppLocalizations.of(context)!;
    final sortedDays = _eventsByDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (sortedDays.isEmpty) {
      return Expanded(
        child: Center(
          child: AppEmptyState(
            lottieAsset: 'assets/animations/lottie/Calendar.lottie',
            icon: AppIcon(name: 'eventNote', size: 56),
            title: l10n.calendarNothingAhead,
            description:
                l10n.calendarNothingAheadDesc,
            actions: [
              AppButton(
                text: l10n.choreAppBarTitle,
                variant: AppButtonVariant.outline,
                onPressed: () => context.pushNamed('chores'),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
        itemCount: sortedDays.length,
        itemBuilder: (context, index) {
          final entry = sortedDays[index];
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
                        margin:
                            const EdgeInsets.only(right: MitlistSpacing.sm),
                      ),
                    Text(
                      _formatAgendaDate(day, l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
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
      ),
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
    return '${_weekdayName(day.weekday, l10n)}, ${day.day}.${day.month}.';
  }

  String _weekdayName(int weekday, AppLocalizations l10n) {
    return [
      l10n.calendarWeekdayMonday, l10n.calendarWeekdayTuesday, l10n.calendarWeekdayWednesday,
      l10n.calendarWeekdayThursday, l10n.calendarWeekdayFriday, l10n.calendarWeekdaySaturday,
      l10n.calendarWeekdaySunday,
    ][weekday - 1];
  }

  List<Widget> _agendaDayEvents(List<CalendarEvent> events, AppLocalizations l10n) {
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
                if (e.type == CalendarEventType.mealPlan &&
                    e.mealPlan != null)
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

  (IconData, Color, String) _eventMeta(BuildContext context, CalendarEvent event, AppLocalizations l10n) {
    return switch (event.type) {
      CalendarEventType.mealPlan => (
          Icons.restaurant,
          Theme.of(context).colorScheme.primary,
          event.mealPlan?.slot ?? l10n.calendarEventMeal
        ),
      CalendarEventType.chore => (
          Icons.cleaning_services,
          Theme.of(context).colorScheme.secondary,
          l10n.calendarEventChore
        ),
      CalendarEventType.recurringExpense => (
          Icons.repeat,
          Theme.of(context).colorScheme.tertiary,
          l10n.calendarEventRecurring
        ),
      CalendarEventType.expense => (
          Icons.receipt_outlined,
          Theme.of(context).colorScheme.secondary,
          l10n.calendarEventExpense
        ),
      CalendarEventType.pinwallReminder => (
          Icons.push_pin_outlined,
          Theme.of(context).colorScheme.errorContainer,
          l10n.calendarEventReminder
        ),
    };
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year &&
        d.month == now.month &&
        d.day == now.day;
  }

  void _showEventDetail(BuildContext context, CalendarEvent event) {
    final l10n = AppLocalizations.of(context)!;
    switch (event.type) {
      case CalendarEventType.chore:
        if (event.chore != null) {
          ChoreDetailSheet.show(
            context,
            choreId: event.chore!.choreId,
            title: event.title.isNotEmpty ? event.title : l10n.calendarEventChore,
            statusLabel: event.chore!.status,
            assignee: '',
            dueDate: event.date,
            onDelete: () => _confirmDeleteChore(event.chore!.choreId),
          );
        }
      case CalendarEventType.mealPlan:
        context.pushNamed('mealPlan');
      case CalendarEventType.recurringExpense:
        context.pushNamed('recurringExpenses');
      case CalendarEventType.expense:
        context.pushNamed('money');
      case CalendarEventType.pinwallReminder:
        break;
    }
  }

  Future<void> _confirmDeleteChore(String choreId) async {
    if (_isSaving) return;
    _isSaving = true;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.choreDeleteTitle,
      body: Text(l10n.choreDeleteBody),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: l10n.commonDelete,
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) { _isSaving = false; return; }
    Navigator.of(context).pop();
    try {
      final service = await ref.read(choreServiceProviderAsync.future);
      await service.deleteChore(choreId);
      unawaited(_load());
    } catch (e) {
      if (!mounted) return;
      unawaited(Haptics.failure());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
      );
    } finally {
      _isSaving = false;
    }
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
    final weekday = _weekdayName(day.weekday, l10n);

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
                  '${day.day}.${day.month}.',
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
                      borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
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

  String _weekdayName(int weekday, AppLocalizations l10n) {
    return [
      l10n.calendarWeekdayMonday,
      l10n.calendarWeekdayTuesday,
      l10n.calendarWeekdayWednesday,
      l10n.calendarWeekdayThursday,
      l10n.calendarWeekdayFriday,
      l10n.calendarWeekdaySaturday,
      l10n.calendarWeekdaySunday,
    ][weekday - 1];
  }
}

class _EventRow extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback? onTap;

  const _EventRow({required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (icon, color, label) = switch (event.type) {
      CalendarEventType.mealPlan => (
          Icons.restaurant,
          Theme.of(context).colorScheme.primary,
          event.mealPlan?.slot ?? l10n.calendarEventMeal
        ),
      CalendarEventType.chore => (
          Icons.cleaning_services,
          Theme.of(context).colorScheme.secondary,
          l10n.calendarEventChore
        ),
      CalendarEventType.recurringExpense => (
          Icons.repeat,
          Theme.of(context).colorScheme.tertiary,
          l10n.calendarEventRecurring
        ),
      CalendarEventType.expense => (
          Icons.receipt_outlined,
          Theme.of(context).colorScheme.secondary,
          l10n.calendarEventExpense
        ),
      CalendarEventType.pinwallReminder => (
          Icons.push_pin_outlined,
          Theme.of(context).colorScheme.errorContainer,
          l10n.calendarEventReminder
        ),
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
