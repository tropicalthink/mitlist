import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/billing_models.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/providers/billing_provider.dart';
import 'package:mitlist/providers/theme_provider.dart';
import 'package:mitlist/theme/accent.dart';
import 'package:mitlist/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The supporter pack gates nothing a household needs, so the one thing that
/// must never go wrong is the unlock logic: a self-hosted server unlocks the
/// look for everyone, a hosted one only for people who paid.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BillingStatus supporter fields', () {
    test('parses the pack, the flag and the web offer', () {
      final status = BillingStatus.fromJson({
        'enabled': true,
        'web_enabled': true,
        'free_limit': 4,
        'supporter_enabled': true,
        'supporter': false,
        'supporter_plan': {
          'interval': 'once',
          'amount_cents': 499,
          'currency': 'eur',
        },
      });
      expect(status.supporterEnabled, isTrue);
      expect(status.supporter, isFalse);
      expect(status.supporterOffer?.amountCents, 499);
      expect(status.supporterOffer?.currency, 'EUR');
      expect(status.supporterPerksUnlocked, isFalse);
    });

    test('a server that does not sell the pack unlocks the perks', () {
      final status =
          BillingStatus.fromJson({'enabled': false, 'free_limit': 0});
      expect(status.supporterEnabled, isFalse);
      expect(status.supporterPerksUnlocked, isTrue);
    });

    test('a paid supporter has the perks', () {
      final status = BillingStatus.fromJson({
        'enabled': true,
        'free_limit': 4,
        'supporter_enabled': true,
        'supporter': true,
      });
      expect(status.supporterPerksUnlocked, isTrue);
    });

    test('older servers without the fields parse as not sold', () {
      final status = BillingStatus.fromJson({'enabled': true, 'free_limit': 4});
      expect(status.supporterEnabled, isFalse);
      expect(status.supporter, isFalse);
      expect(status.supporterOffer, isNull);
    });
  });

  test('GroupMemberProfile carries the supporter badge flag', () {
    final member = GroupMemberProfile.fromJson({
      'user_id': 'u1',
      'display_name': 'Ada',
      'role': 'member',
      'supporter': true,
    });
    expect(member.supporter, isTrue);
    expect(
      GroupMemberProfile.fromJson({'user_id': 'u2'}).supporter,
      isFalse,
    );
  });

  group('MitlistAccent', () {
    test('only the default accent is free', () {
      expect(MitlistAccent.defaultAccent.isFree, isTrue);
      for (final accent in MitlistAccent.values) {
        expect(accent.isFree, accent == MitlistAccent.defaultAccent);
      }
    });

    test('unknown persisted names fall back to the default', () {
      expect(MitlistAccent.fromName('violet'), MitlistAccent.violet);
      expect(MitlistAccent.fromName('mauve'), MitlistAccent.defaultAccent);
      expect(MitlistAccent.fromName(null), MitlistAccent.defaultAccent);
    });

    test('every accent builds both themes with its own primary', () {
      for (final accent in MitlistAccent.values) {
        final light = MitlistTheme.lightWith(accent);
        final dark = MitlistTheme.darkWith(accent);
        expect(light.colorScheme.primary, accent.palette.s500);
        expect(dark.colorScheme.primary, accent.palette.s400);
        expect(light.brightness, Brightness.light);
        expect(dark.brightness, Brightness.dark);
      }
      // The default accent is the original theme, unchanged.
      expect(MitlistTheme.light.colorScheme.primary,
          MitlistAccent.clementine.palette.s500);
    });
  });

  group('effectiveAccentProvider', () {
    test('renders the chosen accent only while the perks are unlocked',
        () async {
      final container = ProviderContainer(overrides: [
        supporterPerksProvider
            .overrideWith((ref) => SupporterPerksNotifier(initial: false)),
      ]);
      addTearDown(container.dispose);

      await container.read(accentProvider.notifier).set(MitlistAccent.sky);
      expect(container.read(accentProvider), MitlistAccent.sky);
      expect(
          container.read(effectiveAccentProvider), MitlistAccent.defaultAccent);

      await container.read(supporterPerksProvider.notifier).setFromStatus(
            BillingStatus.fromJson({
              'enabled': true,
              'free_limit': 4,
              'supporter_enabled': true,
              'supporter': true,
            }),
          );
      expect(container.read(effectiveAccentProvider), MitlistAccent.sky);

      // A refund takes the colour away without forgetting the choice.
      await container.read(supporterPerksProvider.notifier).setFromStatus(
            BillingStatus.fromJson({
              'enabled': true,
              'free_limit': 4,
              'supporter_enabled': true,
              'supporter': false,
            }),
          );
      expect(
          container.read(effectiveAccentProvider), MitlistAccent.defaultAccent);
      expect(container.read(accentProvider), MitlistAccent.sky);
    });

    test('the free accent never depends on the perks', () async {
      final container = ProviderContainer(overrides: [
        supporterPerksProvider
            .overrideWith((ref) => SupporterPerksNotifier(initial: false)),
      ]);
      addTearDown(container.dispose);
      expect(
          container.read(effectiveAccentProvider), MitlistAccent.defaultAccent);
    });

    test('a billing answer that arrived before the first read still unlocks',
        () async {
      // The theme never reads the perks while the default accent is chosen,
      // so the accent picker is usually the first reader — well after
      // /billing/status answered. That answer must not be missed.
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(overrides: [
        billingStatusProvider
            .overrideWith((ref) async => BillingStatus.fromJson({
                  'enabled': true,
                  'free_limit': 4,
                  'supporter_enabled': true,
                  'supporter': true,
                })),
      ]);
      addTearDown(container.dispose);
      await container.read(billingStatusProvider.future);

      container.read(supporterPerksProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(supporterPerksProvider), isTrue);
    });

    test('the unlock survives a restart through preferences', () async {
      SharedPreferences.setMockInitialValues(
          {'supporter_perks_unlocked': true, 'accent': 'berry'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Give both notifiers a turn to load their stored values.
      container.read(accentProvider);
      container.read(supporterPerksProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(effectiveAccentProvider), MitlistAccent.berry);
    });
  });
}
