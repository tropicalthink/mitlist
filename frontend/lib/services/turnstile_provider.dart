import 'api_error_mapper.dart';

/// Supplies a Cloudflare Turnstile token for requests that need web abuse
/// protection. Mirrors `AppCheckTokenProvider` so guest creation can ask for
/// "whatever proof this platform offers" without branching on the platform.
abstract interface class TurnstileTokenProvider {
  /// Returns a single-use token, or null when Turnstile is not configured for
  /// this build.
  Future<String?> getToken();
}

/// Thrown when Turnstile is configured but cannot produce a token — a blocked
/// script, an expired challenge, a widget that never called back. Surfaced to
/// the user rather than swallowed, because the API will reject the sign-up.
class TurnstileUnavailableException extends ApiException {
  const TurnstileUnavailableException(super.message);
}
