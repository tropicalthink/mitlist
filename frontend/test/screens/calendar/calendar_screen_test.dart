import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/calendar_models.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/providers/calendar_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/screens/calendar/calendar_screen.dart';
import 'package:mitlist/widgets/skeleton.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const groupId = '11111111-1111-1111-1111-111111111111';

  Group group() => Group(
        id: groupId,
        name: 'Home',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  CalendarEvent todayEvent() => CalendarEvent(
        id: 'e1',
        type: CalendarEventType.chore,
        title: 'Team dinner',
        date: DateTime.now(),
        groupId: groupId,
      );

  Future<void> pumpCalendar(
    WidgetTester tester, {
    required List<CalendarEvent> events,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cachedGroupsProvider.overrideWith((ref) async => [group()]),
          calendarEventsProvider.overrideWith((ref, range) async => events),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CalendarScreen(),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('renders the loaded events (week view, no lingering skeleton)',
      (tester) async {
    await pumpCalendar(tester, events: [todayEvent()]);

    expect(find.text('Team dinner'), findsWidgets);
    expect(find.byType(AppSkeleton), findsNothing);
  });

  testWidgets('navigating weeks keeps last data visible instead of blanking',
      (tester) async {
    await pumpCalendar(tester, events: [todayEvent()]);
    expect(find.text('Team dinner'), findsWidgets);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(CalendarScreen)),
    )!;

    // Previous week: the range key changes and refetches, but the screen must
    // never fall back to skeletons (the regression this refactor fixed).
    await tester.tap(find.byTooltip(l10n.calendarPreviousWeek));
    await tester.pump();
    expect(find.byType(AppSkeleton), findsNothing);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Back to the current week — event is in range again.
    await tester.tap(find.byTooltip(l10n.calendarNextWeek));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Team dinner'), findsWidgets);
  });
}
