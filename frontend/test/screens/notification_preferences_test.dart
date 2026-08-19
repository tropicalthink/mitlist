import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/models/notification_models.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/notification_provider.dart';
import 'package:mitlist/screens/notifications/notification_preferences_screen.dart';
import 'package:mitlist/services/notification_service.dart';

class _PreferenceService implements NotificationService {
  _PreferenceService(this.preferences, {this.failUpdate = false});

  final List<NotificationPreferenceModel> preferences;
  final bool failUpdate;
  NotificationPreferenceModel? lastUpdated;

  @override
  Future<List<NotificationPreferenceModel>> getPreferences() async =>
      List.of(preferences);

  @override
  Future<void> updatePreference(NotificationPreferenceModel pref) async {
    if (failUpdate) throw Exception('offline');
    lastUpdated = pref;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  testWidgets('default rows are updated by household rather than zero id',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.utc(2026, 1, 1);
    const firstGroupId = '11111111-1111-1111-1111-111111111111';
    const secondGroupId = '22222222-2222-2222-2222-222222222222';
    final groups = [
      Group(
          id: firstGroupId,
          name: 'First house',
          createdAt: now,
          updatedAt: now),
      Group(
          id: secondGroupId,
          name: 'Second house',
          createdAt: now,
          updatedAt: now),
    ];
    final service = _PreferenceService(const [
      NotificationPreferenceModel(
        id: '00000000-0000-0000-0000-000000000000',
        userId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        groupId: firstGroupId,
      ),
      NotificationPreferenceModel(
        id: '00000000-0000-0000-0000-000000000000',
        userId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        groupId: secondGroupId,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cachedGroupsProvider.overrideWith((ref) async => groups),
          notificationServiceProviderAsync.overrideWith((ref) async => service),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationPreferencesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('First house'), findsOneWidget);
    expect(find.text('Second house'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(18));

    // Each card has nine toggles; index nine is the first toggle in house two.
    await tester.tap(find.byType(Switch).at(9));
    await tester.pumpAndSettle();

    expect(service.lastUpdated?.groupId, secondGroupId);
    expect(service.lastUpdated?.choreDue, isFalse);
  });

  testWidgets('failed saves explain the problem and keep the previous value',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.utc(2026, 1, 1);
    const groupId = '11111111-1111-1111-1111-111111111111';
    final service = _PreferenceService(const [
      NotificationPreferenceModel(
        id: '00000000-0000-0000-0000-000000000000',
        userId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        groupId: groupId,
      ),
    ], failUpdate: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cachedGroupsProvider.overrideWith((ref) async => [
                Group(
                    id: groupId, name: 'Home', createdAt: now, updatedAt: now),
              ]),
          notificationServiceProviderAsync.overrideWith((ref) async => service),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationPreferencesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstSwitch = tester.widget<Switch>(find.byType(Switch).first);
    expect(firstSwitch.value, isTrue);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Couldn’t save that preference. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
  });
}
