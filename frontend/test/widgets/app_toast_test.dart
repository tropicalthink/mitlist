import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/theme/colors.dart';
import 'package:mitlist/theme/theme.dart';
import 'package:mitlist/widgets/app_toast.dart';

/// Pumps a screen with a button that fires [fire], then taps it.
Future<BuildContext> _fire(
  WidgetTester tester,
  void Function(BuildContext) fire, {
  ThemeData? theme,
}) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? MitlistTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            captured = context;
            return Center(
              child: ElevatedButton(
                onPressed: () => fire(context),
                child: const Text('go'),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
  return captured;
}

/// The tone swatch is the only box painted in one of the tone colours.
Color? _swatchColor(WidgetTester tester) {
  final tones = <Color>{
    MitlistColors.success700,
    MitlistColors.error600,
    MitlistColors.primary700,
  };
  for (final w in tester.widgetList<Container>(find.byType(Container))) {
    final d = w.decoration;
    if (d is BoxDecoration && tones.contains(d.color)) return d.color;
  }
  return null;
}

List<String> _hapticSpy(WidgetTester tester) {
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
  return calls;
}

void main() {
  testWidgets('a success and a failure no longer look identical',
      (tester) async {
    // The whole point of the layer: Material gave both the same grey pill.
    await _fire(tester, (c) => AppToast.success(c, 'Settlement recorded'));
    expect(_swatchColor(tester), MitlistColors.success700);

    await _fire(tester, (c) => AppToast.error(c, 'Settlement failed'));
    expect(_swatchColor(tester), MitlistColors.error600);

    await _fire(tester, (c) => AppToast.info(c, 'Timer done'));
    expect(_swatchColor(tester), MitlistColors.primary700);
  });

  testWidgets('errors stay on screen longer than confirmations',
      (tester) async {
    expect(AppToast.errorDuration, greaterThan(AppToast.successDuration));
    expect(AppToast.undoDuration, greaterThan(AppToast.errorDuration));

    await _fire(tester, (c) => AppToast.success(c, 'Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);

    await tester.pump(AppToast.successDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('a success feels different from a failure', (tester) async {
    final calls = _hapticSpy(tester);

    await _fire(tester, (c) => AppToast.success(c, 'Saved'));
    expect(calls, ['HapticFeedbackType.lightImpact']);

    calls.clear();
    await _fire(tester, (c) => AppToast.error(c, 'Nope'));
    expect(calls, ['vibrate']);

    // Info is a state notice, not something the user did. It stays silent.
    calls.clear();
    await _fire(tester, (c) => AppToast.info(c, 'Timer done'));
    expect(calls, isEmpty);
  });

  testWidgets('undo runs the callback and dismisses', (tester) async {
    var undone = false;
    await _fire(
      tester,
      (c) => AppToast.undo(
        c,
        message: 'Milk purchased',
        onUndo: () => undone = true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Milk purchased'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(undone, isTrue);
    expect(find.text('Milk purchased'), findsNothing);
  });

  testWidgets('a burst of confirmations does not queue up behind itself',
      (tester) async {
    // Material queues SnackBars, so five quick saves used to mean the user
    // watched five toasts drain long after the moment had passed.
    await tester.pumpWidget(
      MaterialApp(
        theme: MitlistTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  AppToast.success(context, 'first');
                  AppToast.success(context, 'second');
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);
  });

  testWidgets('the ink offset follows the theme so it survives dark mode',
      (tester) async {
    for (final (theme, expected) in [
      (MitlistTheme.light, MitlistColors.borderPrimary),
      (MitlistTheme.dark, MitlistColors.surfaceSoft),
    ]) {
      await _fire(tester, (c) => AppToast.success(c, 'Saved'), theme: theme);
      await tester.pumpAndSettle();

      final body = tester.widgetList<Container>(find.byType(Container)).firstWhere(
            (w) =>
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).boxShadow?.isNotEmpty == true &&
                (w.decoration as BoxDecoration).color !=
                    MitlistColors.success700,
          );
      final decoration = body.decoration as BoxDecoration;
      expect(decoration.boxShadow!.single.color, expected);
      expect(decoration.boxShadow!.single.blurRadius, 0);
    }
  });

  testWidgets('an action fires and the toast announces itself', (tester) async {
    final handle = tester.ensureSemantics();
    var tapped = false;
    await _fire(
      tester,
      (c) => AppToast.error(
        c,
        'Upload failed',
        actionLabel: 'Retry upload',
        onAction: () => tapped = true,
      ),
    );
    await tester.pumpAndSettle();

    // SnackBar declares its content a live region and merges the subtree, so
    // the toast announces as one node carrying the message and the action it
    // offers, and that node is activatable.
    final data = tester.getSemantics(find.text('Upload failed'))
        .getSemanticsData();
    expect(data.label, 'Upload failed\nRetry upload');
    expect(data.flagsCollection.isLiveRegion, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    await tester.tap(find.text('Retry upload'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
    handle.dispose();
  });

  testWidgets('a push with no body does not print its title twice',
      (tester) async {
    late ScaffoldMessengerState messenger;
    await tester.pumpWidget(
      MaterialApp(
        theme: MitlistTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              messenger = ScaffoldMessenger.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    AppToast.notification(messenger, title: null, body: 'Chore due today');
    await tester.pumpAndSettle();
    expect(find.text('Chore due today'), findsOneWidget);

    AppToast.notification(messenger, title: 'Rent', body: 'Due tomorrow');
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Due tomorrow'), findsOneWidget);
  });
}
