import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../models/billing_models.dart';
import 'api_client.dart';
import 'api_error_mapper.dart';

/// Talks to the backend's household premium endpoints.
///
/// Every call goes to the mitlist API with the user's Bearer token — unlike
/// [FeedbackService], which posts to a different host entirely.
class BillingService {
  final Dio _dio;
  final Logger _logger = Logger();

  BillingService._(this._dio);

  /// Creates an instance of BillingService.
  static Future<BillingService> create([Ref? ref]) async {
    final dio = resolveDio(ref);
    return BillingService._(dio);
  }

  /// The caller's own billing position.
  ///
  /// A server with no payment provider configured reports `enabled: false`,
  /// which hides billing UI entirely.
  Future<BillingStatus> getStatus() async {
    try {
      final response = await _dio.get('/billing/status');
      final data = response.data;
      if (data is! Map<String, dynamic>) return BillingStatus.disabled;
      return BillingStatus.fromJson(data);
    } on DioException catch (e) {
      _logger.e('Billing status failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  /// One household's premium position, including whether the caller could move
  /// their existing premium here.
  Future<HouseholdEntitlement> getEntitlement(String groupId) async {
    try {
      final response = await _dio.get('/billing/groups/$groupId/entitlement');
      return HouseholdEntitlement.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Entitlement fetch failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  /// Moves the caller's subscription to cover [groupId].
  ///
  /// The household it moves away from keeps every member it already has; it
  /// simply cannot add more once it is over the free limit.
  Future<BillingSubscription> setPremiumHousehold(String groupId) async {
    try {
      final response = await _dio.put('/billing/groups/$groupId/premium');
      return BillingSubscription.fromJson(response.data);
    } on DioException catch (e) {
      _logger.e('Set premium household failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  /// Starts a hosted checkout and returns the URL to send the user to.
  ///
  /// [groupId] is the household the subscription will cover once paid.
  Future<String> createCheckout({
    required BillingInterval interval,
    String? groupId,
  }) async {
    try {
      final response = await _dio.post('/billing/checkout', data: {
        'interval': interval.wire,
        if (groupId != null) 'group_id': groupId,
      });
      final url = response.data?['checkout_url'] as String?;
      if (url == null || url.isEmpty) {
        throw const ApiException('Checkout is unavailable right now.');
      }
      return url;
    } on DioException catch (e) {
      _logger.e('Create checkout failed: ${e.response?.data}');
      throw apiException(e);
    }
  }

  /// Returns a URL where the user manages payment method, invoices, and
  /// cancellation on the provider's own portal.
  Future<String> openPortal() async {
    try {
      final response = await _dio.post('/billing/portal');
      final url = response.data?['portal_url'] as String?;
      if (url == null || url.isEmpty) {
        throw const ApiException('The billing portal is unavailable.');
      }
      return url;
    } on DioException catch (e) {
      _logger.e('Open portal failed: ${e.response?.data}');
      throw apiException(e);
    }
  }
}
