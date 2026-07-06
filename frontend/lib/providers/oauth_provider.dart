import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';

/// Which OAuth providers the backend is configured for.
typedef OAuthProviderAvailability = ({bool google, bool apple});

/// Fetches `/oauth/providers` so sign-in buttons for unconfigured providers
/// can be hidden instead of dead-ending at the backend. Fails safe to hiding
/// both buttons: email/password login is always available.
final oauthProvidersProvider = FutureProvider<OAuthProviderAvailability>((
  ref,
) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/oauth/providers');
    final data = response.data;
    if (data is! Map) {
      return (google: false, apple: false);
    }
    return (google: data['google'] == true, apple: data['apple'] == true);
  } catch (_) {
    return (google: false, apple: false);
  }
});
