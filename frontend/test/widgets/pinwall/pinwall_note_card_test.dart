import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/auth_models.dart';
import 'package:mitlist/models/pinwall_media_models.dart';
import 'package:mitlist/models/pinwall_models.dart';
import 'package:mitlist/providers/pinwall_provider.dart';
import 'package:mitlist/widgets/pinwall/pinwall_note_card.dart';
import 'package:mitlist/widgets/pinwall_link_chip.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _groupId = '11111111-1111-1111-1111-111111111111';
const _userId = '22222222-2222-2222-2222-222222222222';
final _now = DateTime.utc(2026, 1, 2, 12);

final _me = User(
  id: _userId,
  email: 'test@example.com',
  firstName: 'Test',
  lastName: 'User',
  isActive: true,
  isVerified: true,
  isGuest: false,
  createdAt: _now,
  updatedAt: _now,
);

PinwallPost _post({
  String id = '33333333-3333-3333-3333-333333333333',
  String content = 'Remember the milk',
  DateTime? remindAt,
  DateTime? reminderSentAt,
  String? linkedEntityType,
  String? linkedEntityId,
}) =>
    PinwallPost(
      id: id,
      groupId: _groupId,
      userId: _userId,
      content: content,
      createdAt: _now,
      remindAt: remindAt,
      reminderSentAt: reminderSentAt,
      linkedEntityType: linkedEntityType,
      linkedEntityId: linkedEntityId,
    );

/// Pumps [PinwallNoteCard] for [post] inside a localized, provider-scoped
/// [MaterialApp]. Media resolves to an empty list unless [media] is given.
Future<void> _pumpCard(
  WidgetTester tester, {
  required PinwallNoteCardVariant variant,
  required PinwallPost post,
  List<PinwallMediaItem> media = const [],
  void Function(BuildContext)? onOpenLinkedEntity,
  double? width,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pinwallMediaByPostProvider((groupId: _groupId, postId: post.id))
            .overrideWith((ref) async => media),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PinwallNoteCard(
            variant: variant,
            index: 0,
            groupId: _groupId,
            me: _me,
            post: post,
            width: width,
            onOpenLinkedEntity: onOpenLinkedEntity ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PinwallNoteCard (hub variant)', () {
    testWidgets('lays out at the width the hub gives it', (tester) async {
      await _pumpCard(
        tester,
        variant: PinwallNoteCardVariant.hub,
        post: _post(),
        width: 142,
      );

      // The hub derives this width so its columns fill the row exactly; if the
      // card ignored it and kept its fixed 160dp, the wrap would go one-up.
      final card = find
          .descendant(
            of: find.byType(PinwallNoteCard),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(card).width, 142);
    });

    testWidgets('falls back to its fixed width when none is given',
        (tester) async {
      await _pumpCard(
        tester,
        variant: PinwallNoteCardVariant.hub,
        post: _post(),
      );

      final card = find
          .descendant(
            of: find.byType(PinwallNoteCard),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(card).width, 160);
    });

    testWidgets('renders content and "You" for the post author',
        (tester) async {
      await _pumpCard(
        tester,
        variant: PinwallNoteCardVariant.hub,
        post: _post(content: 'Buy oat milk'),
      );

      expect(find.text('Buy oat milk'), findsOneWidget);
      expect(find.textContaining('You'), findsOneWidget);
    });

    testWidgets('shows a reminder row when remindAt is set', (tester) async {
      await _pumpCard(
        tester,
        variant: PinwallNoteCardVariant.hub,
        post: _post(remindAt: _now.add(const Duration(days: 1))),
      );

      expect(find.byIcon(Icons.alarm_on_outlined), findsOneWidget);
    });

    testWidgets('shows the post-options menu (add photo / delete)',
        (tester) async {
      await _pumpCard(
        tester,
        variant: PinwallNoteCardVariant.hub,
        post: _post(),
      );

      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('renders an inline "Open <entity>" row when linked',
        (tester) async {
      await _pumpCard(
        tester,
        variant: PinwallNoteCardVariant.hub,
        post: _post(linkedEntityType: 'list', linkedEntityId: 'list-1'),
      );

      expect(find.textContaining('Open'), findsOneWidget);
    });
  });

  group('PinwallNoteCard (board variant)', () {
    testWidgets('renders content and calls back for linked entities',
        (tester) async {
      var tapped = false;
      await _pumpCard(
        tester,
        variant: PinwallNoteCardVariant.board,
        post: _post(
          content: 'Call the plumber',
          linkedEntityType: 'chore',
          linkedEntityId: 'chore-1',
        ),
        onOpenLinkedEntity: (_) => tapped = true,
      );

      expect(find.text('Call the plumber'), findsOneWidget);
      // Board variant has no post-options menu — it's a read-only card; the
      // board's own draggable wrapper handles interaction/positioning.
      expect(find.byIcon(Icons.more_horiz), findsNothing);

      await tester.tap(find.byType(PinwallLinkChip));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('does not show a reminder row when remindAt is unset',
        (tester) async {
      await _pumpCard(
        tester,
        variant: PinwallNoteCardVariant.board,
        post: _post(),
      );

      expect(find.byIcon(Icons.alarm_on_outlined), findsNothing);
    });
  });
}
