import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

import '../l10n/app_localizations.dart';
import '../repositories/widget_ops_repository.dart';
import '../services/api_client.dart' show dioProvider;
import '../services/server_language_sync.dart' show effectiveLanguageCode;
import '../services/widgets/app_shortcuts.dart';
import '../services/widgets/home_widgets_controller.dart';
import '../services/widgets/widget_bridge.dart';
import '../services/widgets/widget_credential_provisioner.dart';
import '../services/widgets/widget_snapshot_sync.dart';
import 'auth_provider.dart';
import 'chore_provider.dart';
import 'group_provider.dart';
import 'list_provider.dart';
import 'locale_provider.dart';

final widgetBridgeProvider =
    Provider<WidgetBridge>((ref) => WidgetBridge.instance);

final appShortcutsProvider = Provider<AppShortcuts>((ref) => AppShortcuts());

final widgetSnapshotSyncProvider = Provider<WidgetSnapshotSync>((ref) {
  final sync = WidgetSnapshotSync(
    dio: ref.watch(dioProvider),
    bridge: ref.watch(widgetBridgeProvider),
  );
  ref.onDispose(sync.dispose);
  return sync;
});

/// Replays and imports ops queued by widgets; also drained by the outbox
/// coordinator.
final widgetOpsRepositoryProvider =
    FutureProvider<WidgetOpsRepository>((ref) async {
  return WidgetOpsRepository(
    db: ref.watch(appDatabaseProvider),
    bridge: ref.watch(widgetBridgeProvider),
    dio: ref.watch(dioProvider),
    listRepo: await ref.watch(listRepositoryProvider.future),
    choreRepo: await ref.watch(choreRepositoryProvider.future),
    onLocalWrite: ref.watch(syncSchedulerProvider).noteLocalWrite,
  );
});

/// The app's side of home screen widgets, for a signed-in session. Built
/// lazily by `MitlistApp` after authentication.
final homeWidgetsControllerProvider =
    FutureProvider<HomeWidgetsController>((ref) async {
  final bridge = ref.watch(widgetBridgeProvider);
  final snapshots = ref.watch(widgetSnapshotSyncProvider);
  final controller = HomeWidgetsController(
    bridge: bridge,
    provisioner: WidgetCredentialProvisioner(
      dio: ref.watch(dioProvider),
      bridge: bridge,
    ),
    snapshots: snapshots,
    ops: await ref.watch(widgetOpsRepositoryProvider.future),
    currentUserId: () async {
      final auth = await ref.read(authServiceProviderAsync.future);
      return (auth.cachedMe ?? await auth.getMe()).id;
    },
    householdIds: () async {
      final groups = await ref.read(cachedGroupsProvider.future);
      return [for (final g in groups) g.id];
    },
    // Signing out disposes this provider while its work may still be in
    // flight; a disposed ref then reads as signed out.
    sessionIsRemembered: () async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(ApiConfig.persistSessionKey) ?? true;
    },
    isSignedIn: () {
      try {
        return ref.read(authStateProvider);
      } catch (_) {
        return false;
      }
    },
  );
  if (!controller.isSupported) return controller;

  // Joining or leaving a household changes what the credential may cover.
  ref.listen(cachedGroupsProvider, (previous, next) {
    if (next.hasValue && previous?.valueOrNull != next.valueOrNull) {
      unawaited(controller.onHouseholdsChanged());
    }
  });

  // A drained outbox means the server now has the app's changes.
  final db = ref.watch(appDatabaseProvider);
  var lastCount = 0;
  final outboxSub = db.watchOutboxCount().listen((count) {
    if (lastCount > 0 && count == 0) controller.onDataChanged();
    lastCount = count;
  });

  // Live updates from the rest of the household.
  final sseSub = ref.watch(sseServiceProvider).events.listen((event) {
    final type = event.type;
    if (type.startsWith('list:') ||
        (type.startsWith('chore:') && !type.startsWith('chore:subtask')) ||
        type.startsWith('member:') ||
        type.startsWith('meal_plan:') ||
        type.startsWith('expense:') ||
        type.startsWith('settlement:')) {
      controller.onDataChanged();
    }
  });

  // App icon shortcuts follow the snapshot's default list and the language.
  final shortcuts = ref.watch(appShortcutsProvider);
  WidgetDefaults? defaults;
  AppLocalizations l10n() =>
      lookupAppLocalizations(Locale(effectiveLanguageCode(
        ref.read(localeProvider),
        PlatformDispatcher.instance.locales,
      )));
  final defaultsSub = snapshots.defaults.listen((next) {
    defaults = next;
    unawaited(shortcuts.update(l10n(), defaults: next));
  });
  ref.listen(localeProvider, (_, __) {
    unawaited(shortcuts.update(l10n(), defaults: defaults));
  });
  unawaited(shortcuts.update(l10n()));

  ref.onDispose(() {
    unawaited(outboxSub.cancel());
    unawaited(sseSub.cancel());
    unawaited(defaultsSub.cancel());
  });
  return controller;
});
