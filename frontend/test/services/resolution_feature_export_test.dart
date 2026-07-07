import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/extraction_service.dart';
import 'package:mitlist/services/scan/resolution/candidate_generator.dart';
import 'package:mitlist/services/scan/resolution/eval_harness.dart';
import 'package:mitlist/services/scan/resolution/resolution_features.dart';
import 'package:mitlist/services/scan/scan_models.dart';

import '../support/grocery_seed_test_helper.dart';

// Plan 037 — Phase D, the parity bridge.
//
// Exports the EXACT feature vectors the Dart ensemble computes at inference,
// labelled (1 = the expected canonical item, 0 = a distractor), for every
// candidate of every eval row. The build-time fitter
// (intelligence/ml/eval/resolution_eval.py) fits the logistic-regression
// weights on this dump — so the weights are calibrated on the same features the
// app uses, with no Python re-implementation of feature math to drift out of
// sync.
//
// Gated behind EXPORT_RESOLUTION_FEATURES=1 so ordinary `flutter test` runs do
// not rewrite the data file. Maintainer:
//   EXPORT_RESOLUTION_FEATURES=1 flutter test test/services/resolution_feature_export_test.dart
//
// NOTE: in a plain `flutter test` the classifier/embedder are unavailable, so
// their feature columns export as 0. For a full-signal fit, run the export in
// an environment where those models load (a device/integration run).

const _evalPath = '../intelligence/ml/data/resolution_eval.jsonl';
const _outPath = '../intelligence/ml/data/resolution_features.jsonl';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('export labelled feature vectors for the eval set', () async {
    if (Platform.environment['EXPORT_RESOLUTION_FEATURES'] != '1') {
      markTestSkipped('set EXPORT_RESOLUTION_FEATURES=1 to write the dump');
      return;
    }
    final evalFile = File(_evalPath);
    if (!evalFile.existsSync()) {
      markTestSkipped('eval dataset not present at $_evalPath');
      return;
    }
    final cases = ResolutionEvalCase.parseJsonl(await evalFile.readAsString());

    final db = memoryDb();
    addTearDown(db.close);
    await ingestRealSeed(db);

    final generator = CandidateGenerator(db); // alias+fuzzy in this env
    final extraction = ExtractionService();

    final out = StringBuffer();
    var rowCount = 0;
    var positives = 0;
    for (final c in cases) {
      final parsed = extraction.extract(OcrLine(text: c.rawText));
      final query = normaliseTextForExport(parsed.itemName);
      final candidates =
          await generator.generate(parsed.itemName, kGlobalGroup);

      // Household prior from the row's labelled context.
      final counts = <String, int>{};
      for (final id in c.householdPurchases) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
      final ctx = ResolutionContext(purchaseCounts: counts);

      for (final cand in candidates) {
        final features = buildResolutionFeatures(cand, query, ctx);
        final label = cand.canonicalItemId == c.expectedCanonicalId ? 1 : 0;
        if (label == 1) positives++;
        rowCount++;
        out.writeln(jsonEncode({
          'raw_text': c.rawText,
          'input_type': c.inputType,
          'candidate_id': cand.canonicalItemId,
          'expected_id': c.expectedCanonicalId,
          'label': label,
          'features': features,
        }));
      }
    }

    await File(_outPath).writeAsString(
      '# feature_names: ${kResolutionFeatureNames.join(",")}\n$out',
    );
    // ignore: avoid_print
    print('exported $rowCount candidate rows ($positives positive) '
        'over ${cases.length} eval cases → $_outPath');

    expect(rowCount, greaterThan(0));
  });
}

/// Local copy of the normalisation the resolver applies, to avoid importing the
/// private helper. Kept identical to string_sim.normaliseText.
String normaliseTextForExport(String s) =>
    s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
