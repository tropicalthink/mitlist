/// Models for household premium billing.
///
/// A subscription covers exactly one household — the "premium household" — the
/// way a console is designated primary. The owner picks it at checkout and can
/// move it to another household they belong to at any time.
library;

import 'package:collection/collection.dart';

/// A premium subscription held by the signed-in user.
class BillingSubscription {
  final String id;
  final String userId;

  /// The single household this subscription makes premium. Null when the owner
  /// has not chosen one yet, in which case it covers nothing.
  final String? primaryGroupId;
  final String status;

  /// 'month' or 'year' as reported by the payment provider, when known.
  final String? recurringInterval;
  final int amountCents;
  final String currency;
  final DateTime? currentPeriodEnd;

  /// True when the subscription stays live until [currentPeriodEnd] and then
  /// stops. Entitlement is unaffected until that date passes.
  final bool cancelAtPeriodEnd;

  const BillingSubscription({
    required this.id,
    required this.userId,
    this.primaryGroupId,
    required this.status,
    this.recurringInterval,
    this.amountCents = 0,
    this.currency = 'eur',
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
  });

  factory BillingSubscription.fromJson(Map<String, dynamic> json) {
    return BillingSubscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      primaryGroupId: json['primary_group_id'] as String?,
      status: json['status'] as String? ?? 'active',
      recurringInterval: json['recurring_interval'] as String?,
      amountCents: json['amount_cents'] as int? ?? 0,
      currency: json['currency'] as String? ?? 'eur',
      currentPeriodEnd: json['current_period_end'] == null
          ? null
          : DateTime.tryParse(json['current_period_end'] as String),
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
    );
  }

  /// Whether this subscription is pinned to [groupId].
  bool coversGroup(String groupId) => primaryGroupId == groupId;
}

/// What one premium interval costs.
///
/// Read live from the payment provider rather than hardcoded, so the app can
/// never advertise a price the customer will not actually be charged.
class BillingPlan {
  final BillingInterval interval;
  final int amountCents;

  /// Upper-case ISO 4217 code, e.g. 'EUR'.
  final String currency;

  const BillingPlan({
    required this.interval,
    required this.amountCents,
    required this.currency,
  });

  /// Returns null for an interval the backend did not report, which happens
  /// when the provider was unreachable or the product has no sellable price.
  static BillingPlan? fromJson(Map<String, dynamic> json) {
    final wire = json['interval'] as String?;
    final interval =
        BillingInterval.values.where((i) => i.wire == wire).firstOrNull;
    if (interval == null) return null;
    return BillingPlan(
      interval: interval,
      amountCents: json['amount_cents'] as int? ?? 0,
      currency: (json['currency'] as String? ?? 'EUR').toUpperCase(),
    );
  }
}

/// The caller's own billing position, independent of any household.
class BillingStatus {
  /// False on servers with no payment provider configured — a self-hosted
  /// instance, typically. All billing UI is hidden when this is false.
  final bool enabled;

  /// Largest household size that stays free.
  final int freeLimit;

  /// What each interval costs. Empty when the payment provider could not be
  /// reached — the paywall still works, it just shows no price.
  final List<BillingPlan> plans;

  /// The caller's live subscription, or null when they hold none.
  final BillingSubscription? subscription;

  const BillingStatus({
    required this.enabled,
    required this.freeLimit,
    this.plans = const [],
    this.subscription,
  });

  /// A status that hides every billing entry point, used when the endpoint is
  /// unreachable so a network blip never shows a paywall.
  static const disabled = BillingStatus(enabled: false, freeLimit: 0);

  factory BillingStatus.fromJson(Map<String, dynamic> json) {
    final sub = json['subscription'];
    final rawPlans = json['plans'];
    return BillingStatus(
      enabled: json['enabled'] as bool? ?? false,
      freeLimit: json['free_limit'] as int? ?? 0,
      plans: rawPlans is List
          ? rawPlans
              .whereType<Map<String, dynamic>>()
              .map(BillingPlan.fromJson)
              .whereType<BillingPlan>()
              .toList()
          : const [],
      subscription: sub is Map<String, dynamic>
          ? BillingSubscription.fromJson(sub)
          : null,
    );
  }

  bool get isSubscribed => subscription != null;

  /// The plan for [interval], or null when the provider reported none.
  BillingPlan? planFor(BillingInterval interval) =>
      plans.where((p) => p.interval == interval).firstOrNull;
}

/// One household's premium position — what the paywall is rendered from.
class HouseholdEntitlement {
  final String groupId;
  final int memberCount;
  final int freeLimit;

  /// True when a member has designated this household as their premium
  /// household, which lifts the member limit for everyone in it.
  final bool premium;

  /// False when the household is at the free limit and nobody has paid.
  /// Existing members are never locked out — only growth is gated.
  final bool canAddMember;

  /// Display name of the member whose subscription covers this household.
  final String? coveredBy;

  /// Whether the caller personally holds a live subscription.
  final bool viewerSubscribed;

  /// Which household the caller's own subscription is pinned to. Together with
  /// [viewerSubscribed] this distinguishes "subscribe" from "move your premium
  /// here", so a paying user is never asked to pay twice.
  final String? viewerPrimaryGroupId;

  const HouseholdEntitlement({
    required this.groupId,
    required this.memberCount,
    required this.freeLimit,
    required this.premium,
    required this.canAddMember,
    this.coveredBy,
    this.viewerSubscribed = false,
    this.viewerPrimaryGroupId,
  });

  factory HouseholdEntitlement.fromJson(Map<String, dynamic> json) {
    return HouseholdEntitlement(
      groupId: json['group_id'] as String,
      memberCount: json['member_count'] as int? ?? 0,
      freeLimit: json['free_limit'] as int? ?? 0,
      premium: json['premium'] as bool? ?? false,
      canAddMember: json['can_add_member'] as bool? ?? true,
      coveredBy: json['covered_by'] as String?,
      viewerSubscribed: json['viewer_subscribed'] as bool? ?? false,
      viewerPrimaryGroupId: json['viewer_primary_group_id'] as String?,
    );
  }

  /// The caller pays already, but for a different household — so the fix is to
  /// move their premium here rather than buy a second subscription.
  bool get canMovePremiumHere =>
      viewerSubscribed && !premium && viewerPrimaryGroupId != groupId;

  /// How many more members may join before the paywall applies. Zero once the
  /// household is at or over the limit.
  int get remainingFreeSlots {
    if (premium) return -1; // unlimited
    final left = freeLimit - memberCount;
    return left < 0 ? 0 : left;
  }
}

/// Which recurring plan a checkout is for.
enum BillingInterval {
  monthly('monthly'),
  yearly('yearly');

  const BillingInterval(this.wire);

  /// The value the backend expects.
  final String wire;
}
