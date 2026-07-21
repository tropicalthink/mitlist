import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/auth_models.dart';
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
import 'package:mitlist/services/pinwall_service.dart';
import 'package:mitlist/storage/app_database.dart';

/// Records position syncs and succeeds, so a test can tell "the outbox op was
/// drained" apart from "the op is sitting in the queue". The shared
/// `FakePinwallService` throws on every call to model the offline path, which
/// cannot distinguish those two.
class _RecordingPinwallService implements PinwallService {
  final List<({String postId, double x, double y})> positionSyncs = [];

  @override
  Future<PinwallPost> updatePostPosition(
    String groupId,
    String postId, {
    required double x,
    required double y,
  }) async {
    positionSyncs.add((postId: postId, x: x, y: y));
    return PinwallPost(
      id: postId,
      groupId: groupId,
      userId: 'u1',
      content: 'note',
      createdAt: DateTime.utc(2026, 1, 2, 12),
      posX: x,
      posY: y,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected call: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const groupId = '11111111-1111-1111-1111-111111111111';
  const userId = '22222222-2222-2222-2222-222222222222';
  const postId = '33333333-3333-3333-3333-333333333333';
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

  final post = PinwallPost(
    id: postId,
    groupId: groupId,
    userId: userId,
    content: 'Remember milk',
    createdAt: now,
  );

  testWidgets('dragging a note syncs the new position, not just queues it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(db.close);

    final service = _RecordingPinwallService();
    final repo = PinwallRepository(db: db, remote: service);

    await db.upsertPinwallPosts(
      groupId: groupId,
      postsJson: jsonEncode([post.toJson()]),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pinwallRepositoryProvider.overrideWith((ref) async => repo),
          pinwallPostsByGroupProvider(groupId)
              .overrideWith((ref) => Stream.value([post])),
          pinwallMediaByPostProvider((groupId: groupId, postId: postId))
              .overrideWith((ref) async => const <PinwallMediaItem>[]),
          presentMembersProvider((groupId: groupId, meId: userId))
              .overrideWithValue(const []),
          cachedCurrentChoresByGroupProvider(groupId)
              .overrideWith((ref) => Stream.value(const [])),
          cachedFinanceSummaryByGroupProvider(groupId)
              .overrideWith((ref) => Stream.value(null)),
          cachedListsByGroupProvider(groupId)
              .overrideWith((ref) => Stream.value(const [])),
          todayMealPlansProvider(groupId).overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PinwallBoardScreen(groupId: groupId, me: user, posts: [post]),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.drag(find.text('Remember milk'), const Offset(80, 60));
    await tester.pump();
    // Let the enqueue → drain chain settle, then run out the board's entrance
    // timer so it isn't left pending at teardown.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 3));

    // The regression: the board enqueued the move but never drained it, so it
    // sat in the outbox — showing "syncing" — until connectivity flipped or the
    // app was resumed.
    expect(service.positionSyncs, hasLength(1));
    expect(service.positionSyncs.single.postId, postId);
    expect(await db.outboxCount(), 0,
        reason: 'a drained op should be removed from the queue');
  });
}
