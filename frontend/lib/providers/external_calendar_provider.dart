import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/external_calendar_models.dart';
import '../services/device_calendar/device_calendar_source.dart';
import '../services/device_calendar/device_calendar_sync.dart';
import '../services/external_calendar_service.dart';
import '../services/widgets/widget_credential_provisioner.dart';
import 'auth_provider.dart';

final externalCalendarServiceProvider =
    FutureProvider<ExternalCalendarService>((ref) async {
  return ExternalCalendarService.build(ref);
});

/// This phone's calendars; unsupported on web and desktop.
final deviceCalendarSourceProvider =
    Provider<DeviceCalendarSource>((ref) => DeviceCalendarSource.forPlatform());

/// A stable id for this install: the one the widget credential uses.
final deviceInstallIdProvider = FutureProvider<String>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return WidgetCredentialProvisioner.installId(prefs);
});

/// The signed-in person's id, or null.
final currentUserIdProvider = FutureProvider<String?>((ref) async {
  if (!ref.watch(authStateProvider)) return null;
  final auth = await ref.read(authServiceProviderAsync.future);
  return (auth.cachedMe ?? await auth.getMe()).id;
});

/// The signed-in person's calendar connections.
final calendarConnectionsProvider =
    FutureProvider.autoDispose<List<CalendarConnection>>((ref) async {
  final service = await ref.watch(externalCalendarServiceProvider.future);
  return service.listConnections();
});

/// Uploads this phone's shared calendars. Signing out invalidates it, which
/// stops whatever run is in flight.
final deviceCalendarSyncProvider = Provider<DeviceCalendarSync>((ref) {
  var disposed = false;
  final sync = DeviceCalendarSync(
    api: () => ref.read(externalCalendarServiceProvider.future),
    source: ref.watch(deviceCalendarSourceProvider),
    isSignedIn: () {
      if (disposed) return false;
      try {
        return ref.read(authStateProvider);
      } catch (_) {
        return false;
      }
    },
    currentUserId: () async {
      if (disposed) return null;
      final auth = await ref.read(authServiceProviderAsync.future);
      return (auth.cachedMe ?? await auth.getMe()).id;
    },
  );
  ref.onDispose(() {
    disposed = true;
    sync.stop();
  });
  return sync;
});
