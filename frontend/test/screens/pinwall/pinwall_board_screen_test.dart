import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/auth_models.dart';
import 'package:mitlist/models/chore_models.dart';
import 'package:mitlist/models/finance_models.dart';
import 'package:mitlist/models/group_models.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/models/pinwall_media_models.dart';
import 'package:mitlist/models/pinwall_models.dart';
import 'package:mitlist/providers/chore_provider.dart';
import 'package:mitlist/providers/finance_provider.dart';
import 'package:mitlist/providers/list_provider.dart';
import 'package:mitlist/providers/meal_plan_provider.dart';
import 'package:mitlist/providers/pinwall_provider.dart';
import 'package:mitlist/providers/presence_provider.dart';
import 'package:mitlist/repositories/pinwall_repository.dart';
import 'package:mitlist/screens/pinwall/pinwall_board_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const groupId = '11111111-1111-1111-1111-111111111111';
  const userId = '22222222-2222-2222-2222-222222222222';
  final now = DateTime.utc(2026, 1, 2, 12);

  final user = User(
    id: userId,
    email: 'test@example.com',
    firstName: 'Test',
    lastName: 'User',
    isActive: true,
    isVerified: true,
    isGuest: false,
    createdAt: now,
    updatedAt: now,
  );

  final posts = [
    PinwallPost(
      id: '33333333-3333-3333-3333-333333333333',
      groupId: groupId,
      userId: userId,
      content: 'Remember milk',
      createdAt: now,
    ),
    PinwallPost(
      id: '44444444-4444-4444-4444-444444444444',
      groupId: groupId,
      userId: userId,
      content: 'Call plumber',
      createdAt: now,
      remindAt: now.add(const Duration(days: 1)),
    ),
  ];

  testWidgets('renders notes, presence, and household stats', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final pendingRepository = Completer<PinwallRepository>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinwallRepositoryProvider.overrideWith(
            (ref) => pendingRepository.future,
          ),
          pinwallPostsByGroupProvider(groupId).overrideWith(
            (ref) => Stream.value(posts),
          ),
          pinwallMediaByPostProvider(
            (groupId: groupId, postId: posts[0].id),
          ).overrideWith(
            (ref) async => const <PinwallMediaItem>[],
          ),
          pinwallMediaByPostProvider(
            (groupId: groupId, postId: posts[1].id),
          ).overrideWith(
            (ref) async => const <PinwallMediaItem>[],
          ),
          presentMembersProvider((groupId: groupId, meId: userId))
              .overrideWithValue(
            const [
              GroupMemberProfile(
                userId: userId,
                displayName: 'Test User',
                role: 'admin',
              ),
            ],
          ),
          cachedCurrentChoresByGroupProvider(groupId).overrideWith(
            (ref) => Stream.value([
              CurrentChore(
                chore: Chore(
                  id: '55555555-5555-5555-5555-555555555555',
                  groupId: groupId,
                  name: 'Vacuum',
                  description: null,
                  rotationType: 'none',
                  frequency: 'daily',
                  isActive: true,
                  createdAt: now,
                  updatedAt: now,
                ),
                pendingAssignment: ChoreAssignment(
                  id: '66666666-6666-6666-6666-666666666666',
                  choreId: '55555555-5555-5555-5555-555555555555',
                  userId: userId,
                  dueDate: now,
                  status: 'pending',
                  assignedAt: now,
                  completedAt: null,
                ),
                dueStatus: 'due',
                assignedToMe: true,
              ),
            ]),
          ),
          cachedFinanceSummaryByGroupProvider(groupId).overrideWith(
            (ref) => Stream.value(
              const FinanceSummary(
                balances: [
                  BalanceEntry(
                    userId: userId,
                    displayName: 'Test User',
                    paid: 2500,
                    owed: 0,
                    total: 2500,
                  ),
                ],
                reimbursements: [],
              ),
            ),
          ),
          cachedListsByGroupProvider(groupId).overrideWith(
            (ref) => Stream.value([
              ItemList(
                id: '77777777-7777-7777-7777-777777777777',
                groupId: groupId,
                name: 'Groceries',
                type: 'shopping',
                createdAt: now,
                updatedAt: now,
              ),
            ]),
          ),
          todayMealPlansProvider(groupId).overrideWith(
            (ref) async => const [],
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PinwallBoardScreen(groupId: groupId, me: user, posts: posts),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Remember milk'), findsOneWidget);
    expect(find.text('TU'), findsOneWidget);
    expect(find.text('Chores'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('Lists'), findsOneWidget);
    expect(find.text('+\$25'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });
}
