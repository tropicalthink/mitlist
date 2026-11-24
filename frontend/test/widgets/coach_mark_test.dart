import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/theme/theme.dart';
import 'package:mitlist/widgets/coach_mark.dart';

void main() {
  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

  testWidgets('results: next, skip, target tap, back', (tester) async {
    for (final (action, expected) in [
      ('next', CoachMarkResult.next),
      ('skip', CoachMarkResult.skip),
      ('target', CoachMarkResult.next),
      ('back', CoachMarkResult.dismissed),
    ]) {
      final target = GlobalKey();
      late BuildContext host;
      await tester.pumpWidget(MaterialApp(
        theme: MitlistTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          host = context;
          return Scaffold(
            body: Center(child: SizedBox(key: target, width: 60, height: 44)),
          );
        }),
      ));
      CoachMarkResult? result;
      unawaited(
          showCoachMark(host, target: target, message: 'Tip', step: 1, total: 2)
              .then((r) => result = r));
      await settle(tester);
      switch (action) {
        case 'next':
          await tester.tap(find.byKey(const ValueKey('coachMark-next')));
        case 'skip':
          await tester.tap(find.byKey(const ValueKey('coachMark-skip')));
        case 'target':
          await tester.tap(find.byKey(const ValueKey('coachMark-target')));
        case 'back':
          final nav = tester.state<NavigatorState>(find.byType(Navigator));
          unawaited(nav.maybePop());
      }
      await settle(tester);
      expect(result, expected, reason: action);
      expect(find.text('Tip'), findsNothing, reason: action);
    }
  });

  testWidgets('a tap on the dimmed backdrop does nothing', (tester) async {
    var tappedBelow = 0;
    final target = GlobalKey();
    late BuildContext host;
    await tester.pumpWidget(MaterialApp(
      theme: MitlistTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        host = context;
        return Scaffold(
          body: Stack(children: [
            Positioned.fill(
              child: GestureDetector(onTap: () => tappedBelow++),
            ),
            Center(child: SizedBox(key: target, width: 60, height: 44)),
          ]),
        );
      }),
    ));
    CoachMarkResult? result;
    unawaited(
        showCoachMark(host, target: target, message: 'Tip', step: 1, total: 1)
            .then((r) => result = r));
    await settle(tester);
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);
    expect(tappedBelow, 0);
    expect(result, isNull);
    expect(find.text('Tip'), findsOneWidget);
    // The last step says "Got it" and has no Skip.
    expect(find.byKey(const ValueKey('coachMark-skip')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('coachMark-next')));
    await settle(tester);
    expect(result, CoachMarkResult.next);
  });

  testWidgets('scrolls a target inside a scrollable into view first',
      (tester) async {
    final target = GlobalKey();
    late BuildContext host;
    await tester.pumpWidget(MaterialApp(
      theme: MitlistTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        host = context;
        return Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [
              const SizedBox(height: 3000),
              SizedBox(key: target, height: 44, child: const Text('Target')),
              const SizedBox(height: 600),
            ]),
          ),
        );
      }),
    ));
    unawaited(
        showCoachMark(host, target: target, message: 'Tip', step: 1, total: 1));
    await settle(tester);
    final rect = tester.getRect(find.text('Target'));
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.bottom, lessThanOrEqualTo(screen.height));
  });

  testWidgets(
      'targets at every edge, large text, dark theme: bubble stays on screen',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    for (final align in [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
      Alignment.center,
    ]) {
      final target = GlobalKey();
      late BuildContext host;
      await tester.pumpWidget(MaterialApp(
        theme: MitlistTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(builder: (context) {
          host = context;
          return Scaffold(
            body: Align(
                alignment: align,
                child: SizedBox(key: target, width: 48, height: 48)),
          );
        }),
      ));
      unawaited(showCoachMark(host,
          target: target,
          message: 'Share your calendar here, so the household knows when '
              "you're busy.",
          step: 2,
          total: 3));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: '$align');
      final bubble =
          tester.getRect(find.byKey(const ValueKey('coachMark-next')));
      expect(bubble.left, greaterThanOrEqualTo(0), reason: '$align');
      expect(bubble.right, lessThanOrEqualTo(390), reason: '$align');
      expect(bubble.top, greaterThanOrEqualTo(0), reason: '$align');
      expect(bubble.bottom, lessThanOrEqualTo(844), reason: '$align');
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(nav.maybePop());
      await settle(tester);
    }
  });

  testWidgets('follows the target when the screen size changes',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final target = GlobalKey();
    late BuildContext host;
    await tester.pumpWidget(MaterialApp(
      theme: MitlistTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        host = context;
        return Scaffold(
          body: Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(key: target, width: 48, height: 48)),
        );
      }),
    ));
    unawaited(
        showCoachMark(host, target: target, message: 'Tip', step: 1, total: 1));
    await settle(tester);
    Rect hole() =>
        tester.getRect(find.byKey(const ValueKey('coachMark-target')));
    expect(hole().center.dx, closeTo(390 - 24, 12));
    // Rotate.
    tester.view.physicalSize = const Size(844, 390);
    await settle(tester);
    expect(hole().center.dx, closeTo(844 - 24, 12));
    expect(hole().center.dy, closeTo(390 - 24, 12));
  });

  testWidgets('screen readers get a named route with the message and buttons',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final target = GlobalKey();
    late BuildContext host;
    await tester.pumpWidget(MaterialApp(
      theme: MitlistTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        host = context;
        return Scaffold(
          body: Center(child: SizedBox(key: target, width: 60, height: 44)),
        );
      }),
    ));
    unawaited(showCoachMark(host,
        target: target, message: 'Tip text', step: 2, total: 3));
    await settle(tester);
    expect(find.bySemanticsLabel('Tip 2 of 3'), findsOneWidget);
    expect(find.bySemanticsLabel('Tip text'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Skip', caseSensitive: false)),
        findsOneWidget);
    semantics.dispose();
  });

  testWidgets('with reduce motion it appears at once', (tester) async {
    final target = GlobalKey();
    late BuildContext host;
    await tester.pumpWidget(MaterialApp(
      theme: MitlistTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Builder(builder: (context) {
        host = context;
        return Scaffold(
          body: Center(child: SizedBox(key: target, width: 60, height: 44)),
        );
      }),
    ));
    unawaited(
        showCoachMark(host, target: target, message: 'Tip', step: 1, total: 1));
    await tester.pump();
    await tester.pump();
    // No fade: fully there after the first frames.
    expect(
        tester
            .widgetList<FadeTransition>(find.ancestor(
                of: find.text('Tip'), matching: find.byType(FadeTransition)))
            .where((f) => f.opacity.value < 1),
        isEmpty);
    expect(find.text('Tip'), findsOneWidget);
  });

  testWidgets('a target that is not on screen shows nothing', (tester) async {
    late BuildContext host;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        host = context;
        return const SizedBox();
      }),
    ));
    final result = await showCoachMark(host,
        target: GlobalKey(), message: 'Tip', step: 1, total: 1);
    expect(result, CoachMarkResult.missing);
  });
}
