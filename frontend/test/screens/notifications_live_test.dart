import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/models/notification_models.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/list_provider.dart' show sseServiceProvider;
import 'package:mitlist/providers/notification_provider.dart';
import 'package:mitlist/screens/notifications/notifications_screen.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/router.dart'
    show currentGroupIdProvider, CurrentGroupIdNotifier;
import 'package:mitlist/services/notification_service.dart';
import 'package:mitlist/services/sse_service.dart';

// ---------------------------------------------------------------------------
// Fake SSE service — no real HTTP; supports manual event injection.
// ---------------------------------------------------------------------------
class _FakeSse extends SseService {
  final _ctrl = StreamController<SseEvent>.broadcast();
  @override
  Future<void> connect(String groupId) async {}

  @override
  Stream<SseEvent> get events => _ctrl.stream;

  void emit(SseEvent e) => _ctrl.add(e);

  @override
  void dispose() {
    _ctrl.close();
  }
}

// ---------------------------------------------------------------------------
// Fake notification service — counts listNotifications calls; returns [].
// ---------------------------------------------------------------------------
class _CountingNotificationService implements NotificationService {
  int listCallCount = 0;

  @override
  Future<List<NotificationModel>> listNotifications(
      {int limit = 50,
      int offset = 0,
      DateTime? beforeCreatedAt,
      String? beforeId}) async {
    listCallCount++;
    return [];
  }

  @override
  Future<int> countUnreadNotifications() async => 0;

  @override
  Future<void> markAllAsRead() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      '${invocation.memberName} not implemented in _CountingNotificationService');
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------
final _testGroup = Group(
  id: '11111111-1111-1111-1111-111111111111',
  name: 'Test House',
  currency: 'USD',
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'notification:created SSE event triggers a second listNotifications call',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeSse = _FakeSse();
      final fakeNotifSvc = _CountingNotificationService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Provide one group so _load() proceeds past the "no household" guard.
            cachedGroupsProvider.overrideWith((ref) async => [_testGroup]),
            // Provide a stable group-id so resolveActiveGroupId picks it up.
            currentGroupIdProvider
                .overrideWith((ref) => CurrentGroupIdNotifier()),
            // Inject counting notification service.
            notificationServiceProviderAsync
                .overrideWith((ref) async => fakeNotifSvc),
            // Inject fake SSE.
            sseServiceProvider.overrideWithValue(fakeSse),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const NotificationsScreen(),
          ),
        ),
      );

      // Let initState → _load() → _ensureLiveUpdates() complete.
      await tester.pumpAndSettle();

      // One call happened during initial load.
      final countAfterInit = fakeNotifSvc.listCallCount;
      expect(countAfterInit, greaterThanOrEqualTo(1),
          reason:
              'initState should have called listNotifications at least once');

      // Emit a notification:created event.
      fakeSse.emit(SseEvent(
        type: 'notification:created',
        groupId: _testGroup.id,
        payload: {},
      ));

      // Let the listener's _load() complete.
      await tester.pump();
      await tester.pumpAndSettle();

      expect(fakeNotifSvc.listCallCount, greaterThan(countAfterInit),
          reason:
              'notification:created SSE event should trigger an additional listNotifications call');
    },
  );

  testWidgets(
    'unrelated SSE events do not trigger a refetch',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeSse = _FakeSse();
      final fakeNotifSvc = _CountingNotificationService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cachedGroupsProvider.overrideWith((ref) async => [_testGroup]),
            currentGroupIdProvider
                .overrideWith((ref) => CurrentGroupIdNotifier()),
            notificationServiceProviderAsync
                .overrideWith((ref) async => fakeNotifSvc),
            sseServiceProvider.overrideWithValue(fakeSse),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const NotificationsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final countAfterInit = fakeNotifSvc.listCallCount;

      // Emit a different event type that should be ignored.
      fakeSse.emit(SseEvent(
        type: 'pinwall:post_created',
        groupId: _testGroup.id,
        payload: {},
      ));

      await tester.pump();
      await tester.pumpAndSettle();

      expect(fakeNotifSvc.listCallCount, equals(countAfterInit),
          reason: 'unrelated SSE events must not trigger a refetch');
    },
  );
}
