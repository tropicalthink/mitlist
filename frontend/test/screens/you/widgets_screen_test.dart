import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/home_widgets_provider.dart';
import 'package:mitlist/providers/widget_discovery_provider.dart';
import 'package:mitlist/screens/you/widgets_screen.dart';
import 'package:mitlist/theme/theme.dart';
import 'package:mitlist/widgets/app_button.dart';
import 'package:mitlist/widgets/home_widget_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/widgets/fake_widget_bridge.dart';

final _household = Group(
  id: '11111111-1111-4111-8111-111111111111',
  name: 'Flat 3B',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Finder _addButtons() => find.byWidgetPredicate(
      (w) => w is AppButton && w.text == 'Add to home screen',
    );

Finder _card(String kind) => find.byKey(ValueKey('widgetsPage-$kind'));

Future<void> _pumpPage(
  WidgetTester tester, {
  required FakeWidgetBridge bridge,
  required TargetPlatform platform,
  ThemeData? theme,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 3200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        widgetBridgeProvider.overrideWithValue(bridge),
        homeWidgetPlatformProvider.overrideWithValue(platform),
        cachedGroupsProvider.overrideWith((ref) async => [_household]),
      ],
      child: MaterialApp(
        theme: theme ?? MitlistTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const WidgetsScreen(),
      ),
    ),
  );
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Android', () {
    testWidgets('one tap pins a widget; installed ones are marked added',
        (tester) async {
      final bridge = FakeWidgetBridge()
        ..pinSupported = true
        ..installed = const ['chores'];
      await _pumpPage(tester, bridge: bridge, platform: TargetPlatform.android);

      for (final kind in [
        'shopping_list',
        'chores',
        'quick_add',
        'household'
      ]) {
        expect(_card(kind), findsOneWidget, reason: kind);
      }
      // Chores is on the home screen already: no button there, a badge.
      expect(_addButtons(), findsNWidgets(3));
      expect(
        find.descendant(of: _card('chores'), matching: find.text('Added')),
        findsOneWidget,
      );
      expect(find.text('How to add a widget'), findsNothing);
      // The real household names the household preview.
      expect(
        find.descendant(of: _card('household'), matching: find.text('Flat 3B')),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: _card('shopping_list'), matching: _addButtons()),
      );
      await tester.pump();
      expect(bridge.pinRequests, ['shopping_list']);
      expect(find.text('How to add a widget'), findsNothing);
    });

    testWidgets('a refused pin falls back to the written steps',
        (tester) async {
      final bridge = FakeWidgetBridge()
        ..pinSupported = true
        ..pinShown = false;
      await _pumpPage(tester, bridge: bridge, platform: TargetPlatform.android);

      await tester.tap(
        find.descendant(of: _card('quick_add'), matching: _addButtons()),
      );
      await tester.pump();
      expect(bridge.pinRequests, ['quick_add']);
      expect(find.text('How to add a widget'), findsOneWidget);
      expect(
        find.text('Touch and hold an empty spot on your home screen.'),
        findsOneWidget,
      );
      // Let the toast run out.
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('without one-tap pinning the steps show and no buttons',
        (tester) async {
      final bridge = FakeWidgetBridge()..pinSupported = false;
      await _pumpPage(tester, bridge: bridge, platform: TargetPlatform.android);

      expect(find.text('How to add a widget'), findsOneWidget);
      expect(find.text('Tap Widgets and find mitlist.'), findsOneWidget);
      expect(_addButtons(), findsNothing);
    });
  });

  group('iOS', () {
    testWidgets('numbered steps, no pin buttons, every widget incl. quick add',
        (tester) async {
      final bridge = FakeWidgetBridge()
        ..pinSupported = true
        ..installed = const ['shopping_list'];
      await _pumpPage(tester, bridge: bridge, platform: TargetPlatform.iOS);

      expect(find.text('How to add a widget'), findsOneWidget);
      for (final n in ['1', '2', '3', '4']) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.text('Search for “mitlist”.'), findsOneWidget);
      expect(_addButtons(), findsNothing);
      for (final kind in [
        'shopping_list',
        'chores',
        'quick_add',
        'household'
      ]) {
        expect(_card(kind), findsOneWidget, reason: kind);
      }
      // iOS quick add is a small square widget: "Add to" + the list name.
      final quickAdd = find.descendant(
        of: _card('quick_add'),
        matching: find.byType(HomeWidgetPreview),
      );
      final size = tester.getSize(quickAdd);
      expect(size.width, moreOrLessEquals(size.height, epsilon: 0.5));
      expect(
        find.descendant(of: quickAdd, matching: find.text('Add to')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _card('shopping_list'),
          matching: find.text('Added'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders in dark mode with the installed state unknown',
        (tester) async {
      final bridge = FakeWidgetBridge()..installed = null;
      await _pumpPage(
        tester,
        bridge: bridge,
        platform: TargetPlatform.iOS,
        theme: MitlistTheme.dark,
      );

      expect(tester.takeException(), isNull);
      expect(_card('household'), findsOneWidget);
      expect(find.text('Added'), findsNothing);
    });
  });

  testWidgets('Android quick add is the wide bar, not the iOS square',
      (tester) async {
    await _pumpPage(
      tester,
      bridge: FakeWidgetBridge(),
      platform: TargetPlatform.android,
    );
    final quickAdd = find.descendant(
      of: _card('quick_add'),
      matching: find.byType(HomeWidgetPreview),
    );
    final size = tester.getSize(quickAdd);
    expect(size.width, greaterThan(size.height * 2));
    expect(
      find.descendant(of: quickAdd, matching: find.text('Add to the list')),
      findsOneWidget,
    );
  });

  testWidgets('kinds the page does not know are ignored', (tester) async {
    // iOS Balance or Controls, or a widget newer than this app build.
    final bridge = FakeWidgetBridge()
      ..installed = const ['balance', 'controls', 'chores', ''];
    await _pumpPage(tester, bridge: bridge, platform: TargetPlatform.iOS);

    expect(tester.takeException(), isNull);
    expect(find.text('Added'), findsOneWidget);
    expect(
      find.descendant(of: _card('chores'), matching: find.text('Added')),
      findsOneWidget,
    );
  });

  testWidgets('shows nothing where widgets are not supported', (tester) async {
    final bridge = _UnsupportedBridge();
    await _pumpPage(tester, bridge: bridge, platform: TargetPlatform.android);
    expect(_card('shopping_list'), findsNothing);
    expect(find.text('How to add a widget'), findsNothing);
  });
}

class _UnsupportedBridge extends FakeWidgetBridge {
  @override
  bool get isSupported => false;
}
