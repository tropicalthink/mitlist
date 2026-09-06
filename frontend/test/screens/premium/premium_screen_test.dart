import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/billing_models.dart';
import 'package:mitlist/providers/billing_provider.dart';
import 'package:mitlist/screens/premium/premium_pages.dart';
import 'package:mitlist/screens/premium/premium_screen.dart';
import 'package:mitlist/services/billing_service.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

const _groupId = 'group-1';

class _Launcher extends UrlLauncherPlatform {
  @override
  Null get linkDelegate => null;

  String? url;
  LaunchOptions? options;
  bool succeeds = true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    this.url = url;
    this.options = options;
    return succeeds;
  }
}

Future<GoRouter> _pumpRoutedScreen(
  WidgetTester tester, {
  bool pushed = false,
  Future<HouseholdEntitlement?> Function()? entitlement,
  BillingService? billing,
}) async {
  final router = GoRouter(
    initialLocation: pushed ? '/you' : '/premium/$_groupId',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: Text('Household home')),
      ),
      GoRoute(
        path: '/you',
        builder: (_, __) => const Scaffold(body: Text('Account screen')),
      ),
      GoRoute(
        path: '/premium/:groupId',
        builder: (_, __) => const PremiumScreen(groupId: _groupId),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      billingStatusProvider.overrideWith(
        (ref) async => const BillingStatus(enabled: true, freeLimit: 4),
      ),
      householdEntitlementProvider(_groupId).overrideWith(
        (ref) => entitlement?.call() ?? Future.value(_entitlement()),
      ),
      if (billing != null)
        billingServiceProvider.overrideWith((ref) async => billing),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  if (pushed) {
    unawaited(router.push('/premium/$_groupId'));
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return router;
}

HouseholdEntitlement _entitlement({
  int memberCount = 4,
  int freeLimit = 4,
  bool premium = false,
  bool canAddMember = false,
  String? coveredBy,
  bool viewerSubscribed = false,
  String? viewerPrimaryGroupId,
}) {
  return HouseholdEntitlement(
    groupId: _groupId,
    memberCount: memberCount,
    freeLimit: freeLimit,
    premium: premium,
    canAddMember: canAddMember,
    coveredBy: coveredBy,
    viewerSubscribed: viewerSubscribed,
    viewerPrimaryGroupId: viewerPrimaryGroupId,
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  HouseholdEntitlement entitlement,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // The plan page reads the catalog for its prices; an empty one renders
        // the tiles without them, which is the offline case.
        billingStatusProvider.overrideWith(
          (ref) async => const BillingStatus(enabled: true, freeLimit: 4),
        ),
        householdEntitlementProvider(_groupId).overrideWith(
          (ref) async => entitlement,
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PremiumScreen(groupId: _groupId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PremiumScreen', () {
    for (final skipToPlan in [false, true]) {
      for (final pushed in [false, true]) {
        testWidgets(
            'close exits ${skipToPlan ? 'plan' : 'intro'} '
            'after ${pushed ? 'push' : 'direct entry'}', (tester) async {
          await _pumpRoutedScreen(tester, pushed: pushed);
          await tester.pumpAndSettle();
          if (skipToPlan) {
            await tester.tap(find.text('Skip'));
            await tester.pumpAndSettle();
          }
          expect(find.byIcon(Icons.close), findsOneWidget);
          await tester.tap(find.byTooltip('Close'));
          await tester.pumpAndSettle();
          expect(find.text(pushed ? 'Account screen' : 'Household home'),
              findsOneWidget);
        });
      }
    }

    testWidgets('intro back returns home after direct entry', (tester) async {
      await _pumpRoutedScreen(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Household home'), findsOneWidget);
    });

    for (final state in ['loading', 'error', 'disabled', 'active', 'move']) {
      testWidgets('can close the $state panel', (tester) async {
        await _pumpRoutedScreen(tester, entitlement: () {
          switch (state) {
            case 'loading':
              return Completer<HouseholdEntitlement?>().future;
            case 'error':
              return Future.error(StateError('Unavailable'));
            case 'disabled':
              return Future.value(null);
            case 'active':
              return Future.value(_entitlement(premium: true));
            default:
              return Future.value(_entitlement(
                viewerSubscribed: true,
                viewerPrimaryGroupId: 'other-group',
              ));
          }
        });
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.text('Household home'), findsOneWidget);
      });
    }

    for (final scenario in [
      'success',
      'launch failure',
      'closed while waiting'
    ]) {
      testWidgets('hosted checkout: $scenario', (tester) async {
        final original = UrlLauncherPlatform.instance;
        final launcher = _Launcher()..succeeds = scenario != 'launch failure';
        UrlLauncherPlatform.instance = launcher;
        addTearDown(() {
          UrlLauncherPlatform.instance = original;
        });
        final response = Completer<String>();
        RequestOptions? request;
        final dio = Dio()
          ..interceptors.add(InterceptorsWrapper(
            onRequest: (options, handler) async {
              request = options;
              handler.resolve(Response(
                requestOptions: options,
                data: {'checkout_url': await response.future},
              ));
            },
          ));
        addTearDown(dio.close);
        await _pumpRoutedScreen(tester, billing: BillingService.forTest(dio));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('GET PREMIUM'));
        await tester.tap(find.text('GET PREMIUM'));
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(request?.path, '/billing/checkout');
        expect(request?.data, {'interval': 'yearly', 'group_id': _groupId});
        if (scenario == 'closed while waiting') {
          await tester.tap(find.byTooltip('Close'));
          await tester.pumpAndSettle();
        }
        response.complete('https://checkout.polar.sh/test');
        await tester.pumpAndSettle();
        if (scenario == 'closed while waiting') {
          expect(launcher.url, isNull);
          expect(find.text('Household home'), findsOneWidget);
        } else {
          expect(launcher.url, 'https://checkout.polar.sh/test');
          expect(launcher.options?.webOnlyWindowName, '_self');
          if (scenario == 'launch failure') {
            expect(find.text('GET PREMIUM'), findsOneWidget);
            expect(find.byTooltip('Close'), findsOneWidget);
          } else if (!kIsWeb) {
            expect(find.text('Household home'), findsOneWidget);
          }
        }
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant({TargetPlatform.linux}));
    }

    testWidgets('opens on the household it is selling a place in',
        (tester) async {
      await _pumpScreen(tester, _entitlement());

      expect(find.text('Room for one more'), findsOneWidget);
      expect(find.text('4 of 4 free places used'), findsOneWidget);
      // Four taken places, and the open one that is the whole argument.
      expect(find.byKey(const ValueKey('premium-seat-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('premium-seat-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('premium-seat-4')), findsNothing);
    });

    testWidgets('walks the value pages before it asks for money',
        (tester) async {
      await _pumpScreen(tester, _entitlement());

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Nobody buys the milk twice'), findsOneWidget);

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('One more person, one smaller bill'), findsOneWidget);

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Your turn comes round slower'), findsOneWidget);

      // The last step names where it is going rather than saying "next".
      await tester.tap(find.text('SEE THE PLAN'));
      await tester.pumpAndSettle();
      expect(find.text('Open the household'), findsOneWidget);
      expect(find.text('GET PREMIUM'), findsOneWidget);
    });

    testWidgets('skip jumps straight to the plan', (tester) async {
      await _pumpScreen(tester, _entitlement());

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Open the household'), findsOneWidget);
      // Nowhere left to skip to.
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('a covered household is told so, and sold nothing',
        (tester) async {
      await _pumpScreen(
        tester,
        _entitlement(premium: true, canAddMember: true, coveredBy: 'Ines'),
      );

      expect(find.text('Premium is active here'), findsOneWidget);
      expect(find.text('Premium on this household, paid by Ines.'),
          findsOneWidget);
      expect(find.text('GET PREMIUM'), findsNothing);
      expect(find.text('Skip'), findsNothing);
    });

    testWidgets(
        'a subscriber who pays elsewhere is offered the move, not a '
        'second subscription', (tester) async {
      await _pumpScreen(
        tester,
        _entitlement(
          viewerSubscribed: true,
          viewerPrimaryGroupId: 'other-group',
        ),
      );

      expect(find.text('Move your premium here'), findsOneWidget);
      expect(find.text('MOVE PREMIUM HERE'), findsOneWidget);
      expect(find.text('GET PREMIUM'), findsNothing);
    });
  });

  group('PremiumMoneyPage', () {
    testWidgets('shows the per-person share moving as the split changes',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: PremiumMoneyPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // $62.40 across the five of them.
      expect(find.text('5 ways · \$12.48 each'), findsOneWidget);

      // Take the newcomer out and everyone else pays more: the page's whole
      // argument, done as arithmetic rather than as a claim.
      await tester.tap(find.text('Mara'));
      await tester.pumpAndSettle();
      expect(find.text('4 ways · \$15.60 each'), findsOneWidget);
    });
  });
}
