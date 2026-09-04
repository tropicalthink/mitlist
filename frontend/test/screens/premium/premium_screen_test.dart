import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/billing_models.dart';
import 'package:mitlist/providers/billing_provider.dart';
import 'package:mitlist/screens/premium/premium_pages.dart';
import 'package:mitlist/screens/premium/premium_screen.dart';

const _groupId = 'group-1';

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

    testWidgets('a subscriber who pays elsewhere is offered the move, not a '
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
