import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reproduction: reqtrack answers a successful submission with `201` and a JSON
/// body. Does `post<void>` survive that?
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  // What reqtrack actually returns on success.
  const acceptedBody =
      '{"submissionId":"sub_123","requestId":"req_456","status":"new"}';

  test('post<void> against a 201 JSON body', () async {
    final dio = Dio()..httpClientAdapter = _FakeAdapter(201, acceptedBody);

    await dio.post<void>('/api/v1/intake/requests', data: {'text': 'hello'});
  });

  test('post<Map> against the same response', () async {
    final dio = Dio()..httpClientAdapter = _FakeAdapter(201, acceptedBody);

    final res = await dio.post<Map<String, dynamic>>(
      '/api/v1/intake/requests',
      data: {'text': 'hello'},
    );
    expect(res.statusCode, 201);
    expect(jsonEncode(res.data), acceptedBody);
  });
}
