import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/widgets/shell_branch_switcher.dart';

Widget _harness({
  required int index,
  bool reducedMotion = false,
  bool animate = true,
  TextDirection direction = TextDirection.ltr,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: Directionality(
      textDirection: direction,
      child: ShellBranchSwitcher(
        index: index,
        animate: animate,
        child: Text('branch $index'),
      ),
    ),
  );
}

double? _dx(WidgetTester tester) {
  final finder = find.byType(Transform);
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Transform>(finder.first).transform.getTranslation().x;
}

double? _opacity(WidgetTester tester) {
  final finder = find.byType(Opacity);
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Opacity>(finder.first).opacity;
}

void main() {
  testWidgets('sits still until the branch changes', (tester) async {
    await tester.pumpWidget(_harness(index: 0));
    await tester.pumpAndSettle();

    expect(find.text('branch 0'), findsOneWidget);
    expect(_dx(tester), isNull);
    expect(_opacity(tester), isNull);
  });

  testWidgets('slides a later branch in from the leading side', (tester) async {
    await tester.pumpWidget(_harness(index: 0));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_harness(index: 2));
    await tester.pump(const Duration(milliseconds: 20));

    final dx = _dx(tester)!;
    expect(dx, greaterThan(0));
    expect(dx, lessThanOrEqualTo(ShellBranchSwitcher.travel));
    expect(_opacity(tester), lessThan(1));
  });

  testWidgets('slides the other way when moving back', (tester) async {
    await tester.pumpWidget(_harness(index: 3));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_harness(index: 1));
    await tester.pump(const Duration(milliseconds: 20));

    expect(_dx(tester), lessThan(0));
  });

  testWidgets('mirrors the travel direction in RTL', (tester) async {
    await tester.pumpWidget(_harness(index: 0, direction: TextDirection.rtl));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_harness(index: 2, direction: TextDirection.rtl));
    await tester.pump(const Duration(milliseconds: 20));

    expect(_dx(tester), lessThan(0));
  });

  testWidgets('settles with no transform or opacity layer left behind',
      (tester) async {
    await tester.pumpWidget(_harness(index: 0));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_harness(index: 2));
    await tester.pumpAndSettle();

    expect(find.text('branch 2'), findsOneWidget);
    expect(_dx(tester), isNull);
    expect(_opacity(tester), isNull);
  });

  testWidgets('does not slide while the shell is restoring the last tab',
      (tester) async {
    await tester.pumpWidget(_harness(index: 0, animate: false));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_harness(index: 3, animate: false));
    await tester.pump();

    expect(find.text('branch 3'), findsOneWidget);
    expect(_dx(tester), isNull);
    expect(_opacity(tester), isNull);
  });

  testWidgets('with reduced motion the branch arrives instantly',
      (tester) async {
    await tester.pumpWidget(_harness(index: 0, reducedMotion: true));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_harness(index: 4, reducedMotion: true));
    await tester.pump();

    expect(find.text('branch 4'), findsOneWidget);
    expect(_dx(tester), isNull);
    expect(_opacity(tester), isNull);
  });
}
