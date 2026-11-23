import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/providers/auth_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/home_widgets_provider.dart';
import 'package:mitlist/providers/widget_discovery_provider.dart';
import 'package:mitlist/services/widgets/widget_promo.dart';
import 'package:mitlist/theme/theme.dart';
import 'package:mitlist/widgets/hub/widget_promo_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/widgets/fake_widget_bridge.dart';

const _primary = ValueKey('widgetPromo-add');
const _notNow = ValueKey('widgetPromo-notNow');
const _headline = 'Your shopping list, on your home screen';

/// Home stand-in: one button opens the sheet directly, one runs the gate.
Future<void> _pumpHome(
  WidgetTester tester, {
  required FakeWidgetBridge bridge,
  required TargetPlatform platform,
  DateTime Function()? clock,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) => Column(
              children: [
                TextButton(
                  onPressed: () => showWidgetPromoSheet(context, ref),
                  child: const Text('open'),
                ),
                TextButton(
                  onPressed: () => maybeOfferHomeWidgets(
                    context,
                    ref,
                    onboardingDone: true,
                  ),
                  child: const Text('offer'),
                ),
              ],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/you',
        builder: (context, state) => const Text('you'),
        routes: [
          GoRoute(
            path: 'widgets',
            name: 'widgets',
            builder: (context, state) =>
                const Scaffold(body: Text('widgets page')),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        widgetBridgeProvider.overrideWithValue(bridge),
        homeWidgetPlatformProvider.overrideWithValue(platform),
        authStateProvider.overrideWith((ref) => true),
        cachedGroupsProvider.overrideWith((ref) async => const []),
        if (clock != null) widgetPromoClockProvider.overrideWithValue(clock),
      ],
      child: MaterialApp.router(
        theme: MitlistTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.text(_headline), findsOneWidget);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('primary button', () {
    testWidgets('Android: pins the shopping list widget in one tap',
        (tester) async {
      final bridge = FakeWidgetBridge()..pinSupported = true;
      await _pumpHome(tester, bridge: bridge, platform: TargetPlatform.android);
      await _open(tester);
      expect(find.text('ADD TO HOME SCREEN'), findsOneWidget);

      await tester.tap(find.byKey(_primary));
      await tester.pumpAndSettle();
      expect(bridge.pinRequests, ['shopping_list']);
      expect(find.text(_headline), findsNothing);
      expect(find.text('widgets page'), findsNothing);
    });

    testWidgets('Android: a refused pin opens the Widgets page',
        (tester) async {
      final bridge = FakeWidgetBridge()
        ..pinSupported = true
        ..pinShown = false;
      await _pumpHome(tester, bridge: bridge, platform: TargetPlatform.android);
      await _open(tester);

      await tester.tap(find.byKey(_primary));
      await tester.pumpAndSettle();
      expect(bridge.pinRequests, ['shopping_list']);
      expect(find.text('widgets page'), findsOneWidget);
    });

    testWidgets('Android without pinning: opens the Widgets page',
        (tester) async {
      final bridge = FakeWidgetBridge()..pinSupported = false;
      await _pumpHome(tester, bridge: bridge, platform: TargetPlatform.android);
      await _open(tester);
      expect(find.text('SHOW ME HOW'), findsOneWidget);

      await tester.tap(find.byKey(_primary));
      await tester.pumpAndSettle();
      expect(bridge.pinRequests, isEmpty);
      expect(find.text('widgets page'), findsOneWidget);
    });

    testWidgets('iOS: opens the Widgets page', (tester) async {
      final bridge = FakeWidgetBridge()..pinSupported = true;
      await _pumpHome(tester, bridge: bridge, platform: TargetPlatform.iOS);
      await _open(tester);
      expect(find.text('SHOW ME HOW'), findsOneWidget);

      await tester.tap(find.byKey(_primary));
      await tester.pumpAndSettle();
      expect(bridge.pinRequests, isEmpty);
      expect(find.text('widgets page'), findsOneWidget);
    });
  });

  testWidgets('"Not now" closes the sheet and does nothing else',
      (tester) async {
    final bridge = FakeWidgetBridge()..pinSupported = true;
    await _pumpHome(tester, bridge: bridge, platform: TargetPlatform.android);
    await _open(tester);

    await tester.tap(find.byKey(_notNow));
    await tester.pumpAndSettle();
    expect(find.text(_headline), findsNothing);
    expect(bridge.pinRequests, isEmpty);
    expect(find.text('widgets page'), findsNothing);
  });

  group('gate', () {
    testWidgets('first visit shows it and records when', (tester) async {
      final now = DateTime(2026, 11, 22, 9);
      final bridge = FakeWidgetBridge()..installed = const [];
      await _pumpHome(
        tester,
        bridge: bridge,
        platform: TargetPlatform.android,
        clock: () => now,
      );

      await tester.tap(find.text('offer'));
      await tester.pumpAndSettle();
      expect(find.text(_headline), findsOneWidget);
      expect(await WidgetPromoStore.lastShownAt(), now);
    });

    testWidgets('not again within six weeks, again after with none installed',
        (tester) async {
      final shown = DateTime(2026, 10, 1, 9);
      SharedPreferences.setMockInitialValues({
        WidgetPromoStore.key: shown.millisecondsSinceEpoch,
      });
      var now = shown.add(const Duration(days: 41));
      final bridge = FakeWidgetBridge()..installed = const [];
      await _pumpHome(
        tester,
        bridge: bridge,
        platform: TargetPlatform.android,
        clock: () => now,
      );

      await tester.tap(find.text('offer'));
      await tester.pumpAndSettle();
      expect(find.text(_headline), findsNothing);

      now = shown.add(const Duration(days: 42));
      await tester.tap(find.text('offer'));
      await tester.pumpAndSettle();
      expect(find.text(_headline), findsOneWidget);
    });

    testWidgets('never with a widget installed or an unknown state later',
        (tester) async {
      final shown = DateTime(2026, 1, 1);
      SharedPreferences.setMockInitialValues({
        WidgetPromoStore.key: shown.millisecondsSinceEpoch,
      });
      final bridge = FakeWidgetBridge()..installed = null;
      await _pumpHome(
        tester,
        bridge: bridge,
        platform: TargetPlatform.android,
        clock: () => DateTime(2026, 11, 22),
      );

      await tester.tap(find.text('offer'));
      await tester.pumpAndSettle();
      expect(find.text(_headline), findsNothing);

      SharedPreferences.setMockInitialValues({});
      bridge.installed = const ['shopping_list'];
      final container = ProviderScope.containerOf(
        tester.element(find.text('offer')),
      );
      container.invalidate(installedHomeWidgetsProvider);
      await tester.tap(find.text('offer'));
      await tester.pumpAndSettle();
      expect(find.text(_headline), findsNothing);
    });
  });
}
