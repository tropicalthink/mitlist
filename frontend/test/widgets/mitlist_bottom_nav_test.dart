import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/theme/colors.dart';
import 'package:mitlist/theme/theme.dart';
import 'package:mitlist/widgets/mitlist_bottom_nav.dart';

const _items = [
  MitlistNavItem(iconName: 'home', label: 'Home'),
  MitlistNavItem(
      iconName: 'clipboardDocumentList', label: 'Chores', badgeCount: 3),
  MitlistNavItem(iconName: 'queueList', label: 'Kitchen'),
  MitlistNavItem(iconName: 'banknotes', label: 'Money', badgeCount: 12),
  MitlistNavItem(iconName: 'listBullet', label: 'Lists'),
];

Widget _harness({
  required int index,
  required ValueChanged<int> onTap,
  ThemeData? theme,
  bool animate = true,
  bool reducedMotion = false,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: theme ?? MitlistTheme.light,
    builder: (context, child) => Directionality(
      textDirection: direction,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reducedMotion,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    ),
    home: Scaffold(
      bottomNavigationBar: MitlistBottomNav(
        items: _items,
        currentIndex: index,
        animate: animate,
        onTap: onTap,
      ),
    ),
  );
}

/// The slab is the only [DecoratedBox] filled with the accent.
Rect _slabRect(WidgetTester tester) {
  final finder = find.byWidgetPredicate((w) {
    if (w is! DecoratedBox) return false;
    final d = w.decoration;
    return d is BoxDecoration &&
        (d.color == MitlistColors.primary500 ||
            d.color == MitlistColors.primary400);
  });
  expect(finder, findsOneWidget);
  return tester.getRect(finder);
}

/// Translation applied to a cell's content — the press-into-shadow move.
Vector3Like _cellShift(WidgetTester tester, String label) {
  final container = tester.widget<AnimatedContainer>(
    find
        .ancestor(
          of: find.text(label).first,
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  final t = container.transform!.getTranslation();
  return (x: t.x, y: t.y);
}

typedef Vector3Like = ({double x, double y});

void main() {
  testWidgets('reports the tapped tab', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(_harness(index: 0, onTap: taps.add));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Money').first);
    await tester.pumpAndSettle();

    expect(taps, [3]);
  });

  testWidgets('reports a tap on the tab already selected', (tester) async {
    // The shell turns this into "pop this branch to its root", so the widget
    // must not swallow it the way the old BottomNavigationBar wiring did.
    final taps = <int>[];
    await tester.pumpWidget(_harness(index: 2, onTap: taps.add));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kitchen').first);
    await tester.pumpAndSettle();

    expect(taps, [2]);
  });

  testWidgets('fires a haptic on tap', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String? ?? 'vibrate');
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(_harness(index: 0, onTap: (_) {}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chores').first);
    await tester.pumpAndSettle();

    expect(calls, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('shows a badge only where there is pending work', (tester) async {
    await tester.pumpWidget(_harness(index: 0, onTap: (_) {}));
    await tester.pumpAndSettle();

    // Badge digits are rendered by the odometer, which paints every digit 0-9
    // per wheel, so assert on the wheels rather than a '3' finder.
    expect(find.text('Home'), findsNWidgets(2)); // live row + clipped ink row
    final badges = find.byWidgetPredicate((w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).color == MitlistColors.error600);
    // Two tabs carry a count, drawn once per row copy.
    expect(badges, findsNWidgets(4));
  });

  testWidgets('presses the touched tab into its shadow and releases',
      (tester) async {
    await tester.pumpWidget(_harness(index: 0, onTap: (_) {}));
    await tester.pumpAndSettle();

    expect(_cellShift(tester, 'Money'), (x: 0.0, y: 0.0));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Money').first));
    await tester.pumpAndSettle();
    expect(_cellShift(tester, 'Money'), (x: 2.0, y: 2.0));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_cellShift(tester, 'Money'), (x: 0.0, y: 0.0));
  });

  testWidgets('slides the slab to the selected tab', (tester) async {
    await tester.pumpWidget(_harness(index: 0, onTap: (_) {}));
    await tester.pumpAndSettle();
    final start = _slabRect(tester).left;

    await tester.pumpWidget(_harness(index: 4, onTap: (_) {}));
    await tester.pump(const Duration(milliseconds: 60));
    final midway = _slabRect(tester).left;

    await tester.pumpAndSettle();
    final end = _slabRect(tester).left;

    expect(midway, greaterThan(start));
    expect(midway, lessThan(end));
    // It lands on the last cell.
    final width = tester.getSize(find.byType(MitlistBottomNav)).width;
    expect(end, closeTo(width * 4 / 5, 6));
  });

  testWidgets('with reduced motion the slab arrives without a slide',
      (tester) async {
    await tester
        .pumpWidget(_harness(index: 0, onTap: (_) {}, reducedMotion: true));
    await tester.pumpAndSettle();

    await tester
        .pumpWidget(_harness(index: 4, onTap: (_) {}, reducedMotion: true));
    await tester.pump();

    final width = tester.getSize(find.byType(MitlistBottomNav)).width;
    expect(_slabRect(tester).left, closeTo(width * 4 / 5, 6));
  });

  testWidgets('with reduced motion a press does not translate the cell',
      (tester) async {
    await tester
        .pumpWidget(_harness(index: 0, onTap: (_) {}, reducedMotion: true));
    await tester.pumpAndSettle();

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Money').first));
    await tester.pumpAndSettle();
    expect(_cellShift(tester, 'Money'), (x: 0.0, y: 0.0));
    await gesture.up();
  });

  testWidgets('does not slide while the shell is restoring the last tab',
      (tester) async {
    // A cold start opens on Home and then jumps to wherever the user was.
    // That jump must not be animated: the product loads into a task.
    await tester.pumpWidget(_harness(index: 0, onTap: (_) {}, animate: false));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_harness(index: 4, onTap: (_) {}, animate: false));
    await tester.pump();

    final width = tester.getSize(find.byType(MitlistBottomNav)).width;
    expect(_slabRect(tester).left, closeTo(width * 4 / 5, 6));
  });

  testWidgets('mirrors the slab in RTL', (tester) async {
    await tester.pumpWidget(
      _harness(index: 0, onTap: (_) {}, direction: TextDirection.rtl),
    );
    await tester.pumpAndSettle();

    final width = tester.getSize(find.byType(MitlistBottomNav)).width;
    // Index 0 is the rightmost cell when the layout is mirrored.
    expect(_slabRect(tester).left, closeTo(width * 4 / 5, 6));
  });

  testWidgets('exposes each tab as a selectable button with its count',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_harness(index: 1, onTap: (_) {}));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.text('Chores').first),
      matchesSemantics(
        label: 'Chores, 3',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
      ),
    );
    expect(
      tester.getSemantics(find.text('Kitchen').first),
      matchesSemantics(
        label: 'Kitchen',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('grows with the text scale instead of clipping labels',
      (tester) async {
    await tester.pumpWidget(_harness(index: 0, onTap: (_) {}));
    await tester.pumpAndSettle();
    final base = tester.getSize(find.byType(MitlistBottomNav)).height;

    await tester.pumpWidget(_harness(index: 0, onTap: (_) {}, textScale: 2.0));
    await tester.pumpAndSettle();
    final scaled = tester.getSize(find.byType(MitlistBottomNav)).height;

    expect(scaled, greaterThan(base));
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the ink offset visible in dark mode', (tester) async {
    // The offset stands in for a shadow; in dark mode the ink is the light
    // outline, and a hardcoded black one would vanish against the bar.
    await tester.pumpWidget(
        _harness(index: 0, onTap: (_) {}, theme: MitlistTheme.dark));
    await tester.pumpAndSettle();

    final slab = tester.widget<DecoratedBox>(
      find.byWidgetPredicate((w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == MitlistColors.primary400),
    );
    final decoration = slab.decoration as BoxDecoration;
    expect(decoration.boxShadow!.single.color, MitlistColors.surfaceSoft);
    expect(decoration.boxShadow!.single.blurRadius, 0);
  });
}
