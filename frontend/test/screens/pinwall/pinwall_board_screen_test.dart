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

  /// The board's own provider wiring, shared by every case below.
  List<Override> boardOverrides(Completer<PinwallRepository> pending) => [
        pinwallRepositoryProvider.overrideWith((ref) => pending.future),
        pinwallPostsByGroupProvider(groupId).overrideWith(
          (ref) => Stream.value(posts),
        ),
        for (final post in posts)
          pinwallMediaByPostProvider(
            (groupId: groupId, postId: post.id),
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
      ];

  Future<void> pumpBoard(
    WidgetTester tester, {
    Size surface = const Size(1200, 900),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: boardOverrides(Completer<PinwallRepository>()),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Inside MaterialApp: it installs its own MediaQuery from the view,
          // so an ancestor override would be discarded.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
          home: PinwallBoardScreen(groupId: groupId, me: user, posts: posts),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// The zoom the board opened at, read off the cork canvas: the 3200-wide
  /// board paints at `3200 * scale` on screen.
  double openingScale(WidgetTester tester) {
    final canvas = find.byWidgetPredicate(
      (w) => w is SizedBox && w.width == 3200 && w.height == 2400,
    );
    expect(canvas, findsOneWidget);
    return tester.getRect(canvas).width / 3200;
  }

  testWidgets('renders notes, presence, and household stats', (tester) async {
    await pumpBoard(tester);

    expect(find.text('Remember milk'), findsOneWidget);
    expect(find.text('TU'), findsOneWidget);
    expect(find.text('Chores'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.text('Lists'), findsOneWidget);
    expect(find.text('+\$25'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('opens at a readable zoom even on a narrow viewport',
      (tester) async {
    // A phone-width viewport cannot frame the cluster at 1:1; the board must
    // stop shrinking at the readable floor rather than fitting everything.
    await pumpBoard(tester, surface: const Size(400, 800));

    // Readable floor, and genuinely zoomed out from 1:1 — so this is measuring
    // the board's transform and not a fixed canvas size.
    expect(openingScale(tester), greaterThanOrEqualTo(0.79));
    expect(openingScale(tester), lessThan(1.0));
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('lays out without overflow at a 1.3x text scale',
      (tester) async {
    await pumpBoard(
      tester,
      surface: const Size(400, 800),
      textScaler: const TextScaler.linear(1.3),
    );

    expect(find.text('Remember milk'), findsOneWidget);
    expect(openingScale(tester), greaterThanOrEqualTo(0.79));
    // Any RenderFlex overflow inside a note, the summary band, or the board
    // chrome would surface here.
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 3));
  });
}
