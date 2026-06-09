import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/theme.dart';
import 'router.dart';
import 'providers/outbox_provider.dart';
import 'services/api_client.dart' show createApiClient;
import 'providers/theme_provider.dart';
import 'services/error_reporter.dart';
import 'services/fcm_service.dart';
import 'services/push_subscription_service.dart';
import 'widgets/offline_banner.dart';

class MitlistApp extends ConsumerStatefulWidget {
  const MitlistApp({super.key});

  @override
  ConsumerState<MitlistApp> createState() => _MitlistAppState();
}

class _MitlistAppState extends ConsumerState<MitlistApp>
    with WidgetsBindingObserver {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription? _fcmSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ensure coordinator is initialized.
    ref.read(outboxCoordinatorProvider);

    ErrorReporter().init(
      dsn: const String.fromEnvironment('GLITCHTIP_DSN',
          defaultValue: ''),
      environment: const String.fromEnvironment('ENVIRONMENT',
          defaultValue: 'development'),
    );

    if (kReleaseMode) {
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        ErrorReporter().captureException(
          details.exception,
          stackTrace: details.stack,
        );
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        ErrorReporter().captureException(error, stackTrace: stack);
        return true;
      };
    }

    _initPushSubscriptions();
  }

  void _initPushSubscriptions() {
    PushSubscriptionService().init();
    FcmService.init(createApiClient()).then((_) {
      _fcmSub = FcmService.onForegroundMessage.listen((message) {
        final title = message.notification?.title;
        final body = message.notification?.body;
        if (title == null && body == null) return;
        _scaffoldMessengerKey.currentState
          ?..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (body != null) Text(body),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
      });
    });
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final coordinator = ref.read(outboxCoordinatorProvider).valueOrNull;
      coordinator?.drain();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'mitlist',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: MitlistTheme.light,
      darkTheme: MitlistTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return Column(
          children: [
            const OfflineBanner(),
            Expanded(child: child!),
          ],
        );
      },
    );
  }
}
