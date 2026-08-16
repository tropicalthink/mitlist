import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/integration_credential_service.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add('${options.method} ${options.path}');
    if (options.method == 'GET') {
      return _json(200, [
        {
          'id': 'credential-1',
          'name': 'Home Assistant',
          'token_prefix': 'ml_int_abc',
          'group_ids': ['group-1'],
          'scopes': ['lists:read'],
          'created_at': '2026-08-16T10:00:00Z',
        },
      ]);
    }
    if (options.method == 'POST') {
      return _json(201, {
        'id': 'credential-2',
        'name': 'Wall tablet',
        'token_prefix': 'ml_int_xyz',
        'group_ids': ['group-1'],
        'scopes': ['lists:read', 'lists:write'],
        'created_at': '2026-08-16T10:00:00Z',
        'token': 'ml_int_secret',
      });
    }
    return ResponseBody.fromString('', 204);
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  test('uses the integration credentials endpoints and parses responses',
      () async {
    final adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'))
      ..httpClientAdapter = adapter;
    final service = IntegrationCredentialService(dio);

    final listed = await service.list();
    final created = await service.create(
      name: 'Wall tablet',
      groupIds: ['group-1'],
      scopes: ['lists:read', 'lists:write'],
    );
    await service.revoke('credential-2');

    expect(listed.single.id, 'credential-1');
    expect(created.credential.id, 'credential-2');
    expect(created.token, 'ml_int_secret');
    expect(adapter.requests, [
      'GET /auth/integration-credentials',
      'POST /auth/integration-credentials',
      'DELETE /auth/integration-credentials/credential-2',
    ]);
  });
}
