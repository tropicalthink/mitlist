/// Plan 037 — Phase A instrument.
///
/// Pure, dependency-free scoring of resolution quality against a labelled eval
/// set. No DB, no I/O, no Flutter — feed it the per-row outcomes produced by
/// whatever resolver you are measuring and it returns the metrics that define
/// "insane correct rate": top-1 accuracy, precision@auto-accept, and coverage,
/// scored overall and split by `input_type` (print vs handwriting are never
/// blended — see intelligence/plan.md §19).
library;

import 'dart:convert';

/// One labelled row of the eval set (see
/// `intelligence/ml/eval/resolution_eval.schema.md`).
class ResolutionEvalCase {
  /// Exactly what the OCR/extraction layer emits for one line, pre-resolution.
  final String rawText;

  /// The correct seed canonical id this should resolve to.
  final String expectedCanonicalId;

  /// `print` | `handwriting` — scored separately.
  final String inputType;

  /// Human-readable difficulty/intent label. Documentation only; not scored.
  final String? note;

  /// Canonical ids already on the current list (feeds co-occurrence prior).
  final List<String> listContext;

  /// Canonical ids this household has bought before (feeds frequency prior).
  final List<String> householdPurchases;

  const ResolutionEvalCase({
    required this.rawText,
    required this.expectedCanonicalId,
    required this.inputType,
    this.note,
    this.listContext = const [],
    this.householdPurchases = const [],
  });

  factory ResolutionEvalCase.fromJson(Map<String, dynamic> json) {
    List<String> strList(Object? v) =>
        (v as List?)?.map((e) => e as String).toList() ?? const [];
    return ResolutionEvalCase(
      rawText: json['raw_text'] as String,
      expectedCanonicalId: json['expected_canonical_id'] as String,
      inputType: json['input_type'] as String? ?? 'print',
      note: json['note'] as String?,
      listContext: strList(json['list_context']),
      householdPurchases: strList(json['household_purchases']),
    );
  }

  /// Parses a JSONL document (one object per line; blank lines ignored).
  static List<ResolutionEvalCase> parseJsonl(String jsonl) {
    final cases = <ResolutionEvalCase>[];
    for (final line in const LineSplitter().convert(jsonl)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      cases.add(ResolutionEvalCase.fromJson(
          jsonDecode(trimmed) as Map<String, dynamic>));
    }
    return cases;
  }
}

/// The result of running one [ResolutionEvalCase] through a resolver.
class ResolutionEvalOutcome {
  final ResolutionEvalCase evalCase;

  /// What the resolver chose, or null if it produced no canonical match.
  final String? predictedCanonicalId;

  /// The resolver's confidence in [predictedCanonicalId], 0–1.
  final double score;

  const ResolutionEvalOutcome({
    required this.evalCase,
    required this.predictedCanonicalId,
    required this.score,
  });

  bool get isCorrect =>
      predictedCanonicalId != null &&
      predictedCanonicalId == evalCase.expectedCanonicalId;
}

/// Metrics for a set of outcomes. All rates are in [0, 1]; `total` is the count.
class ResolutionMetrics {
  final int total;

  /// Did the chosen candidate equal the expected id? Ignores confidence.
  final double top1Accuracy;

  /// Of rows auto-accepted (score ≥ τ_auto), the fraction that were correct.
  /// The "genius" number — must approach ~0.99. NaN when nothing was accepted.
  final double precisionAtAutoAccept;

  /// Fraction of rows auto-accepted. Keeps precision honest (abstaining on
  /// everything makes precision trivially high but coverage 0).
  final double coverage;

  /// Count auto-accepted (score ≥ τ_auto).
  final int autoAccepted;

  /// Count auto-accepted AND correct.
  final int autoAcceptedCorrect;

  const ResolutionMetrics({
    required this.total,
    required this.top1Accuracy,
    required this.precisionAtAutoAccept,
    required this.coverage,
    required this.autoAccepted,
    required this.autoAcceptedCorrect,
  });

  /// Computes metrics over [outcomes]. A row is auto-accepted when its score is
  /// at or above [tauAuto] (default 0.85 — today's hardcoded ConfidenceService
  /// auto-accept threshold).
  static ResolutionMetrics compute(
    List<ResolutionEvalOutcome> outcomes, {
    double tauAuto = 0.85,
  }) {
    final total = outcomes.length;
    if (total == 0) {
      return const ResolutionMetrics(
        total: 0,
        top1Accuracy: double.nan,
        precisionAtAutoAccept: double.nan,
        coverage: 0,
        autoAccepted: 0,
        autoAcceptedCorrect: 0,
      );
    }
    var correct = 0;
    var accepted = 0;
    var acceptedCorrect = 0;
    for (final o in outcomes) {
      if (o.isCorrect) correct++;
      if (o.score >= tauAuto) {
        accepted++;
        if (o.isCorrect) acceptedCorrect++;
      }
    }
    return ResolutionMetrics(
      total: total,
      top1Accuracy: correct / total,
      precisionAtAutoAccept:
          accepted == 0 ? double.nan : acceptedCorrect / accepted,
      coverage: accepted / total,
      autoAccepted: accepted,
      autoAcceptedCorrect: acceptedCorrect,
    );
  }

  String pct(double v) => v.isNaN ? '   —  ' : '${(v * 100).toStringAsFixed(1)}%';

  String get summaryLine =>
      'n=$total  top1=${pct(top1Accuracy)}  '
      'precision@auto=${pct(precisionAtAutoAccept)} ($autoAcceptedCorrect/$autoAccepted)  '
      'coverage=${pct(coverage)}';
}

/// Computes overall metrics plus a per-`input_type` breakdown.
class ResolutionReport {
  final ResolutionMetrics overall;
  final Map<String, ResolutionMetrics> byInputType;
  final double tauAuto;

  const ResolutionReport({
    required this.overall,
    required this.byInputType,
    required this.tauAuto,
  });

  static ResolutionReport build(
    List<ResolutionEvalOutcome> outcomes, {
    double tauAuto = 0.85,
  }) {
    final groups = <String, List<ResolutionEvalOutcome>>{};
    for (final o in outcomes) {
      (groups[o.evalCase.inputType] ??= []).add(o);
    }
    return ResolutionReport(
      overall: ResolutionMetrics.compute(outcomes, tauAuto: tauAuto),
      byInputType: {
        for (final e in groups.entries)
          e.key: ResolutionMetrics.compute(e.value, tauAuto: tauAuto),
      },
      tauAuto: tauAuto,
    );
  }

  /// A human-readable report block, including which rows missed — the actionable
  /// part for driving the number up.
  String format(List<ResolutionEvalOutcome> outcomes) {
    final b = StringBuffer();
    b.writeln('── Resolution eval (τ_auto=$tauAuto) ──');
    b.writeln('OVERALL   ${overall.summaryLine}');
    final types = byInputType.keys.toList()..sort();
    for (final t in types) {
      b.writeln('${t.padRight(9).substring(0, 9)} ${byInputType[t]!.summaryLine}');
    }
    final misses = outcomes.where((o) => !o.isCorrect).toList();
    if (misses.isNotEmpty) {
      b.writeln('misses (${misses.length}):');
      for (final m in misses) {
        b.writeln('  "${m.evalCase.rawText}" → '
            '${m.predictedCanonicalId ?? "(none)"} '
            '[${m.score.toStringAsFixed(2)}]  '
            'expected ${m.evalCase.expectedCanonicalId}');
      }
    }
    return b.toString();
  }
}
