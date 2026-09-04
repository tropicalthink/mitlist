import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'config/api_config.dart';
import 'services/app_check_service.dart';
import 'services/fcm_service.dart';
import 'utils/url_strategy.dart';

/// Must be a top-level function so the OS can invoke it in a separate isolate.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase must be initialised before any Firebase services are used.
  await Firebase.initializeApp();
  // The OS displays the notification in the system tray automatically when a
  // notification payload is present.  Nothing more needed for the basic case.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web routes on the URL path, not the default `#/` fragment. Every link
  // that reaches the web app from outside — recipe share links (/r/<token>),
  // household invites (/join/<code>), the OAuth callback (/auth/callback) and
  // push notification clicks — is a plain path. Under the hash strategy the
  // browser loads index.html for that path but Flutter only reads the
  // fragment, so the route was silently dropped and every deep link landed
  // on /home or /welcome. nginx/default.conf serves index.html for unknown
  // paths so a direct request still reaches the router. The fragment has to
  // survive too: the OAuth callback arrives as /auth/callback#handoff=…, and
  // the stock path strategy discards it before the router runs. No-op off
  // the web.
  usePathUrlStrategyKeepingFragment();

  // Apply a self-hoster's server choice before anything touches the network.
  final prefs = await SharedPreferences.getInstance();
  ApiConfig.setRuntimeBaseUrl(prefs.getString(ApiConfig.serverUrlKey));

  // FCM is optional — only wire it up when google-services.json / GoogleService-Info.plist
  // are present (Firebase project created). Without them, push is disabled but the app runs.
  if (!kIsWeb && await FcmService.ensureFirebaseCore()) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // App Check is build-time opt-in and mobile-only: its web provider would be
  // reCAPTCHA Enterprise, and web uses Cloudflare Turnstile instead (see
  // TurnstileConfig). Official workflows enable it; self-hosted builds remain
  // Firebase-free unless their operator opts in. Activate it after Firebase
  // Core and before guest creation requests a token.
  await FirebaseAppCheckService.initialize();

  const dsn = String.fromEnvironment('GLITCHTIP_DSN', defaultValue: '');
  const env =
      String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');

  if (dsn.isEmpty) {
    runApp(const ProviderScope(child: MitlistApp()));
  } else {
    await SentryFlutter.init(
      (options) {
        options.dsn = dsn;
        options.environment = env;
        // Keep defaults conservative for a household app; no PII, no perf tracing.
        options.tracesSampleRate = 0.0;
      },
      appRunner: () => runApp(const ProviderScope(child: MitlistApp())),
    );
  }
}
