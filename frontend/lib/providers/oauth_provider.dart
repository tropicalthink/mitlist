import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';

/// Which sign-in methods the backend offers. `password` covers the whole
/// email + password surface: login, registration, reset and change-password.
/// `guest` is whether new guest accounts can be created at all.
typedef OAuthProviderAvailability = ({
  bool google,
  bool apple,
  bool password,
  bool guest,
});

/// What to assume when the server cannot be asked: no OAuth buttons (they
/// would dead-end), but the password form, because a backend too old to
/// report the flag offers passwords unconditionally. No guest door: it is
/// the abuse-prone one, so it only opens when the server says so.
const OAuthProviderAvailability _unknownAvailability =
    (google: false, apple: false, password: true, guest: false);

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
      // Missing key: a backend that predates GUEST_AUTH_ENABLED, which the
      // hosted service never ran with guests on anyway. Closed until told.
      guest: data['guest'] == true,
    );
  } catch (_) {
    return _unknownAvailability;
  }
});
