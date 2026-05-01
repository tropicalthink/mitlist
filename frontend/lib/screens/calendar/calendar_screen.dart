import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/calendar_models.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/group_provider.dart';
import '../../services/group_id_validator.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/mitlist_app_bar.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  bool _isLoading = true;
  String? _error;
  bool _hasHousehold = true;
  final List<CalendarEvent> _events = [];

  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
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
      final groupId = groups.isNotEmpty ? groups.first.id : null;
      if (!isValidGroupId(groupId)) {
        setState(() {
          _hasHousehold = false;
          _isLoading = false;
        });
        return;
      }
      final calendarService = await ref.read(calendarServiceProviderAsync.future);
      final from = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
      final to = from.add(const Duration(days: 6));
      final events = await calendarService.getCalendar(groupId!, from, to);
      setState(() {
        _events
          ..clear()
          ..addAll(events);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _prevWeek() {
    setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    _load();
  }

  void _nextWeek() {
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
    _load();
  }

  String _weekLabel() {
    final end = _weekStart.add(const Duration(days: 6));
    return '${_weekStart.day}.${_weekStart.month}. – ${end.day}.${end.month}.${end.year}';
  }

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
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: MitlistSpacing.sm),
          child: AppSkeleton(width: double.infinity, height: 80),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: AppEmptyState(
          icon: const Icon(Icons.error_outline),
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
      return const Center(
        child: AppEmptyState(
          icon: Icon(Icons.home_outlined),
          title: 'No household',
          description: 'Join or create a household to view the calendar',
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
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
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next week',
                onPressed: _nextWeek,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
            itemCount: 7,
            itemBuilder: (context, index) {
              final day = _weekStart.add(Duration(days: index));
              final dayEvents = _eventsByDay[day] ?? [];
              return _DayCard(
                day: day,
                events: dayEvents,
                isToday: _isToday(day),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _DayCard extends StatelessWidget {
  final DateTime day;
  final List<CalendarEvent> events;
  final bool isToday;

  const _DayCard({
    required this.day,
    required this.events,
    required this.isToday,
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
                      color: MitlistColors.primary500,
                      borderRadius: BorderRadius.circular(4),
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
                    color: MitlistColors.textTertiary,
                  ),
                ),
              )
            else
              ...events.map((e) => _EventRow(event: e)),
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

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (event.type) {
      CalendarEventType.mealPlan => (
          Icons.restaurant,
          MitlistColors.primary500,
          event.mealPlan?.slot ?? 'Meal'
        ),
      CalendarEventType.chore => (
          Icons.cleaning_services,
          MitlistColors.warning500,
          'Chore'
        ),
      CalendarEventType.recurringExpense => (
          Icons.repeat,
          MitlistColors.success500,
          'Recurring'
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: MitlistSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Text(
              event.title.isNotEmpty ? event.title : label,
              style: TextStyle(
                color: MitlistColors.textPrimary,
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
              '€${(event.recurringExpense!.amount / 100).toStringAsFixed(2)}',
              style: MitlistTypography.labelXSmall(),
            ),
        ],
      ),
    );
  }
}
