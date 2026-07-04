import 'dart:typed_data';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/grocery_classifier_service.dart';
import 'package:mitlist/services/scan/resolution/calibrated_scorer.dart';
import 'package:mitlist/services/scan/resolution/ensemble_resolver.dart';
import 'package:mitlist/services/scan/static_embedding_service.dart';
import 'package:mitlist/storage/app_database.dart';

class _FakeClassifier extends GroceryClassifierService {
  final List<ClassifierPrediction> canned;

  _FakeClassifier(this.canned);

  @override
  Future<List<ClassifierPrediction>> classify(
    String rawText, {
    int topK = 5,
  }) async =>
      canned.take(topK).toList();
}

AppDatabase _memoryDb() => AppDatabase(
      drift.DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

final _now = DateTime(2024, 1, 1);

Future<void> _seedCanonicalItem(
  AppDatabase db, {
  required String id,
  required String name,
}) async {
  await db.upsertCanonicalItems([
    CanonicalItemsTableCompanion.insert(
      id: id,
      groupId: '__global__',
      nameDe: drift.Value(name),
      isGlobal: const drift.Value(true),
      createdAt: _now,
      updatedAt: _now,
    ),
  ]);
}

Future<void> _seedAlias(
  AppDatabase db, {
  required String id,
  required String canonicalItemId,
  required String aliasText,
}) async {
  await db.upsertItemAliases([
    ItemAliasesTableCompanion.insert(
      id: id,
      groupId: '__global__',
      canonicalItemId: canonicalItemId,
      aliasText: aliasText,
      createdAt: _now,
      updatedAt: _now,
    ),
  ]);
}

StaticEmbeddingService _embedderForQuery(
  String queryToken, {
  required String primaryItemId,
  String? secondaryItemId,
}) {
  final itemIds = [
    primaryItemId,
    if (secondaryItemId != null) secondaryItemId,
  ];
  final catalogVectors = [
    Float32List.fromList(const [1, 0, 0]),
    if (secondaryItemId != null) Float32List.fromList(const [0, 1, 0]),
  ];

  return StaticEmbeddingService()
    ..seedForTest(
      vocab: [queryToken],
      vocabVectors: [
        Float32List.fromList(const [1, 0, 0])
      ],
      itemIds: itemIds,
      catalogVectors: catalogVectors,
    );
}

CalibratedScorer _modelScorer() => CalibratedScorer(
      weights: const [
        0, // aliasStringSim
        0, // canonicalNameSim
        1, // classifierProb
        1, // embedderCosine
        4, // sourceAgreement
        0, // isHouseholdAlias
        0, // householdFreq
        0, // recency
        0, // listCooccurrence
        0, // isExactAlias
      ],
      bias: -1,
      tauAuto: 0.85,
      tauReview: 0.5,
    );

void main() {
  late AppDatabase db;

  setUp(() async {
    db = _memoryDb();
    await _seedCanonicalItem(db, id: 'item-milk', name: 'milk');
    await _seedCanonicalItem(db, id: 'item-eggs', name: 'eggs');
    await _seedAlias(
      db,
      id: 'alias-milk',
      canonicalItemId: 'item-milk',
      aliasText: 'milk',
    );
    await _seedAlias(
      db,
      id: 'alias-eggs',
      canonicalItemId: 'item-eggs',
      aliasText: 'eggs',
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('unions classifier and embedder candidates and rewards agreement',
      () async {
    final resolver = EnsembleResolver(
      db,
      classifier: _FakeClassifier(const [
        ClassifierPrediction(label: 'milk', score: 0.90),
      ]),
      embedder: _embedderForQuery(
        'mystery',
        primaryItemId: 'item-eggs',
      ),
      scorer: _modelScorer(),
    );

    final union = await resolver.resolve('mystery', 'hh-models');

    expect(union.canonicalItemId, equals('item-eggs'));
    expect(
      union.alternatives.map((a) => a.canonicalItemId),
      contains('item-milk'),
    );

    final agreedResolver = EnsembleResolver(
      db,
      classifier: _FakeClassifier(const [
        ClassifierPrediction(label: 'eggs', score: 0.90),
      ]),
      embedder: _embedderForQuery(
        'mystery',
        primaryItemId: 'item-eggs',
      ),
      scorer: _modelScorer(),
    );
    final embedderOnlyResolver = EnsembleResolver(
      db,
      classifier: _FakeClassifier(const []),
      embedder: _embedderForQuery(
        'mystery',
        primaryItemId: 'item-eggs',
      ),
      scorer: _modelScorer(),
    );

    final agreed = await agreedResolver.resolve('mystery', 'hh-models');
    final embedderOnly =
        await embedderOnlyResolver.resolve('mystery', 'hh-models');

    expect(agreed.canonicalItemId, equals('item-eggs'));
    expect(embedderOnly.canonicalItemId, equals('item-eggs'));
    expect(agreed.score, greaterThan(embedderOnly.score));
  });

  test('maps classifier labels through aliases and drops unmapped labels',
      () async {
    final resolver = EnsembleResolver(
      db,
      classifier: _FakeClassifier(const [
        ClassifierPrediction(label: 'unknown model label', score: 0.99),
        ClassifierPrediction(label: 'milk', score: 0.80),
      ]),
      scorer: _modelScorer(),
    );

    final result = await resolver.resolve('nomatch', 'hh-models');

    expect(result.canonicalItemId, equals('item-milk'));
    expect(result.alternatives, isEmpty);
  });

  test('empty classifier and unavailable embedder match modelless ensemble',
      () async {
    final scorer = _modelScorer();
    final modelless = EnsembleResolver(db, scorer: scorer);
    final failedModels = EnsembleResolver(
      db,
      classifier: _FakeClassifier(const []),
      embedder: StaticEmbeddingService(),
      scorer: scorer,
    );

    final expected = await modelless.resolve('milk', 'hh-models');
    final actual = await failedModels.resolve('milk', 'hh-models');

    expect(actual.canonicalItemId, equals(expected.canonicalItemId));
    expect(actual.displayName, equals(expected.displayName));
    expect(actual.score, closeTo(expected.score, 1e-9));
  });
}
