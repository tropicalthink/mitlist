import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:logger/logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/iap_config.dart';
import '../models/billing_models.dart';
import 'auth_service.dart';
import 'billing_service.dart';

/// Outcome of a native purchase attempt, delivered on [IapService.results].
enum IapStatus { success, canceled, pending, error }

/// One result event from the purchase stream.
class IapResult {
  const IapResult(this.status, {this.error});

  final IapStatus status;
  final Object? error;
}

/// Narrow store seam so verification and acknowledgement can be tested without
/// installing a native StoreKit or Play Billing implementation.
abstract class IapStore {
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids);
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
  Future<void> restorePurchases();
  Future<void> completePurchase(PurchaseDetails purchase);
}

class PluginIapStore implements IapStore {
  PluginIapStore([InAppPurchase? plugin])
      : _plugin = plugin ?? InAppPurchase.instance;

  final InAppPurchase _plugin;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _plugin.purchaseStream;
  @override
  Future<bool> isAvailable() => _plugin.isAvailable();
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) =>
      _plugin.queryProductDetails(ids);
  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _plugin.buyNonConsumable(purchaseParam: purchaseParam);
  @override
  Future<void> restorePurchases() => _plugin.restorePurchases();
  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _plugin.completePurchase(purchase);
}

/// Drives native In-App Purchase on iOS and Android: StoreKit and Google Play
/// Billing via the `in_app_purchase` plugin.
///
/// Entitlement is never granted here. A completed purchase is forwarded to the
/// backend ([BillingService.verifyIap]), which validates it against the store
/// and records the subscription; only then does premium activate. This mirrors
/// the web flow, where the Polar webhook — not the client — activates premium.
///
/// Web and desktop are not supported; those platforms keep the Polar hosted
/// checkout. Callers must gate on [isSupported] before using this service.
class IapService {
  IapService(
    this._billing,
    this._auth, {
    IapStore? store,
    Logger? log,
    FlutterSecureStorage? storage,
  })  : _iap = store ?? PluginIapStore(),
        _log = log ?? Logger(),
        _storage = storage ?? const FlutterSecureStorage();

  final BillingService _billing;
  final AuthService _auth;
  final IapStore _iap;
  final Logger _log;
  final FlutterSecureStorage _storage;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final StreamController<IapResult> _results =
      StreamController<IapResult>.broadcast();
  List<ProductDetails> _products = const [];
  final Map<String, PurchaseDetails> _unverifiedPurchases = {};

  /// The household the in-flight purchase should cover, remembered so it can be
  /// sent to the backend when the (asynchronous) purchase result arrives.
  static const _pendingGroupKey = 'iap_pending_group_id';
  static const _pendingUserKey = 'iap_pending_user_id';
  String? _pendingGroupId;

  /// Whether native IAP is the purchase channel on this platform. Web and
  /// desktop fall back to the Polar hosted checkout.
  static bool get isSupported =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// A broadcast stream of purchase outcomes. The UI listens while a purchase
  /// is in flight and reacts to success, cancellation, or error.
  Stream<IapResult> get results => _results.stream;

  /// Begins listening to the store purchase stream. Idempotent. Should be called
  /// before [buy] so no result is missed; safe to call at app start too, which
  /// is where a delayed (pending → purchased) result would be delivered.
  void start() {
    _sub ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => _log.e('IAP purchase stream error: $e'),
    );
  }

  /// Clears purchase intent after authoritative delivery succeeds.
  Future<void> clearPendingIntent() async {
    _pendingGroupId = null;
    await _storage.delete(key: _pendingGroupKey);
    await _storage.delete(key: _pendingUserKey);
  }

  /// Retries store deliveries retained after an offline/auth/backend failure.
  /// The store transaction remains unfinished until one of these attempts is
  /// authoritatively accepted by the backend.
  Future<void> retryPendingVerification() async {
    for (final purchase in List<PurchaseDetails>.from(
      _unverifiedPurchases.values,
    )) {
      if (await _verify(purchase)) {
        _unverifiedPurchases.remove(_purchaseKey(purchase));
        await _complete(purchase);
      }
    }
  }

  /// Releases the stream subscription and result controller.
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    if (!_results.isClosed) await _results.close();
  }

  /// Whether the store is reachable and can transact.
  Future<bool> available() async {
    if (!isSupported) return false;
    return _iap.isAvailable();
  }

  /// Queries the store for the premium products and caches them. Returns an
  /// empty list when unsupported or when the store returned nothing (typically a
  /// product-id mismatch with the store console).
  Future<List<ProductDetails>> loadProducts() async {
    if (!isSupported) return const [];
    final ids = Platform.isIOS
        ? <String>{IapConfig.appleMonthly, IapConfig.appleYearly}
        : <String>{IapConfig.googleSubscriptionId};
    final response = await _iap.queryProductDetails(ids);
    if (response.notFoundIDs.isNotEmpty) {
      _log.w('IAP products not found in store: ${response.notFoundIDs}');
    }
    _products = response.productDetails;
    return _products;
  }

  /// The store's localized price string for an interval (e.g. "€29.99"), or null
  /// when the product has not loaded. This is the source of truth for the mobile
  /// price — it reflects the store's own conversion and the viewer's locale.
  String? priceLabel(BillingInterval interval) => _productFor(interval)?.price;

  /// Starts a purchase for [interval], covering [groupId]. The result is
  /// delivered asynchronously on [results]; this future completes once the
  /// store UI has been handed the request.
  Future<void> buy({
    required BillingInterval interval,
    String? groupId,
  }) async {
    if (!isSupported) {
      throw StateError('native IAP is not supported on this platform');
    }
    start();
    if (_products.isEmpty) await loadProducts();

    final product = _productFor(interval);
    if (product == null) {
      throw StateError('the store has no product for this plan');
    }

    // Stamp the purchase with the mitlist user id, so the backend and the store
    // notifications can resolve it to an account without trusting a client call.
    // On iOS this becomes appAccountToken; on Android, obfuscatedAccountId.
    final userId = (await _auth.getMe()).id;
    final pendingUserId = await _storage.read(key: _pendingUserKey);
    if (pendingUserId != null && pendingUserId != userId) {
      throw StateError(
        'an unfinished purchase belongs to another signed-in account',
      );
    }
    _pendingGroupId = groupId;
    if (groupId == null) {
      await _storage.delete(key: _pendingGroupKey);
    } else {
      await _storage.write(key: _pendingGroupKey, value: groupId);
    }
    await _storage.write(key: _pendingUserKey, value: userId);

    final PurchaseParam param;
    if (product is GooglePlayProductDetails) {
      param = GooglePlayPurchaseParam(
        productDetails: product,
        applicationUserName: userId,
        offerToken: product.offerToken,
      );
    } else {
      param = PurchaseParam(
        productDetails: product,
        applicationUserName: userId,
      );
    }
    final accepted = await _iap.buyNonConsumable(purchaseParam: param);
    if (!accepted) {
      await clearPendingIntent();
      throw StateError(
          'The store did not start the purchase. Please try again.');
    }
  }

  /// Restores previously bought subscriptions. Required by App Store review, and
  /// how a user recovers premium on a reinstalled or new device. Restored
  /// purchases flow through the same verification as new ones.
  Future<void> restore({String? groupId}) async {
    if (!isSupported) return;
    start();
    _pendingGroupId = groupId;
    final userId = (await _auth.getMe()).id;
    final pendingUserId = await _storage.read(key: _pendingUserKey);
    if (pendingUserId != null && pendingUserId != userId) {
      throw StateError(
        'an unfinished purchase belongs to another signed-in account',
      );
    }
    await _storage.write(key: _pendingUserKey, value: userId);
    if (groupId != null) {
      await _storage.write(key: _pendingGroupKey, value: groupId);
    }
    await _iap.restorePurchases();
  }

  /// Resolves the [ProductDetails] for an interval. On iOS this is a direct
  /// product-id match; on Android the subscription is expanded into one offer
  /// per base plan, matched here by base-plan id.
  ProductDetails? _productFor(BillingInterval interval) {
    if (!isSupported) return null;
    if (Platform.isIOS) {
      final target = IapConfig.appleProduct(interval);
      for (final product in _products) {
        if (product.id == target) return product;
      }
      return null;
    }
    final targetBasePlan = IapConfig.googleBasePlan(interval);
    for (final product in _products) {
      if (product is GooglePlayProductDetails) {
        final offers = product.productDetails.subscriptionOfferDetails;
        final index = product.subscriptionIndex;
        if (offers != null && index != null && index < offers.length) {
          if (offers[index].basePlanId == targetBasePlan) return product;
        }
      }
    }
    return null;
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _emit(const IapResult(IapStatus.pending));
        case PurchaseStatus.canceled:
          _emit(const IapResult(IapStatus.canceled));
          await _complete(purchase);
        case PurchaseStatus.error:
          _log.e('IAP purchase error: ${purchase.error}');
          _emit(IapResult(IapStatus.error, error: purchase.error));
          await _complete(purchase);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final verified = await _verify(purchase);
          if (verified) {
            _unverifiedPurchases.remove(_purchaseKey(purchase));
            await _complete(purchase);
          } else {
            _unverifiedPurchases[_purchaseKey(purchase)] = purchase;
          }
      }
    }
  }

  /// Sends a completed purchase to the backend for verification and recording.
  Future<bool> _verify(PurchaseDetails purchase) async {
    try {
      final platform = Platform.isIOS ? 'apple' : 'google';
      _pendingGroupId ??= await _storage.read(key: _pendingGroupKey);
      final pendingUserId = await _storage.read(key: _pendingUserKey);
      final currentUserId = (await _auth.getMe()).id;
      if (pendingUserId != null && pendingUserId != currentUserId) {
        throw StateError('purchase belongs to another signed-in account');
      }
      await _billing.verifyIap(
        platform: platform,
        token: purchase.verificationData.serverVerificationData,
        groupId: _pendingGroupId,
      );
      await clearPendingIntent();
      _emit(const IapResult(IapStatus.success));
      return true;
    } catch (e) {
      _log.e('IAP backend verification failed: $e');
      _emit(IapResult(IapStatus.error, error: e));
      return false;
    }
  }

  /// Acknowledges a purchase to the store. Until this is called the store keeps
  /// re-delivering it (and, on Android, refunds an unacknowledged purchase).
  Future<void> _complete(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }

  void _emit(IapResult result) {
    if (!_results.isClosed) _results.add(result);
  }

  String _purchaseKey(PurchaseDetails purchase) =>
      purchase.purchaseID ??
      '${purchase.productID}:${purchase.verificationData.serverVerificationData.hashCode}';
}
