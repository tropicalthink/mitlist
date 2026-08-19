import 'turnstile_provider.dart';

/// Non-web platforms have no Turnstile widget: mobile attests with App Check.
class TurnstileService implements TurnstileTokenProvider {
  const TurnstileService._();

  static const TurnstileService instance = TurnstileService._();

  @override
  Future<String?> getToken() async => null;
}
