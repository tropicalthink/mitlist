import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/resolution/eval_harness.dart';

// Pure metric-math tests for the Phase A eval harness. No DB, no I/O, fully
// deterministic — this is the committed CI-safe guard. The real-resolver
// baseline (real seed + real dataset) lives in resolution_baseline_test.dart.

ResolutionEvalOutcome _o(
  String expected,
  String? predicted,
  double score, {
  String type = 'print',
}) =>
    ResolutionEvalOutcome(
      evalCase: ResolutionEvalCase(
        rawText: 'x',
        expectedCanonicalId: expected,
        inputType: type,
      ),
      predictedCanonicalId: predicted,
      score: score,
    );

void main() {
  group('ResolutionEvalCase.parseJsonl', () {
    test('parses rows, ignores blank lines, reads optional context', () {
      const jsonl = '''
{"raw_text":"Bananen","expected_canonical_id":"banana","input_type":"print"}

{"raw_text":"ban","expected_canonical_id":"banana","input_type":"handwriting","list_context":["milk","bread"],"household_purchases":["banana","banana"]}
''';
      final cases = ResolutionEvalCase.parseJsonl(jsonl);
      expect(cases, hasLength(2));
      expect(cases[0].rawText, 'Bananen');
      expect(cases[0].listContext, isEmpty);
      expect(cases[1].inputType, 'handwriting');
      expect(cases[1].listContext, ['milk', 'bread']);
      expect(cases[1].householdPurchases, ['banana', 'banana']);
    });
  });

  group('ResolutionMetrics.compute', () {
    test('top-1 counts correct predictions regardless of score', () {
      final m = ResolutionMetrics.compute([
        _o('a', 'a', 0.10), // correct but low score
        _o('b', 'c', 0.99), // wrong but high score
        _o('d', 'd', 0.90),
      ]);
      expect(m.total, 3);
      expect(m.top1Accuracy, closeTo(2 / 3, 1e-9));
    });

    test('precision@auto-accept only considers rows ≥ τ_auto', () {
      final m = ResolutionMetrics.compute([
        _o('a', 'a', 0.90), // accepted, correct
        _o('b', 'x', 0.95), // accepted, wrong
        _o('c', 'c', 0.40), // not accepted (correct, but below τ)
      ], tauAuto: 0.85);
      expect(m.autoAccepted, 2);
      expect(m.autoAcceptedCorrect, 1);
      expect(m.precisionAtAutoAccept, closeTo(0.5, 1e-9));
      expect(m.coverage, closeTo(2 / 3, 1e-9));
    });

    test('null prediction is never correct', () {
      final m = ResolutionMetrics.compute([_o('a', null, 0.0)]);
      expect(m.top1Accuracy, 0.0);
    });

    test('precision is NaN when nothing is auto-accepted', () {
      final m = ResolutionMetrics.compute([_o('a', 'a', 0.2)]);
      expect(m.precisionAtAutoAccept.isNaN, isTrue);
      expect(m.coverage, 0.0);
    });

    test('exact boundary score is accepted (≥, not >)', () {
      final m = ResolutionMetrics.compute([_o('a', 'a', 0.85)], tauAuto: 0.85);
      expect(m.autoAccepted, 1);
    });

    test('empty input is safe', () {
      final m = ResolutionMetrics.compute([]);
      expect(m.total, 0);
      expect(m.coverage, 0.0);
    });
  });

  group('ResolutionReport', () {
    test('splits metrics by input_type', () {
      final outcomes = [
        _o('a', 'a', 0.9, type: 'print'),
        _o('b', 'b', 0.9, type: 'print'),
        _o('c', 'x', 0.9, type: 'handwriting'),
      ];
      final r = ResolutionReport.build(outcomes);
      expect(r.byInputType.keys, containsAll(['print', 'handwriting']));
      expect(r.byInputType['print']!.top1Accuracy, 1.0);
      expect(r.byInputType['handwriting']!.top1Accuracy, 0.0);
      expect(r.overall.top1Accuracy, closeTo(2 / 3, 1e-9));
    });

    test('format lists the misses with predicted/expected', () {
      final outcomes = [_o('banana', 'banana_bread', 0.7)];
      final r = ResolutionReport.build(outcomes);
      final text = r.format(outcomes);
      expect(text, contains('OVERALL'));
      expect(text, contains('expected banana'));
      expect(text, contains('banana_bread'));
    });
  });
}
