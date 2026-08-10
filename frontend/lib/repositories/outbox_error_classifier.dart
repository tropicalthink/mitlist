import 'package:dio/dio.dart';

const int kOutboxMaxAttempts = 10;

/// How a failed outbox op should be treated.
///
/// [unreachable] is deliberately distinct from [transient]. Both mean "try
/// again later", but only [transient] counts toward [kOutboxMaxAttempts].
///
/// The attempt counter exists to give up on an op the *server* keeps rejecting.
/// A connection error means we never reached a server at all, so it is evidence
/// about the network, not about the op — counting it dead-lettered perfectly
/// good writes for the sole crime of being made offline. With the 5s drain
/// backoff, ~50 seconds of offline editing was enough to burn all 10 attempts
/// on the head-of-queue op and surface a permanent "Failed to save" for a
/// change the server had never once seen.
enum OutboxErrorDisposition { transient, unreachable, permanent, conflict }

OutboxErrorDisposition classifyOutboxError(Object error) {
  if (error is! DioException) return OutboxErrorDisposition.permanent;
  switch (error.type) {
    // Never got a connection, or gave up before the server could answer —
    // says nothing about whether the op itself is valid.
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.cancel:
      return OutboxErrorDisposition.unreachable;
    // Connected, but the exchange stalled. The server was reachable, so this
    // is real (if soft) evidence about the request.
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return OutboxErrorDisposition.transient;
    case DioExceptionType.badCertificate:
      return OutboxErrorDisposition.permanent;
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      break;
  }
  final status = error.response?.statusCode;
  // No response at all (an unwrapped SocketException and friends) — same
  // reasoning as the transport cases above: we never heard from a server.
  if (status == null) return OutboxErrorDisposition.unreachable;
  if (status == 409) return OutboxErrorDisposition.conflict;
  if (status == 408 || status == 429) return OutboxErrorDisposition.transient;
  if (status >= 500) return OutboxErrorDisposition.transient;
  if (status >= 400) return OutboxErrorDisposition.permanent;
  return OutboxErrorDisposition.transient;
}
