import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/billing_models.dart';
import 'package:mitlist/providers/billing_provider.dart';

/// Guards the parsing of what the paywall shows. A price is the one thing on
/// that screen a customer can hold us to, so a malformed or missing plan must
/// degrade to "no price" rather than to a wrong one.
void main() {
  group('BillingStatus plans', () {
    test('parses provider capabilities and subscription provider', () {
      final status = BillingStatus.fromJson({
        'enabled': true,
        'web_enabled': false,
        'apple_enabled': true,
        'google_enabled': false,
        'free_limit': 4,
        'subscription': {
          'id': 'sub',
          'user_id': 'user',
          'provider': 'apple',
          'status': 'active',
        },
      });

      expect(status.webEnabled, isFalse);
      expect(status.appleEnabled, isTrue);
      expect(status.subscription?.provider, 'apple');
      // Widget tests run on the host platform, so an Apple-only server must not
      // advertise a checkout here.
      expect(billingCheckoutEnabled(status), isFalse);
    });

    test('parses plans for both intervals', () {
      final status = BillingStatus.fromJson({
        'enabled': true,
        'free_limit': 4,
        'plans': [
          {'interval': 'yearly', 'amount_cents': 1800, 'currency': 'EUR'},
          {'interval': 'monthly', 'amount_cents': 200, 'currency': 'EUR'},
        ],
      });

      expect(status.plans, hasLength(2));
      expect(status.planFor(BillingInterval.yearly)?.amountCents, 1800);
      expect(status.planFor(BillingInterval.monthly)?.amountCents, 200);
    });

    test('absent plans list leaves the paywall priceless, not broken', () {
      final status = BillingStatus.fromJson({'enabled': true, 'free_limit': 4});

      expect(status.plans, isEmpty);
      expect(status.planFor(BillingInterval.yearly), isNull);
      expect(status.enabled, isTrue);
    });

    test('drops a plan with an unrecognised interval', () {
      final status = BillingStatus.fromJson({
        'enabled': true,
        'free_limit': 4,
        'plans': [
          {'interval': 'weekly', 'amount_cents': 100, 'currency': 'EUR'},
          {'interval': 'yearly', 'amount_cents': 1800, 'currency': 'EUR'},
        ],
      });

      expect(status.plans, hasLength(1));
      expect(status.planFor(BillingInterval.yearly)?.amountCents, 1800);
    });

    test('normalises currency to upper case for formatting', () {
      final status = BillingStatus.fromJson({
        'enabled': true,
        'free_limit': 4,
        'plans': [
          {'interval': 'yearly', 'amount_cents': 1800, 'currency': 'eur'},
        ],
      });

      expect(status.planFor(BillingInterval.yearly)?.currency, 'EUR');
    });
  });

  group('HouseholdEntitlement', () {
    test('offers a move when the viewer pays for another household', () {
      final ent = HouseholdEntitlement.fromJson({
        'group_id': 'group-a',
        'member_count': 5,
        'free_limit': 4,
        'premium': false,
        'can_add_member': false,
        'viewer_subscribed': true,
        'viewer_primary_group_id': 'group-b',
      });

      expect(ent.canMovePremiumHere, isTrue);
      expect(ent.remainingFreeSlots, 0);
    });

    test('no move offered when premium already covers this household', () {
      final ent = HouseholdEntitlement.fromJson({
        'group_id': 'group-a',
        'member_count': 6,
        'free_limit': 4,
        'premium': true,
        'can_add_member': true,
        'viewer_subscribed': true,
        'viewer_primary_group_id': 'group-a',
      });

      expect(ent.canMovePremiumHere, isFalse);
      expect(ent.remainingFreeSlots, -1); // unlimited
    });

    test('non-subscriber is never offered a move', () {
      final ent = HouseholdEntitlement.fromJson({
        'group_id': 'group-a',
        'member_count': 4,
        'free_limit': 4,
        'premium': false,
        'can_add_member': false,
      });

      expect(ent.canMovePremiumHere, isFalse);
      expect(ent.viewerSubscribed, isFalse);
    });
  });
}
