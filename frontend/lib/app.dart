import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'l10n/app_localizations.dart';
import 'theme/theme.dart';
import 'router.dart';
import 'providers/list_provider.dart'
    show sseServiceProvider, grocerySeedProvider;
import 'providers/outbox_provider.dart';
import 'services/api_client.dart' show dioProvider;
import 'services/canonical_display.dart' show setGroceryDisplayLang;
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'services/error_reporter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/fcm_service.dart';
import 'services/push_subscription_service.dart';
import 'providers/billing_provider.dart' show iapServiceProvider;
import 'providers/initial_sync_provider.dart';
import 'services/iap_service.dart';
import 'widgets/offline_banner.dart';

import 'widgets/app_toast.dart';
import 'utils/notification_navigation.dart';
import 'utils/notification_copy.dart';

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
      dsn: const String.fromEnvironment('GLITCHTIP_DSN', defaultValue: ''),
      environment: const String.fromEnvironment('ENVIRONMENT',
          defaultValue: 'development'),
    );
    if (IapService.isSupported) {
      // The store can redeliver unfinished transactions before authentication
      // finishes. Subscribe immediately; failed delivery is retained and
      // retried after the authenticated bootstrap below.
      unawaited(ref.read(iapServiceProvider.future));
    }
  }

  void _ensureDeferredInit() {
    if (_deferredInitDone || !ref.read(authStateProvider)) return;
    _deferredInitDone = true;
    ref.read(outboxCoordinatorProvider);
    // Cold-start pull of the active household, so screens never sit on stale
    // cache without at least attempting (and surfacing) a refresh.
    unawaited(ref.read(initialSyncProvider.notifier).start());
    // Kick off the grocery/alias seed as early as possible (app bootstrap,
    // right after auth) rather than waiting for whichever screen the user
    // opens first — it's a one-time but heavy load (~280k alias rows) that
    // shares the same serial DB connection as interactive list writes, so
    // starting it here gives it a head start before the user is likely to be
    // actively typing into a list.
    ref.read(grocerySeedProvider);
    if (IapService.isSupported) {
      unawaited(
        ref
            .read(iapServiceProvider.future)
            .then((service) => service.retryPendingVerification()),
      );
    }
    _initPushSubscriptions();
  }

  void _initPushSubscriptions() {
    PushSubscriptionService().init();
    FcmService.init(ref.read(dioProvider)).then((ready) {
      if (!ready || !mounted) return;

      _fcmSub = FcmService.onForegroundMessage.listen((message) {
        ref.invalidate(unreadNotificationCountProvider);
        final title = message.notification?.title;
        final body = message.notification?.body;
        if (title == null && body == null) return;
        final messenger = _scaffoldMessengerKey.currentState;
        if (messenger == null || !messenger.mounted) return;
        final l10n = AppLocalizations.of(messenger.context);
        final text = l10n == null
            ? null
            : resolveNotificationText(
                l10n: l10n,
                fallbackTitle: title ?? '',
                fallbackBody: body ?? title ?? '',
                data: message.data,
              );
        AppToast.notification(
          messenger,
          // A push with only a title has nothing to put underneath it, so the
          // title becomes the body rather than being printed twice.
          title: text == null || text.title.isEmpty ? null : text.title,
          body: text?.body ?? body ?? title!,
          actionLabel: l10n == null
              ? null
              : _notificationActionLabel(message.data['screen'], l10n),
          onAction: () => unawaited(_handleNotificationTap(message)),
        );
      });

      _fcmTapSub = FcmService.onNotificationTap.listen(_handleNotificationTap);

      FcmService.checkInitialMessage().then((msg) {
        if (msg != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _handleNotificationTap(msg),
          );
        }
      });
    });
  }

  String _notificationActionLabel(
    String? screen,
    AppLocalizations l10n,
  ) {
    return switch (screen) {
      'listDetail' => l10n.notificationsOpenList,
      'choreDetail' => l10n.notificationsOpenChore,
      'expenseDetail' ||
      'settlements' ||
      'recurringExpenses' =>
        l10n.notificationsOpenMoney,
      'mealPlan' || 'recipeDetail' => l10n.notificationsOpenRecipes,
      'householdHub' => l10n.notificationsOpenHousehold,
      _ => l10n.commonView,
    };
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    final bootstrap = ref.read(authBootstrapProvider);
    if (bootstrap.isLoading || !ref.read(authStateProvider)) {
      return;
    }
    final data = message.data;
    final notificationId = data['notification_id'];
    if (notificationId != null && notificationId.isNotEmpty) {
      unawaited(_markPushNotificationRead(notificationId));
    }
    final router = ref.read(routerProvider);
    await navigateNotificationPayload(
      router,
      data,
      preserveInbox: false,
      switchGroup: (groupId) =>
          ref.read(currentGroupIdProvider.notifier).set(groupId),
    );
  }

  Future<void> _markPushNotificationRead(String notificationId) async {
    try {
      final service = await ref.read(notificationServiceProviderAsync.future);
      await service.markAsRead(notificationId);
      ref.invalidate(unreadNotificationCountProvider);
    } catch (_) {
      // Navigation should still succeed offline; the inbox remains canonical.
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
      // Whatever the connectivity service believes right now was learned before
      // we lost the foreground, when the OS may have been holding our network
      // down. Clear it first so the drain below decides on a fresh probe.
      ref.read(connectivityServiceProvider).reset();
      final coordinator = ref.read(outboxCoordinatorProvider).valueOrNull;
      coordinator?.drain();
      // Force-reconnect SSE — the OS may have silently killed the connection
      // while the app was backgrounded.
      ref.read(sseServiceProvider).reconnect();
      if (IapService.isSupported && ref.read(authStateProvider)) {
        unawaited(
          ref
              .read(iapServiceProvider.future)
              .then((service) => service.retryPendingVerification()),
        );
      }
      // Re-run the banner state now rather than waiting out the poll interval,
      // so a stale offline bar never survives into the first visible frame.
      ref.invalidate(outboxStateProvider);
      ref.invalidate(unreadNotificationCountProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(authStateProvider, (previous, authenticated) {
      if (!authenticated) {
        _deferredInitDone = false;
        ref.read(initialSyncProvider.notifier).reset();
        ref.invalidate(unreadNotificationCountProvider);
        unawaited(_fcmSub?.cancel());
        unawaited(_fcmTapSub?.cancel());
        _fcmSub = null;
        _fcmTapSub = null;
      } else if (previous == false) {
        _ensureDeferredInit();
      }
    });
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
    final accent = ref.watch(effectiveAccentProvider);
    final locale = ref.watch(localeProvider);
    // Keep the grocery label language in sync with the app locale so canonical
    // items render in the user's language (de/en/fr/es shipped in the seed).
    setGroceryDisplayLang(locale?.languageCode);

    return MaterialApp.router(
      title: 'mitlist',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: MitlistTheme.lightWith(accent),
      darkTheme: MitlistTheme.darkWith(accent),
      themeMode: themeMode,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        final showBanner = ref.watch(outboxStateProvider).maybeWhen(
              data: (state) => state.status != OutboxStatus.online,
              orElse: () => false,
            );

        var content = child!;
        if (showBanner) {
          final mediaQuery = MediaQuery.of(context);
          content = MediaQuery(
            data: mediaQuery.copyWith(
              padding: mediaQuery.padding.copyWith(top: 0),
            ),
            child: content,
          );
        }

        return Column(
          children: [
            const OfflineBanner(),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}
