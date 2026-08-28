import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/weekly_summary_models.dart';
import 'package:mitlist/providers/weekly_summary_provider.dart';
import 'package:mitlist/screens/you/weekly_summary_screen.dart';

const _groupId = '11111111-1111-1111-1111-111111111111';

WeeklySummary _summary({
  int total = 47,
  int previous = 40,
  int mine = 12,
  int minePrevious = 9,
  List<WeeklyCategoryCount>? categories,
  List<WeeklyDayCount>? days,
  int activeMembers = 3,
  int memberCount = 4,
}) {
  final start = DateTime(2026, 8, 19);
  return WeeklySummary(
    groupId: _groupId,
    periodStart: start,
    periodEnd: DateTime(2026, 8, 26),
    total: total,
    previous: previous,
    mine: mine,
    minePrevious: minePrevious,
    categories: categories ??
        const [
          WeeklyCategoryCount(
              category: 'lists', count: 21, previous: 17, mine: 8),
          WeeklyCategoryCount(
              category: 'expenses', count: 8, previous: 10, mine: 2),
          WeeklyCategoryCount(
              category: 'chores', count: 11, previous: 5, mine: 2),
          WeeklyCategoryCount(
              category: 'meals', count: 5, previous: 5, mine: 0),
          WeeklyCategoryCount(
              category: 'recipes', count: 2, previous: 3, mine: 0),
        ],
    days: days ??
        List.generate(
          7,
          (i) => WeeklyDayCount(
              date: start.add(Duration(days: i)), count: i == 3 ? 0 : i + 2),
        ),
    activeMembers: activeMembers,
    memberCount: memberCount,
  );
}

Future<void> _pump(WidgetTester tester, WeeklySummary summary) async {
  await tester.binding.setSurfaceSize(const Size(900, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        weeklySummaryProvider(_groupId).overrideWith((ref) async => summary),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: WeeklySummaryScreen(groupId: _groupId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the household total, the delta, and every category',
      (tester) async {
    await _pump(tester, _summary());

    expect(find.text('Week in review'), findsOneWidget);
    // 47 vs 40 is +17.5%, rounded to 18.
    expect(find.text('18% vs last week'), findsOneWidget);
    expect(find.text('You contributed 12 of 47.'), findsOneWidget);

    for (final label in [
      'List items added',
      'Expenses logged',
      'Chores completed',
      'Meals planned',
      'Recipes added',
    ]) {
      expect(find.text(label), findsOneWidget, reason: 'missing $label');
    }

    // A category that fell shows a negative delta, one that rose a positive.
    expect(find.text('+4'), findsOneWidget); // lists 21 vs 17
    expect(find.text('−2'), findsOneWidget); // expenses 8 vs 10
    expect(find.text('—'), findsOneWidget); // meals 5 vs 5
  });

  testWidgets('a first week shows no percentage rather than "up 100%"',
      (tester) async {
    await _pump(tester, _summary(previous: 0, minePrevious: 0));

    expect(find.text('Your first week of activity'), findsOneWidget);
    expect(find.textContaining('% vs last week'), findsNothing);
  });

  testWidgets('an unchanged week reads as unchanged', (tester) async {
    await _pump(tester, _summary(total: 40, previous: 40));

    expect(find.text('Same as last week'), findsOneWidget);
  });

  testWidgets('nudges the user in when they contributed nothing',
      (tester) async {
    await _pump(tester, _summary(mine: 0, minePrevious: 0));

    expect(find.text('Jump in this week'), findsOneWidget);
    // Never congratulate someone who did nothing, even if the household rose.
    expect(find.text('You are on a roll'), findsNothing);
  });

  testWidgets('congratulates a household that improved', (tester) async {
    await _pump(tester, _summary());

    expect(find.text('You are on a roll'), findsOneWidget);
    expect(
        find.text('3 more than you did last week. Nice work.'), findsOneWidget);
  });

  testWidgets('does not congratulate a household that slowed', (tester) async {
    await _pump(tester, _summary(total: 30, previous: 40, minePrevious: 20));

    expect(find.text('A quieter week'), findsOneWidget);
    expect(find.text('You are on a roll'), findsNothing);
    expect(find.text('8 fewer than you did last week.'), findsOneWidget);
  });

  testWidgets('renders an empty state when the week had no activity',
      (tester) async {
    await _pump(
        tester,
        _summary(
          total: 0,
          previous: 0,
          mine: 0,
          minePrevious: 0,
          categories: const [
            WeeklyCategoryCount(
                category: 'lists', count: 0, previous: 0, mine: 0),
          ],
          days: List.generate(
            7,
            (i) => WeeklyDayCount(date: DateTime(2026, 8, 19 + i), count: 0),
          ),
          activeMembers: 0,
        ));

    expect(find.text('A quiet week'), findsOneWidget);
    // The breakdown and nudge belong to a week that actually happened.
    expect(find.text('Where it happened'), findsNothing);
  });

  testWidgets('shows a failure state with a retry when the load fails',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weeklySummaryProvider(_groupId)
              .overrideWith((ref) async => throw Exception('offline')),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: WeeklySummaryScreen(groupId: _groupId),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your week"), findsOneWidget);
    // AppButton uppercases its label.
    expect(find.text('RETRY'), findsOneWidget);
  });
}
