import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/resolution/calibrated_scorer.dart';
import 'package:mitlist/services/scan/resolution/resolution_candidate.dart';
import 'package:mitlist/services/scan/resolution/resolution_features.dart';
import 'package:mitlist/services/scan/resolution/string_sim.dart';
import 'package:mitlist/storage/app_database.dart';

// Pure component tests for the plan 037 ensemble: string similarity, the
// feature vector (incl. canonicalNameSim + the household prior), and the
// calibrated scorer. No DB, no I/O. Candidate generation (which needs Drift) is
// covered in candidate_generator_test.dart.

CanonicalItemsTableData _item(String id, {String de = '', String en = ''}) =>
    CanonicalItemsTableData(
      id: id,
      groupId: '__global__',
      nameDe: de,
      nameEn: en,
      category: '',
      defaultUnit: '',
      isGlobal: true,
      version: 0,
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );

ResolutionCandidate _cand(
  CanonicalItemsTableData item, {
  double aliasSim = 0,
  double clsProb = 0,
  double embCos = 0,
  Set<String> sources = const {},
  bool exact = false,
  bool household = false,
}) =>
    ResolutionCandidate(
      item: item,
      aliasStringSim: aliasSim,
      classifierProb: clsProb,
      embedderCosine: embCos,
      sources: sources,
      isExactAlias: exact,
      isHouseholdAlias: household,
    );

void main() {
  group('string_sim', () {
    test('normaliseText lowercases, trims, collapses whitespace', () {
      expect(normaliseText('  Oat   Milk '), 'oat milk');
    });
    test('editDistance basics', () {
      expect(editDistance('milch', 'milch'), 0);
      expect(editDistance('milch', 'mlch'), 1);
      expect(editDistance('', 'abc'), 3);
    });
    test('stringSimilarity is 1 for identical, 0 for empty', () {
      expect(stringSimilarity('a', 'a'), 1.0);
      expect(stringSimilarity('', 'a'), 0.0);
      expect(stringSimilarity('spaghetti', 'spaghetti'), 1.0);
      expect(stringSimilarity('mlch', 'milch'), closeTo(1 - 1 / 5, 1e-9));
    });
  });

  group('buildResolutionFeatures', () {
    test('vector has the documented length and order', () {
      final f = buildResolutionFeatures(
        _cand(_item('x', de: 'X'), aliasSim: 0.5, sources: {'fuzzy'}),
        'x',
        ResolutionContext.empty,
      );
      expect(f, hasLength(kResolutionFeatureCount));
      expect(f[0], 0.5); // aliasStringSim
      expect(f[4], closeTo(1 / 5, 1e-9)); // sourceAgreement (1 source)
    });

    test('canonicalNameSim takes the closer of DE/EN name', () {
      // query "spaghetti": equals the DE name, far from EN gibberish.
      final f = buildResolutionFeatures(
        _cand(_item('s', de: 'Spaghetti', en: 'zzzzzz')),
        'spaghetti',
        ResolutionContext.empty,
      );
      expect(f[1], 1.0); // exact match to the DE canonical name
    });

    test('canonicalNameSim separates a collision from the right item', () {
      // "spaghetti" collides as an alias of egg_spaghetti, but matches the
      // canonical name of spaghetti perfectly and egg_spaghetti's only ~0.6.
      final spaghetti = buildResolutionFeatures(
        _cand(_item('spaghetti', de: 'Spaghetti'), aliasSim: 1, exact: true),
        'spaghetti',
        ResolutionContext.empty,
      );
      final egg = buildResolutionFeatures(
        _cand(_item('egg_spaghetti', de: 'Eierspaghetti'),
            aliasSim: 1, exact: true),
        'spaghetti',
        ResolutionContext.empty,
      );
      expect(spaghetti[1], greaterThan(egg[1]));
    });

    test('household prior: frequency normalised by the max, recency decays', () {
      final ctx = ResolutionContext(
        purchaseCounts: {'a': 4, 'b': 1},
        daysSinceLastPurchase: {'a': 0, 'b': 9},
      );
      final fa = buildResolutionFeatures(_cand(_item('a')), 'q', ctx);
      final fb = buildResolutionFeatures(_cand(_item('b')), 'q', ctx);
      expect(fa[6], 1.0); // 4/4
      expect(fb[6], 0.25); // 1/4
      expect(fa[7], 1.0); // 1/(1+0)
      expect(fb[7], closeTo(0.1, 1e-9)); // 1/(1+9)
    });

    test('unknown item has zeroed prior features', () {
      final ctx = ResolutionContext(purchaseCounts: {'other': 3});
      final f = buildResolutionFeatures(_cand(_item('a')), 'q', ctx);
      expect(f[6], 0.0);
      expect(f[7], 0.0);
      expect(f[8], 0.0);
    });
  });

  group('CalibratedScorer', () {
    test('output is a probability in (0,1)', () {
      final s = CalibratedScorer();
      final p = s.score(List.filled(kResolutionFeatureCount, 0.0));
      expect(p, greaterThan(0.0));
      expect(p, lessThan(1.0));
    });

    test('a strong canonical-name match scores higher than a bare alias hit',
        () {
      final s = CalibratedScorer();
      // Candidate A: exact alias only, name far away (the collision loser).
      final a = s.score(buildResolutionFeatures(
        _cand(_item('wrong', de: 'Apfelwein'), aliasSim: 1, exact: true),
        'app',
        ResolutionContext.empty,
      ));
      // Candidate B: weak alias but its own name is close.
      final b = s.score(buildResolutionFeatures(
        _cand(_item('apple', de: 'Apfel', en: 'Apple'), aliasSim: 0.4,
            sources: {'fuzzy'}),
        'app',
        ResolutionContext.empty,
      ));
      expect(b, greaterThan(a));
    });

    test('weights must match feature count (assert guard)', () {
      expect(() => CalibratedScorer(weights: const [1, 2, 3]),
          throwsA(isA<AssertionError>()));
    });
  });
}
