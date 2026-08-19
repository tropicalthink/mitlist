import 'package:dio/dio.dart';

/// Options used when replaying a durable outbox operation.
///
/// The key is stable for the lifetime of the queued operation. The API uses it
/// to return the original result when a request was accepted but the client
/// timed out before receiving the response.
Options? outboxOptions(String? idempotencyKey) {
  if (idempotencyKey == null || idempotencyKey.isEmpty) return null;
  return Options(headers: {'Idempotency-Key': idempotencyKey});
}
