import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'config/api_config.dart';

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

  // Apply a self-hoster's server choice before anything touches the network.
  final prefs = await SharedPreferences.getInstance();
  ApiConfig.setRuntimeBaseUrl(prefs.getString(ApiConfig.serverUrlKey));

  // Register the background handler before runApp so it is available as soon
  // as the app process wakes for a background message.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

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
