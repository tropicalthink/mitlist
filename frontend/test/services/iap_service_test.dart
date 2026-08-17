import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mitlist/services/auth_service.dart';
import 'package:mitlist/services/billing_service.dart';
import 'package:mitlist/services/iap_service.dart';
import 'package:mitlist/services/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StoreFailureAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/auth/me')) {
      return ResponseBody.fromString(
        '{"id":"11111111-1111-1111-1111-111111111111","email":"a@b.test","first_name":"A","last_name":"B","is_active":true,"is_verified":true,"is_guest":false,"created_at":"2026-01-01T00:00:00Z","updated_at":"2026-01-01T00:00:00Z"}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    return ResponseBody.fromString(
      '{"error":"verification unavailable"}',
      503,
      headers: {
        Headers.contentTypeHeader: ['application/json']
      },
    );
  }
}

class _StoreSuccessAdapter extends _StoreFailureAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/billing/iap/verify')) {
      return ResponseBody.fromString(
        '{"id":"sub","user_id":"11111111-1111-1111-1111-111111111111","provider":"google","status":"active"}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        },
      );
    }
    return super.fetch(options, requestStream, cancelFuture);
  }
}

class _FakeIap implements IapStore {
  final controller = StreamController<List<PurchaseDetails>>.broadcast();
  int completes = 0;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completes++;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async =>
      true;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(productDetails: const [], notFoundIDs: const []);
  @override
  Future<void> restorePurchases() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('backend verification failure leaves purchase unfinished for retry',
      () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues(
        {'iap_pending_group_id': 'group-a'});
    final prefs = await SharedPreferences.getInstance();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _StoreFailureAdapter();
    final auth = AuthService.forTest(dio, prefs, _MemoryTokenStore());
    final billing = BillingService.forTest(dio);
    final fakeIap = _FakeIap();
    final service = IapService(billing, auth, store: fakeIap);
    final result = service.results.first;
    service.start();

    final purchase = PurchaseDetails(
      purchaseID: 'purchase',
      productID: 'premium',
      verificationData: PurchaseVerificationData(
        localVerificationData: 'local',
        serverVerificationData: 'token',
        source: 'google_play',
      ),
      transactionDate: '1',
      status: PurchaseStatus.purchased,
    )..pendingCompletePurchase = true;
    fakeIap.controller.add([purchase]);

    expect((await result).status, IapStatus.error);
    expect(fakeIap.completes, 0);
    expect(
      await const FlutterSecureStorage().read(key: 'iap_pending_group_id'),
      'group-a',
    );
    await service.dispose();
    await fakeIap.controller.close();
  });

  test('successful retry acknowledges purchase and clears durable intent',
      () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues(
        {'iap_pending_group_id': 'group-a'});
    final prefs = await SharedPreferences.getInstance();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = _StoreSuccessAdapter();
    final fakeIap = _FakeIap();
    final service = IapService(
      BillingService.forTest(dio),
      AuthService.forTest(dio, prefs, _MemoryTokenStore()),
      store: fakeIap,
    );
    final result = service.results.first;
    service.start();
    final purchase = _purchase();
    fakeIap.controller.add([purchase]);

    expect((await result).status, IapStatus.success);
    expect(fakeIap.completes, 1);
    expect(
      await const FlutterSecureStorage().read(key: 'iap_pending_group_id'),
      isNull,
    );
    await service.dispose();
    await fakeIap.controller.close();
  });
}

PurchaseDetails _purchase() => PurchaseDetails(
      purchaseID: 'purchase',
      productID: 'premium',
      verificationData: PurchaseVerificationData(
        localVerificationData: 'local',
        serverVerificationData: 'token',
        source: 'google_play',
      ),
      transactionDate: '1',
      status: PurchaseStatus.purchased,
    )..pendingCompletePurchase = true;

class _MemoryTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}
  @override
  Future<String?> getAccessToken() async => null;
  @override
  Future<String?> getRefreshToken() async => null;
  @override
  Future<void> save(
      {required String accessToken, required String refreshToken}) async {}
}
