import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/config/api_config.dart';
import 'package:mitlist/services/widgets/widget_credential_provisioner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_widget_bridge.dart';

class _IssuingAdapter implements HttpClientAdapter {
  final requests = <({
    String method,
    String path,
    Object? body,
    Map<String, dynamic> query
  })>[];
  var issued = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    String? body;
    if (requestStream != null) {
      body = utf8.decode(await requestStream.expand((c) => c).toList());
    }
    requests.add((
      method: options.method,
      path: options.path,
      body: body == null ? null : jsonDecode(body),
      query: options.queryParameters,
    ));
    if (options.method == 'POST') {
      issued++;
      return ResponseBody.fromString(
        jsonEncode({
          'id': 'cred-$issued',
          'kind': 'widget',
          'token': 'ml_int_token_$issued',
          'expires_at': '2027-01-01T00:00:00Z',
        }),
        201,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString('', 204);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeWidgetBridge bridge;
  late _IssuingAdapter adapter;
  late Dio dio;
  late DateTime now;
  late WidgetCredentialProvisioner provisioner;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    bridge = FakeWidgetBridge();
    adapter = _IssuingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
      ..httpClientAdapter = adapter;
    now = DateTime.utc(2026, 10, 2, 9);
    provisioner =
        WidgetCredentialProvisioner(dio: dio, bridge: bridge, now: () => now);
  });

  Future<bool> ensure([List<String> households = const ['h1', 'h2']]) =>
      provisioner.ensure(userId: 'user-1', householdIds: households);

  test('issues a credential for this install and hands it to native code',
      () async {
    expect(await ensure(), isTrue);
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/auth/widget-credential');
    final deviceId = (request.body as Map)['device_id'] as String;
    expect(deviceId, hasLength(36));
    expect(bridge.credential, {
      'token': 'ml_int_token_1',
      'expires_at': '2027-01-01T00:00:00Z',
      'api_base_url': '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}',
      'user_id': 'user-1',
      'device_id': deviceId,
    });
  });

  test('keeps a fresh credential and renews when anything changed', () async {
    await ensure();
    // Same households in another order, six days later: nothing to do.
    now = now.add(const Duration(days: 6));
    expect(await ensure(['h2', 'h1']), isFalse);

    // Joined a household: the credential must cover it.
    expect(await ensure(['h1', 'h2', 'h3']), isTrue);

    // A widget saw a 401.
    bridge.authFailed = true;
    expect(await ensure(['h1', 'h2', 'h3']), isTrue);

    // Native storage lost it (restored onto a new phone).
    bridge.credential = null;
    expect(await ensure(['h1', 'h2', 'h3']), isTrue);

    // Weekly renewal.
    now = now.add(const Duration(days: 8));
    expect(await ensure(['h1', 'h2', 'h3']), isTrue);
    expect(adapter.issued, 5);

    // One install, one device id throughout.
    final ids =
        adapter.requests.map((r) => (r.body as Map)['device_id']).toSet();
    expect(ids, hasLength(1));
  });

  test('sign-out revokes this install on the server', () async {
    await ensure();
    final deviceId = (adapter.requests.single.body as Map)['device_id'];
    await WidgetCredentialProvisioner.revokeOnSignOut(dio);
    final revoke = adapter.requests.last;
    expect(revoke.method, 'DELETE');
    expect(revoke.path, '/auth/widget-credential');
    expect(revoke.query, {'device_id': deviceId});
    // Signing back in issues again even within the week.
    bridge.credential = null;
    expect(await ensure(), isTrue);
  });
}
