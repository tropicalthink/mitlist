import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'theme/theme.dart';
import 'router.dart';
import 'providers/list_provider.dart' show sseServiceProvider;
import 'providers/outbox_provider.dart';
import 'services/api_client.dart' show dioProvider;
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'services/error_reporter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
  StreamSubscription? _fcmTapSub;
  bool _deferredInitDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
  }

  void _ensureDeferredInit() {
    if (_deferredInitDone || !ref.read(authStateProvider)) return;
    _deferredInitDone = true;
    ref.read(outboxCoordinatorProvider);
    _initPushSubscriptions();
  }

  void _initPushSubscriptions() {
    PushSubscriptionService().init();
    FcmService.init(ref.read(dioProvider)).then((_) {
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

      _fcmTapSub =
          FcmService.onNotificationTap.listen(_handleNotificationTap);

      FcmService.checkInitialMessage().then((msg) {
        if (msg != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _handleNotificationTap(msg),
          );
        }
      });
    });
  }

  void _handleNotificationTap(RemoteMessage message) {
    final bootstrap = ref.read(authBootstrapProvider);
    if (bootstrap.isLoading || !ref.read(authStateProvider)) {
      return;
    }
    final data = message.data;
    final screen = data['screen'] as String?;
    final id = data['id'] as String?;
    final router = ref.read(routerProvider);
    if (screen == 'choreDetail') {
      router.goNamed('chores');
    } else if (screen == 'listDetail' && id != null) {
      router.goNamed('listDetail', pathParameters: {'listId': id});
    }
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    _fcmTapSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final coordinator = ref.read(outboxCoordinatorProvider).valueOrNull;
      coordinator?.drain();
      // Force-reconnect SSE — the OS may have silently killed the connection
      // while the app was backgrounded.
      ref.read(sseServiceProvider).reconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authBootstrapProvider, (prev, next) {
      next.whenData((authenticated) {
        if (authenticated) _ensureDeferredInit();
      });
    });
    if (ref.read(authStateProvider)) {
      _ensureDeferredInit();
    }

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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
