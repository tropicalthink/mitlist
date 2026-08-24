import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations.dart';
import 'package:mitlist/models/feature_board_models.dart';
import 'package:mitlist/screens/you/feature_board_screen.dart';
import 'package:mitlist/services/feedback_service.dart';

class _FakeFeedbackService extends FeedbackService {
  _FakeFeedbackService()
      : super(Dio(BaseOptions(baseUrl: 'https://example.test')));

  final List<String> upvotes = [];
  final List<({String title, String? description})> submissions = [];
  var items = <FeatureBoardItem>[
    FeatureBoardItem(
      id: 'feature-1',
      title: 'Shared grocery templates',
      description: 'Reuse common shopping lists.',
      status: FeatureBoardStatus.planned,
      voteCount: 2,
      hasVoted: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];

  @override
  Future<List<FeatureBoardItem>> listFeatureBoard() async => items;

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
  Future<void> submitBoardFeature({
    required String title,
    String? description,
    String? sourcePage,
  }) async {
    submissions.add((title: title, description: description));
  }
}

Widget _buildScreen(_FakeFeedbackService service) {
  return ProviderScope(
    overrides: [feedbackServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const FeatureBoardScreen(),
    ),
  );
}

void main() {
  testWidgets('lists features and lets the signed-in user upvote',
      (tester) async {
    final service = _FakeFeedbackService();
    await tester.pumpWidget(_buildScreen(service));
    await tester.pumpAndSettle();

    expect(find.text('Shared grocery templates'), findsOneWidget);
    expect(find.text('Reuse common shopping lists.'), findsOneWidget);
    expect(find.text('PLANNED'), findsOneWidget);
    expect(find.text('2 VOTES'), findsOneWidget);

    await tester.tap(find.text('2 VOTES'));
    await tester.pumpAndSettle();

    expect(service.upvotes, ['feature-1']);
    expect(find.text('3 votes'), findsOneWidget);
  });

  testWidgets('creates a feature without leaving the app', (tester) async {
    final service = _FakeFeedbackService();
    await tester.pumpWidget(_buildScreen(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Suggest a feature'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'Calendar voting',
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      'Let the household vote on meal-plan dates.',
    );
    await tester.tap(find.text('ADD TO BOARD'));
    await tester.pumpAndSettle();

    expect(service.submissions, [
      (
        title: 'Calendar voting',
        description: 'Let the household vote on meal-plan dates.',
      ),
    ]);
    expect(find.byType(TextField), findsNothing);
  });
}
