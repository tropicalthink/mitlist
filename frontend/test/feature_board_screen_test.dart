import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/feature_board_models.dart';
import 'package:mitlist/screens/you/feature_board_detail_screen.dart';
import 'package:mitlist/screens/you/feature_board_screen.dart';
import 'package:mitlist/screens/you/feature_board_widgets.dart';
import 'package:mitlist/services/feedback_service.dart';

FeatureBoardItem _item({
  String id = 'feature-1',
  String title = 'Shared grocery templates',
  String? description = 'Reuse common shopping lists.',
  FeatureBoardStatus status = FeatureBoardStatus.underReview,
  FeatureBoardKind kind = FeatureBoardKind.feature,
  int voteCount = 2,
  bool hasVoted = false,
  int commentCount = 0,
}) {
  return FeatureBoardItem(
    id: id,
    title: title,
    description: description,
    status: status,
    kind: kind,
    voteCount: voteCount,
    hasVoted: hasVoted,
    commentCount: commentCount,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _FakeFeedbackService extends FeedbackService {
  _FakeFeedbackService()
      : super(Dio(BaseOptions(baseUrl: 'https://example.test')));

  final List<String> upvotes = [];
  final List<String> removedVotes = [];
  final List<({FeatureBoardKind? kind, FeatureBoardSort sort})> listCalls = [];
  final List<({String title, String? description, FeatureBoardKind kind})>
      submissions = [];
  final List<String> comments = [];
  var items = <FeatureBoardItem>[_item()];
  var threads = <String, List<FeatureBoardComment>>{};

  @override
  Future<List<FeatureBoardItem>> listFeatureBoard({
    FeatureBoardKind? kind,
    FeatureBoardSort sort = FeatureBoardSort.top,
  }) async {
    listCalls.add((kind: kind, sort: sort));
    return items.where((item) => kind == null || item.kind == kind).toList();
  }

  @override
  Future<FeatureBoardDetail> getFeatureBoardItem(String requestId) async {
    return FeatureBoardDetail(
      item: items.firstWhere((item) => item.id == requestId),
      comments: threads[requestId] ?? const [],
    );
  }

  @override
  Future<FeatureBoardVote> upvoteBoardFeature(String requestId) async {
    upvotes.add(requestId);
    items = items
        .map((item) => item.id == requestId
            ? item.copyWith(voteCount: item.voteCount + 1, hasVoted: true)
            : item)
        .toList();
    return FeatureBoardVote(
      requestId: requestId,
      voteCount: 3,
      hasVoted: true,
    );
  }

  @override
  Future<FeatureBoardVote> removeBoardVote(String requestId) async {
    removedVotes.add(requestId);
    items = items
        .map((item) => item.id == requestId
            ? item.copyWith(voteCount: item.voteCount - 1, hasVoted: false)
            : item)
        .toList();
    return FeatureBoardVote(
      requestId: requestId,
      voteCount: 1,
      hasVoted: false,
    );
  }

  @override
  Future<void> submitBoardFeature({
    required String title,
    String? description,
    FeatureBoardKind kind = FeatureBoardKind.feature,
    String? sourcePage,
  }) async {
    submissions.add((title: title, description: description, kind: kind));
  }

  @override
  Future<FeatureBoardComment> addBoardComment({
    required String requestId,
    required String body,
  }) async {
    comments.add(body);
    final comment = FeatureBoardComment(
      id: 'comment-${comments.length}',
      body: body,
      isFromTeam: false,
      authorName: 'Sam',
      isMine: true,
      createdAt: DateTime(2026),
    );
    threads[requestId] = [...?threads[requestId], comment];
    return comment;
  }
}

Widget _buildApp(_FakeFeedbackService service, {String initial = '/board'}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/board',
        name: 'featureBoard',
        builder: (context, state) => const FeatureBoardScreen(),
        routes: [
          GoRoute(
            path: ':id',
            name: 'featureBoardItem',
            builder: (context, state) => FeatureBoardDetailScreen(
              requestId: state.pathParameters['id']!,
              initialItem: state.extra is FeatureBoardItem
                  ? state.extra as FeatureBoardItem
                  : null,
            ),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [feedbackServiceProvider.overrideWithValue(service)],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('lists requests with status and lets the user upvote',
      (tester) async {
    final service = _FakeFeedbackService();
    await tester.pumpWidget(_buildApp(service));
    await tester.pumpAndSettle();

    expect(find.text('Shared grocery templates'), findsOneWidget);
    expect(find.text('Reuse common shopping lists.'), findsOneWidget);
    expect(find.text('Under review'), findsOneWidget);
    expect(find.text('No comments'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byType(FeatureBoardVoteButton));
    await tester.pumpAndSettle();

    expect(service.upvotes, ['feature-1']);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('lets the user take an upvote back from the list',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final service = _FakeFeedbackService()..items = [_item(hasVoted: true)];
    await tester.pumpWidget(_buildApp(service));
    await tester.pumpAndSettle();

    final button = find.byType(FeatureBoardVoteButton);
    expect(tester.getSemantics(button).label, contains('Remove upvote'));

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(service.removedVotes, ['feature-1']);
    expect(service.upvotes, isEmpty);
    expect(find.text('1'), findsOneWidget);
    expect(tester.getSemantics(button).label, contains('Upvote feature'));
    semantics.dispose();
  });

  testWidgets('lets the user take an upvote back from the detail screen',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final service = _FakeFeedbackService()..items = [_item(hasVoted: true)];
    await tester.pumpWidget(_buildApp(service, initial: '/board/feature-1'));
    await tester.pumpAndSettle();

    expect(find.byType(FeatureBoardDetailScreen), findsOneWidget);
    final button = find.byType(FeatureBoardVoteButton);
    expect(tester.getSemantics(button).label, contains('Remove upvote'));

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(service.removedVotes, ['feature-1']);
    expect(find.textContaining('1 vote'), findsOneWidget);
    expect(tester.getSemantics(button).label, contains('Upvote feature'));
    semantics.dispose();
  });

  testWidgets('filters by kind and sorts through the service', (tester) async {
    final service = _FakeFeedbackService()
      ..items = [
        _item(),
        _item(
          id: 'bug-1',
          title: 'Totals are wrong',
          kind: FeatureBoardKind.bug,
          status: FeatureBoardStatus.inProgress,
        ),
      ];
    await tester.pumpWidget(_buildApp(service));
    await tester.pumpAndSettle();

    expect(find.text('Totals are wrong'), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Bug'), findsOneWidget);

    await tester.tap(find.text('Bugs'));
    await tester.pumpAndSettle();
    expect(find.text('Shared grocery templates'), findsNothing);
    expect(find.text('Totals are wrong'), findsOneWidget);

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();

    expect(service.listCalls.last,
        (kind: FeatureBoardKind.bug, sort: FeatureBoardSort.newest));
  });

  testWidgets('files a bug report from the create sheet', (tester) async {
    final service = _FakeFeedbackService();
    await tester.pumpWidget(_buildApp(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add a request'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bug report'));
    await tester.pumpAndSettle();
    expect(find.text('WHAT WENT WRONG?'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).at(0),
      'Totals are wrong',
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      'Split an expense three ways and the sum is off by a cent.',
    );
    await tester.tap(find.text('ADD TO BOARD'));
    await tester.pumpAndSettle();

    expect(service.submissions, [
      (
        title: 'Totals are wrong',
        description:
            'Split an expense three ways and the sum is off by a cent.',
        kind: FeatureBoardKind.bug,
      ),
    ]);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('opens a request, shows the team reply, and posts a comment',
      (tester) async {
    final service = _FakeFeedbackService()
      ..items = [
        _item(status: FeatureBoardStatus.inProgress, commentCount: 1),
      ]
      ..threads = {
        'feature-1': [
          FeatureBoardComment(
            id: 'reply-1',
            body: 'We are building this now.',
            isFromTeam: true,
            authorName: 'Abdel',
            isMine: false,
            createdAt: DateTime(2026),
          ),
        ],
      };
    await tester.pumpWidget(_buildApp(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Shared grocery templates'));
    await tester.pumpAndSettle();

    expect(find.byType(FeatureBoardDetailScreen), findsOneWidget);
    expect(find.text("We're building this right now."), findsOneWidget);
    expect(find.text('We are building this now.'), findsOneWidget);
    expect(find.text('mitlist team'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Any ETA?');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Post comment'));
    await tester.pumpAndSettle();

    expect(service.comments, ['Any ETA?']);
    expect(find.text('Any ETA?'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
  });
}
