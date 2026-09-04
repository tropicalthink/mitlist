import '../models/billing_models.dart';

/// Store product identifiers for native In-App Purchase.
///
/// These MUST match exactly what is configured in App Store Connect and the
/// Play Console — a mismatch means the store returns no product and the paywall
/// shows nothing to buy. See docs/iap-subscriptions-plan.md for the pricing
/// (store prices sit slightly above the web prices to cover the store cut).
///
/// The backend maps the same ids to a billing interval via APPLE_IAP_PRODUCT_*
/// and GOOGLE_PLAY_PRODUCT_* — keep the two in sync.
class IapConfig {
  IapConfig._();

  // Apple: one distinct product id per interval, inside one subscription group.
  static const String appleMonthly = 'me.mitlist.premium.monthly';
  static const String appleYearly = 'me.mitlist.premium.yearly';

  // Google: one subscription product with two base plans. Play returns an
  // offer per base plan; the interval is selected by base-plan id, not product.
  static const String googleSubscriptionId = 'premium';
  static const String googleMonthlyBasePlan = 'premium-monthly';
  static const String googleYearlyBasePlan = 'premium-yearly';

  static const String appleManageSubscriptionsUrl =
      'https://apps.apple.com/account/subscriptions';
  static const String googleManageSubscriptionsUrl =
      'https://play.google.com/store/account/subscriptions?sku=$googleSubscriptionId&package=me.mitlist';

  // Public legal pages used on the store paywall. Override per deployment when
  // the hosted legal pages live elsewhere; these values are not secrets.
  static const String termsUrl = String.fromEnvironment(
    'TERMS_URL',
    defaultValue: 'https://mitlist.me/terms',
  );
  static const String privacyUrl = String.fromEnvironment(
    'PRIVACY_URL',
    defaultValue: 'https://mitlist.me/privacy',
  );

  /// The Apple product id for an interval.
  static String appleProduct(BillingInterval interval) =>
      interval == BillingInterval.yearly ? appleYearly : appleMonthly;

  /// The Google base-plan id for an interval.
  static String googleBasePlan(BillingInterval interval) =>
      interval == BillingInterval.yearly
          ? googleYearlyBasePlan
          : googleMonthlyBasePlan;
}
