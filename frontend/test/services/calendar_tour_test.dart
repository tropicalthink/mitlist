import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/calendar_tour.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime(2026, 11, 24, 12);

  bool decide({
    DateTime? lastShownAt,
    bool? hasConnection = false,
    bool signedIn = true,
    bool hasHousehold = true,
    bool onboardingDone = true,
    bool otherPromoThisVisit = false,
    bool somethingOnTop = false,
  }) =>
      CalendarTourDecision.shouldShow(
        now: now,
        lastShownAt: lastShownAt,
        hasConnection: hasConnection,
        signedIn: signedIn,
        hasHousehold: hasHousehold,
        onboardingDone: onboardingDone,
        otherPromoThisVisit: otherPromoThisVisit,
        somethingOnTop: somethingOnTop,
      );

  group('CalendarTourDecision', () {
    test('first time: shown to a signed-in person with a household', () {
      expect(decide(), isTrue);
      // Even when the connection state is unknown (offline).
      expect(decide(hasConnection: null), isTrue);
    });

    test('never signed out, without a household or during onboarding', () {
      expect(decide(signedIn: false), isFalse);
      expect(decide(hasHousehold: false), isFalse);
      expect(decide(onboardingDone: false), isFalse);
    });

    test('never on a visit that already showed another promo', () {
      expect(decide(otherPromoThisVisit: true), isFalse);
    });

    test('never while a sheet, dialog or page is on top', () {
      expect(decide(somethingOnTop: true), isFalse);
    });

    test('never once the person has any calendar connection', () {
      expect(decide(hasConnection: true), isFalse);
      expect(
          decide(
              hasConnection: true,
              lastShownAt: now.subtract(const Duration(days: 400))),
          isFalse);
    });

    test('again every 42 days while nothing is connected', () {
      expect(
          decide(lastShownAt: now.subtract(const Duration(days: 41))), isFalse);
      expect(
          decide(lastShownAt: now.subtract(const Duration(days: 42))), isTrue);
    });

    test('an unknown connection state is not asked twice', () {
      expect(
          decide(
              hasConnection: null,
              lastShownAt: now.subtract(const Duration(days: 90))),
          isFalse);
    });
  });

  group('CalendarTourStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('is per account and survives (sign-out does not clear it)', () async {
      await CalendarTourStore.markShown('maya', now);
      expect(await CalendarTourStore.lastShownAt('maya'), now);
      expect(await CalendarTourStore.lastShownAt('jonas'), isNull);
    });
  });

  group('CalendarTourController', () {
    test('hands a step to the next screen once', () {
      final c = CalendarTourController(now: () => now);
      c.handOff(CalendarTourStep.calendarShare, index: 2, total: 3);
      expect(c.take(CalendarTourStep.sharedAdd), isNull);
      final p = c.take(CalendarTourStep.calendarShare)!;
      expect((p.index, p.total), (2, 3));
      expect(c.take(CalendarTourStep.calendarShare), isNull);
    });

    test('a hand-off nobody picked up in time ends the tour', () {
      var t = now;
      final c = CalendarTourController(now: () => t);
      c.handOff(CalendarTourStep.sharedAdd, index: 3, total: 3);
      t = t.add(const Duration(seconds: 30));
      expect(c.take(CalendarTourStep.sharedAdd), isNull);
      expect(c.active, isFalse);
    });
  });
}
