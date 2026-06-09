import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

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

  // Register the background handler before runApp so it is available as soon
  // as the app process wakes for a background message.
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  runApp(const ProviderScope(child: MitlistApp()));
}
