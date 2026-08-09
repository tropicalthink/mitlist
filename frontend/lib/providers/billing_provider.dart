import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/billing_models.dart';
import '../services/billing_service.dart';
import 'auth_provider.dart' show authStateProvider;

/// Provider for the BillingService instance.
final billingServiceProvider = FutureProvider<BillingService>((ref) async {
  return await BillingService.create(ref);
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

/// One household's premium position. Invalidate after joining, inviting, or
/// changing the premium household so member counts stay honest.
final householdEntitlementProvider =
    FutureProvider.family<HouseholdEntitlement?, String>((ref, groupId) async {
  final status = await ref.watch(billingStatusProvider.future);
  // No provider configured: there is no paywall to describe.
  if (!status.enabled) return null;

  final service = await ref.read(billingServiceProvider.future);
  try {
    return await service.getEntitlement(groupId);
  } catch (_) {
    return null;
  }
});

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
