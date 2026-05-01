import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/assistant_models.dart';
import 'package:mitlist/models/notification_models.dart';
import 'package:mitlist/providers/assistant_provider.dart';
import 'package:mitlist/providers/group_provider.dart';
import 'package:mitlist/providers/notification_provider.dart';
import 'package:mitlist/screens/assistant/assistant_sessions_screen.dart';
import 'package:mitlist/screens/notifications/notification_preferences_screen.dart';
import 'package:mitlist/services/assistant_service.dart';
import 'package:mitlist/services/group_service.dart';
import 'package:mitlist/services/notification_service.dart';
import 'package:mitlist/models/group_models.dart';

class _FakeNotificationService extends Fake implements NotificationService {
  @override
  Future<List<NotificationPreferenceModel>> getPreferences() async {
    return [
      NotificationPreferenceModel(
        id: 'pref-1',
        userId: 'user-1',
        groupId: 'group-1',
        choreDue: true,
        choreDueDayOf: true,
        listItemAdded: false,
        expenseCreated: true,
        mealPlanChanged: false,
        weeklyDigest: true,
        pushEnabled: true,
      ),
    ];
  }

  @override
  Future<void> updatePreference(NotificationPreferenceModel pref) async {}
}

class _FakeGroupService extends Fake implements GroupService {
  @override
  Future<List<Group>> listGroups({int limit = 50, int offset = 0}) async {
    return [
      Group(
        id: 'group-1',
        name: 'Test Household',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    ];
  }
}

class _FakeAssistantService extends Fake implements AssistantService {
  @override
  Future<List<ChatSessionModel>> listSessions({int limit = 50, int offset = 0}) async {
    return [];
  }
}

void main() {
  testWidgets('NotificationPreferencesScreen renders loading state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProviderAsync
              .overrideWith((ref) async => _FakeNotificationService()),
          groupServiceProviderAsync
              .overrideWith((ref) async => _FakeGroupService()),
        ],
        child: const MaterialApp(
          home: NotificationPreferencesScreen(),
        ),
      ),
    );

    // Should show loading spinner initially
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('NotificationPreferencesScreen loads preferences',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProviderAsync
              .overrideWith((ref) async => _FakeNotificationService()),
          groupServiceProviderAsync
              .overrideWith((ref) async => _FakeGroupService()),
        ],
        child: const MaterialApp(
          home: NotificationPreferencesScreen(),
        ),
      ),
    );

    // Wait for async providers to resolve
    await tester.pumpAndSettle();

    // Should show the preference toggles after loading
    expect(find.text('Chore due reminders'), findsOneWidget);
    expect(find.text('Chore due day-of'), findsOneWidget);
    expect(find.text('List item added'), findsOneWidget);
    expect(find.text('Expense created'), findsOneWidget);
    expect(find.text('Meal plan changed'), findsOneWidget);
    expect(find.text('Weekly digest'), findsOneWidget);
    expect(find.text('Push notifications'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(7));
  });

  testWidgets('AssistantSessionsScreen renders empty state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantServiceProviderAsync
              .overrideWith((ref) async => _FakeAssistantService()),
        ],
        child: const MaterialApp(
          home: AssistantSessionsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Should show empty state when no sessions exist
    expect(find.text('No chats yet'), findsOneWidget);
    expect(
      find.text(
          'Ask the assistant about chores, meal plans, shopping lists, '
          'or anything household-related.'),
      findsOneWidget,
    );
  });

  testWidgets('NotificationPreferenceModel fromJson / toJson roundtrip',
      (WidgetTester tester) async {
    final original = const NotificationPreferenceModel(
      id: 'pref-1',
      userId: 'user-1',
      groupId: 'group-1',
      choreDue: true,
      choreDueDayOf: false,
      listItemAdded: true,
      expenseCreated: false,
      mealPlanChanged: true,
      weeklyDigest: false,
      pushEnabled: true,
    );

    final json = original.toJson();
    final restored = NotificationPreferenceModel.fromJson(json);

    expect(restored.id, original.id);
    expect(restored.userId, original.userId);
    expect(restored.groupId, original.groupId);
    expect(restored.choreDue, original.choreDue);
    expect(restored.choreDueDayOf, original.choreDueDayOf);
    expect(restored.listItemAdded, original.listItemAdded);
    expect(restored.expenseCreated, original.expenseCreated);
    expect(restored.mealPlanChanged, original.mealPlanChanged);
    expect(restored.weeklyDigest, original.weeklyDigest);
    expect(restored.pushEnabled, original.pushEnabled);
  });
}
