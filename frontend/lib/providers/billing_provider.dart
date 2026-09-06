import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/billing_models.dart';
import '../services/billing_service.dart';
import '../services/iap_service.dart';
import 'auth_provider.dart' show authStateProvider, authServiceProviderAsync;

/// Provider for the BillingService instance.
final billingServiceProvider = FutureProvider<BillingService>((ref) async {
  return await BillingService.create(ref);
});

/// The native In-App Purchase service, used on iOS and Android in place of the
/// Polar hosted checkout. Kept alive for the session so the store's purchase
/// stream is observed continuously; disposed when no longer watched.
///
/// Callers should still gate on [IapService.isSupported] — on web and desktop
/// this resolves to a service whose platform checks all return false.
final iapServiceProvider = FutureProvider<IapService>((ref) async {
  ref.keepAlive();
  final billing = await ref.read(billingServiceProvider.future);
  final auth = await ref.read(authServiceProviderAsync.future);
  final service = IapService(billing, auth);
  service.start();
  ref.listen<bool>(authStateProvider, (previous, next) {
    if (next && previous != true) {
      service.retryPendingVerification();
    }
  });
  ref.onDispose(service.dispose);
  return service;
});

/// The signed-in user's billing position.
///
/// Resolves to [BillingStatus.disabled] rather than throwing when the request
/// fails: billing is an optional server feature, and a self-hosted instance or
/// an offline moment must never surface a broken paywall. Callers that need to
/// distinguish the two should use the service directly.
final billingStatusProvider = FutureProvider<BillingStatus>((ref) async {
  final isAuthenticated = ref.watch(authStateProvider);
  if (!isAuthenticated) return BillingStatus.disabled;

  final service = await ref.read(billingServiceProvider.future);
  try {
    return await service.getStatus();
  } catch (_) {
    return BillingStatus.disabled;
  }
});

/// Whether this particular client has a configured way to buy premium. The
/// server may have Apple enabled while this is an Android/desktop client (or
/// vice versa), which must not surface a checkout that cannot succeed.
bool billingCheckoutEnabled(BillingStatus status) {
  if (kIsWeb) return status.webEnabled;
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return status.appleEnabled;
    case TargetPlatform.android:
      return status.googleEnabled;
    default:
      return status.webEnabled;
  }
}

/// One household's premium position. Invalidate after joining, inviting, or
/// changing the premium household so member counts stay honest.
final householdEntitlementProvider =
    FutureProvider.family<HouseholdEntitlement?, String>((ref, groupId) async {
  final status = await ref.watch(billingStatusProvider.future);
  // No provider configured: there is no paywall to describe.
  if (!status.enabled ||
      (!status.isSubscribed && !billingCheckoutEnabled(status))) {
    return null;
  }

  final service = await ref.read(billingServiceProvider.future);
  try {
    return await service.getEntitlement(groupId);
  } catch (_) {
    return null;
  }
});

/// Whether the supporter pack's customisation (accent colours) applies for
/// the signed-in user.
///
/// Remembered across launches so the accent does not flash back to the
/// default while billing status loads. Only a real answer from the server
/// updates it; the [BillingStatus.disabled] placeholder a network failure
/// yields is ignored, so going offline neither grants nor revokes the perks.
final supporterPerksProvider =
    StateNotifierProvider<SupporterPerksNotifier, bool>((ref) {
  final notifier = SupporterPerksNotifier();
  ref.listen<AsyncValue<BillingStatus>>(billingStatusProvider, (_, next) {
    final status = next.valueOrNull;
    if (status == null || identical(status, BillingStatus.disabled)) return;
    notifier.setFromStatus(status);
  });
  return notifier;
});

class SupporterPerksNotifier extends StateNotifier<bool> {
  SupporterPerksNotifier({bool initial = false}) : super(initial) {
    _load();
  }

  static const _key = 'supporter_perks_unlocked';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_key);
      if (stored != null && mounted) state = stored;
    } catch (_) {
      // Preferences unavailable (tests, a broken platform channel): the
      // server answer will still arrive through setFromStatus.
    }
  }

  /// Applies what the server said. Persisted so the next launch starts from
  /// the same answer.
  Future<void> setFromStatus(BillingStatus status) async {
    final unlocked = status.supporterPerksUnlocked;
    if (state != unlocked) state = unlocked;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, unlocked);
    } catch (_) {}
  }
}

/// Refreshes everything billing-related. Call after a checkout returns or the
/// premium household moves.
///
/// Takes a [WidgetRef] because every caller is a widget reacting to something
/// the user just did; entitlement for *every* household is invalidated, since
/// moving premium changes two households at once.
void invalidateBilling(WidgetRef ref) {
  ref.invalidate(billingStatusProvider);
  ref.invalidate(householdEntitlementProvider);
}
