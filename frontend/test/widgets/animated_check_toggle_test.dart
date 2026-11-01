import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/theme/theme.dart';
import 'package:mitlist/widgets/animated_check_toggle.dart';

Widget _host(bool value) => MaterialApp(
      theme: MitlistTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body:
            Center(child: AnimatedCheckToggle(value: value, onChanged: (_) {})),
      ),
    );

Color? _fill(WidgetTester tester) {
  final box = tester.widget<Container>(
    find.descendant(
      of: find.byType(AnimatedCheckToggle),
      matching: find.byType(Container),
    ),
  );
  return (box.decoration as BoxDecoration?)?.color;
}

void main() {
  testWidgets('a box ticked in place fills, not just its tick mark',
      (tester) async {
    await tester.pumpWidget(_host(false));
    final primary = MitlistTheme.light.colorScheme.primary;
    expect(_fill(tester), isNot(primary));

    // Only the toggle's own value changes: nothing else rebuilds it.
    await tester.pumpWidget(_host(true));
    await tester.pumpAndSettle();

    expect(_fill(tester), primary);
  });
}
