import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';

/// Which sign-in methods the backend offers. `password` covers the whole
/// email + password surface: login, registration, reset and change-password.
typedef OAuthProviderAvailability = ({bool google, bool apple, bool password});

/// What to assume when the server cannot be asked: no OAuth buttons (they
/// would dead-end), but the password form, because a backend too old to
/// report the flag offers passwords unconditionally.
const OAuthProviderAvailability _unknownAvailability =
    (google: false, apple: false, password: true);

/// Fetches `/oauth/providers` so sign-in buttons and forms for methods the
/// server does not offer can be hidden instead of dead-ending at the backend.
final oauthProvidersProvider = FutureProvider<OAuthProviderAvailability>((
  ref,
) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/oauth/providers');
    final data = response.data;
    if (data is! Map) {
      return _unknownAvailability;
    }
    return (
      google: data['google'] == true,
      apple: data['apple'] == true,
      // Missing key: a backend that predates PASSWORD_AUTH_ENABLED.
      password: data['password'] != false,
    );
  } catch (_) {
    return _unknownAvailability;
  }
});
