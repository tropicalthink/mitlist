import 'package:flutter_web_plugins/url_strategy.dart';

/// Routes on the URL path (see main.dart) but keeps the `#fragment` in the
/// location handed to the router.
///
/// Plain [usePathUrlStrategy] reads only pathname + search, and the engine
/// rewrites the browser URL from that reading the moment history initialises,
/// so a fragment is gone before any widget can look at it. The OAuth callback
/// depends on it: the backend redirects a web sign-in to
/// `/auth/callback#provider=…&handoff=…` so the one-time code stays out of
/// server logs and referrers, and without the fragment the callback screen
/// sees no parameters at all.
void usePathUrlStrategyKeepingFragment() {
  setUrlStrategy(PathUrlStrategy(BrowserPlatformLocation(), true));
}
