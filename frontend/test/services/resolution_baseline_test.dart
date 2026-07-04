import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/canonical_resolver_service.dart';
import 'package:mitlist/services/scan/extraction_service.dart';
import 'package:mitlist/services/scan/resolution/ensemble_resolver.dart';
import 'package:mitlist/services/scan/resolution/eval_harness.dart';
import 'package:mitlist/services/scan/resolution/resolution_features.dart';
import 'package:mitlist/services/scan/scan_models.dart';
import 'package:mitlist/storage/app_database.dart';

// Plan 037 — Phase A baseline.
//
// Runs the CURRENT CanonicalResolverService (alias + fuzzy edit-distance — the
// default on-by-everywhere path, no classifier/embedder, which need native libs
// / asset bundles unavailable in a plain `flutter test`) against the REAL seed
// catalogue and the REAL eval dataset, and prints the honest baseline number
// that the ensemble rewrite (Phase B–D) must beat.
//
// This is the "where are we today" instrument. It is deliberately NOT a strict
// pass/fail gate on accuracy — it asserts only that the harness ran over the
// full dataset and prints the metrics. The dataset must be present in a full
// checkout, so a missing file is a broken guard, not a skip.

const _globalGroup = '__global__';
const _evalPath = '../intelligence/ml/data/resolution_eval.jsonl';

AppDatabase _memoryDb() => AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

Future<void> _ingestSeed(AppDatabase db) async {
  final raw = await rootBundle.loadString('assets/grocery/seed.json');
  final parsed = jsonDecode(raw);
  final decoded = ((parsed is Map ? parsed['items'] : parsed) as List)
      .cast<Map<String, dynamic>>();
  final now = DateTime.now();

  final canonical = <CanonicalItemsTableCompanion>[];
  final aliases = <ItemAliasesTableCompanion>[];
  var aliasId = 0;

  for (final item in decoded) {
    final id = item['id'] as String;
    canonical.add(CanonicalItemsTableCompanion.insert(
      id: id,
      groupId: _globalGroup,
      nameDe: Value(item['name_de'] as String? ?? ''),
      nameEn: Value(item['name_en'] as String? ?? ''),
      category: Value(item['category'] as String? ?? ''),
      defaultUnit: Value(item['default_unit'] as String? ?? ''),
      isGlobal: const Value(true),
      version: const Value(0),
      createdAt: now,
      updatedAt: now,
    ));
    void addAlias(String? text, String lang) {
      final n = (text ?? '').toLowerCase().trim();
      if (n.isEmpty) return;
      aliases.add(ItemAliasesTableCompanion.insert(
        id: 'a${aliasId++}',
        groupId: _globalGroup,
        canonicalItemId: id,
        aliasText: n,
        lang: Value(lang),
        source: const Value('seed'),
        weight: const Value(1),
        version: const Value(0),
        createdAt: now,
        updatedAt: now,
      ));
    }

    for (final a in (item['aliases_de'] as List? ?? [])) {
      addAlias(a as String?, 'de');
    }
    for (final a in (item['aliases_en'] as List? ?? [])) {
      addAlias(a as String?, 'en');
    }
    addAlias(item['name_de'] as String?, 'de');
    addAlias(item['name_en'] as String?, 'en');
  }

  for (final chunk in _chunked(canonical, 1000)) {
    await db.upsertCanonicalItems(chunk);
  }
  for (final chunk in _chunked(aliases, 4000)) {
    await db.upsertItemAliases(chunk);
  }
}

Iterable<List<T>> _chunked<T>(List<T> rows, int size) sync* {
  for (var i = 0; i < rows.length; i += size) {
    yield rows.sublist(i, (i + size).clamp(0, rows.length));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('BASELINE: current alias+fuzzy resolver over the real eval set', () async {
    final file = File(_evalPath);
    if (!file.existsSync()) {
      fail('eval dataset missing at $_evalPath - this guard must not pass vacuously');
    }
    final cases = ResolutionEvalCase.parseJsonl(await file.readAsString());
    expect(cases, isNotEmpty, reason: 'eval dataset should have rows');

    final db = _memoryDb();
    addTearDown(db.close);
    await _ingestSeed(db);

    final baseline = CanonicalResolverService(db); // old sequential path
    final ensemble = EnsembleResolver(db); // new path (no classifier/embedder)
    final extraction = ExtractionService();

    // Apples-to-apples: BOTH run without classifier/embedder (those need native
    // libs / asset bundles unavailable here), so this isolates the contribution
    // of candidate-union + canonicalNameSim + the household prior alone. The
    // model voters only widen the lead in production.
    final baseOutcomes = <ResolutionEvalOutcome>[];
    final ensOutcomes = <ResolutionEvalOutcome>[];
    for (final c in cases) {
      // Mirror the production pipeline: OCR line → extraction (strips
      // qty/unit/price) → resolution.
      final parsed = extraction.extract(OcrLine(text: c.rawText));

      final b = await baseline.resolve(parsed.itemName, 'baseline-household');
      baseOutcomes.add(ResolutionEvalOutcome(
        evalCase: c,
        predictedCanonicalId: b.canonicalItemId,
        score: b.score,
      ));

      // Household prior from the eval row (frequency from household_purchases).
      final counts = <String, int>{};
      for (final id in c.householdPurchases) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
      final e = await ensemble.resolve(
        parsed.itemName,
        'baseline-household',
        context: ResolutionContext(purchaseCounts: counts),
      );
      ensOutcomes.add(ResolutionEvalOutcome(
        evalCase: c,
        predictedCanonicalId: e.canonicalItemId,
        score: e.score,
      ));
    }

    final baseReport = ResolutionReport.build(baseOutcomes);
    final ensReport = ResolutionReport.build(ensOutcomes);
    // ignore: avoid_print
    print('\n=== BASELINE (current sequential resolver) ===');
    // ignore: avoid_print
    print(baseReport.format(baseOutcomes));
    // ignore: avoid_print
    print('=== ENSEMBLE (plan 037, no classifier/embedder) ===');
    // ignore: avoid_print
    print(ensReport.format(ensOutcomes));

    expect(baseReport.overall.total, cases.length);
    expect(ensReport.overall.total, cases.length);
    // The ensemble must not regress top-1 vs the sequential baseline...
    expect(ensReport.overall.top1Accuracy,
        greaterThanOrEqualTo(baseReport.overall.top1Accuracy));
    // ...and must strictly improve precision@auto-accept — the genius metric.
    // The baseline confidently auto-accepts wrong answers; the ensemble must not.
    expect(ensReport.overall.precisionAtAutoAccept,
        greaterThan(baseReport.overall.precisionAtAutoAccept));
  });
}
