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
import '../../utils/active_group_context.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../sheets/expense_creation_sheet.dart';
import '../../sheets/chore_creation_sheet.dart';
import '../../sheets/chore_detail_sheet.dart';

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
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupService.listGroups();
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
        _error = 'Something went wrong.';
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
    setState(() => _viewMode = mode);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('calendar_view_mode', mode.name);
    });
    _load();
  }

  String _weekLabel() {
    final end = _weekStart.add(Duration(days: 6));
    return '${_weekStart.day}.${_weekStart.month}.'
        ' – ${end.day}.${end.month}.${end.year}';
  }

  String _monthLabel() {
    return '${_months[_monthStart.month - 1]} ${_monthStart.year}';
  }

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const _weekdayHeaders = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
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
    return Scaffold(
      appBar: MitlistAppBar.titleText(
        'Calendar',
        showStandardActions: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        itemCount: 7,
        itemBuilder: (_, __) => Padding(
          padding: EdgeInsets.only(bottom: MitlistSpacing.sm),
          child: AppSkeleton(width: double.infinity, height: 80),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/404.lottie',
          icon: Icon(Icons.error_outline),
          title: 'Something went wrong',
          description: _error,
          actions: [
            AppButton(
              variant: AppButtonVariant.outline,
              text: 'Retry',
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
          icon: Icon(Icons.home_outlined),
          title: 'No household',
          description: 'Join or create a household to view the calendar',
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
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Row(
        children: [
          Expanded(
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
                  'Week',
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
          Expanded(
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
                  'Month',
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
          Expanded(
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
                  'Agenda',
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
        ],
      ),
    );
  }

  // ── Week View ───────────────────────────────────────────────────────────

  Widget _buildWeekView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left),
                tooltip: 'Previous week',
                onPressed: _prevWeek,
              ),
              Expanded(
                child: Text(
                  _weekLabel(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right),
                tooltip: 'Next week',
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
                icon: Icon(Icons.chevron_left),
                tooltip: 'Previous month',
                onPressed: _prevMonth,
              ),
              Expanded(
                child: Text(
                  _monthLabel(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right),
                tooltip: 'Next month',
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
            children: _weekdayHeaders
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
        SizedBox(height: MitlistSpacing.sm),
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

                return GestureDetector(
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
                        SizedBox(height: MitlistSpacing.xs),
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
    final dayLabel =
        '${_weekdayName(day.weekday)}, ${day.day}.${day.month}.${day.year}';

    showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem(
          enabled: false,
          height: 28,
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
        PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'add_chore',
          child: Text('Add chore'),
        ),
        PopupMenuItem<String>(
          value: 'add_expense',
          child: Text('Add expense'),
        ),
        PopupMenuItem<String>(
          value: 'view_week',
          child: Text('View in week'),
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
    final sortedDays = _eventsByDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (sortedDays.isEmpty) {
      return Expanded(
        child: Center(
          child: AppEmptyState(
            lottieAsset: 'assets/animations/lottie/Calendar.lottie',
            icon: Icon(Icons.event_note, size: 56),
            title: 'Nothing ahead',
            description:
                'Upcoming chores, meal plans, and recurring expenses will appear here.',
            actions: [
              AppButton(
                text: 'Chores',
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
                      _formatAgendaDate(day),
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
                SizedBox(height: MitlistSpacing.sm),
                ..._agendaDayEvents(dayEvents),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatAgendaDate(DateTime day) {
    if (_isToday(day)) return 'Today';
    final tomorrow = DateTime.now().add(Duration(days: 1));
    if (day.year == tomorrow.year &&
        day.month == tomorrow.month &&
        day.day == tomorrow.day) {
      return 'Tomorrow';
    }
    return '${_weekdayName(day.weekday)}, ${day.day}.${day.month}.';
  }

  String _weekdayName(int weekday) {
    return const [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ][weekday - 1];
  }

  List<Widget> _agendaDayEvents(List<CalendarEvent> events) {
    return events.map((e) {
      final (icon, color, label) = _eventMeta(context, e);
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
                SizedBox(width: MitlistSpacing.sm),
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
                    '${e.mealPlan!.servings} ppl ',
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

  (IconData, Color, String) _eventMeta(BuildContext context, CalendarEvent event) {
    return switch (event.type) {
      CalendarEventType.mealPlan => (
          Icons.restaurant,
          Theme.of(context).colorScheme.primary,
          event.mealPlan?.slot ?? 'Meal'
        ),
      CalendarEventType.chore => (
          Icons.cleaning_services,
          Theme.of(context).colorScheme.secondary,
          'Chore'
        ),
      CalendarEventType.recurringExpense => (
          Icons.repeat,
          Theme.of(context).colorScheme.tertiary,
          'Recurring'
        ),
      CalendarEventType.expense => (
          Icons.receipt_outlined,
          Theme.of(context).colorScheme.secondary,
          'Expense'
        ),
      CalendarEventType.pinwallReminder => (
          Icons.push_pin_outlined,
          Theme.of(context).colorScheme.errorContainer,
          'Reminder'
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
    switch (event.type) {
      case CalendarEventType.chore:
        if (event.chore != null) {
          ChoreDetailSheet.show(
            context,
            choreId: event.chore!.choreId,
            title: event.title.isNotEmpty ? event.title : 'Chore',
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
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: 'Delete chore',
      body: Text('This will permanently delete this chore and its history. This cannot be undone.'),
      actions: [
        AppButton(
          text: 'Cancel',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: 'Delete',
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
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete chore')),
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
    final textTheme = Theme.of(context).textTheme;
    final weekday = _weekdayName(day.weekday);

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
                SizedBox(width: MitlistSpacing.sm),
                Text(
                  '${day.day}.${day.month}.',
                  style: MitlistTypography.labelXSmall(),
                ),
                if (isToday) ...[
                  SizedBox(width: MitlistSpacing.sm),
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
                      'Today',
                      style: MitlistTypography.labelXSmall(
                        color: Colors.white,
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
                  'Nothing planned',
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

  String _weekdayName(int weekday) {
    return const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ][weekday - 1];
  }
}

class _EventRow extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback? onTap;

  const _EventRow({required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (event.type) {
      CalendarEventType.mealPlan => (
          Icons.restaurant,
          Theme.of(context).colorScheme.primary,
          event.mealPlan?.slot ?? 'Meal'
        ),
      CalendarEventType.chore => (
          Icons.cleaning_services,
          Theme.of(context).colorScheme.secondary,
          'Chore'
        ),
      CalendarEventType.recurringExpense => (
          Icons.repeat,
          Theme.of(context).colorScheme.tertiary,
          'Recurring'
        ),
      CalendarEventType.expense => (
          Icons.receipt_outlined,
          Theme.of(context).colorScheme.secondary,
          'Expense'
        ),
      CalendarEventType.pinwallReminder => (
          Icons.push_pin_outlined,
          Theme.of(context).colorScheme.errorContainer,
          'Reminder'
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
              SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: Text(
                  event.title.isNotEmpty ? event.title : label,
                  style: TextStyle(
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
                  '${event.mealPlan!.servings} ppl',
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
