/// Plan 012 Workstream C — OCR eval runner (Flutter integration test).
///
/// Drives the real [OcrService] against a labelled image dataset and writes
/// OcrResult JSONL, which is then scored by the Python harness:
///
///   python3 intelligence/ml/eval/ocr_eval.py --mode score \
///       --dataset intelligence/ml/data/ocr_eval_dataset.jsonl \
///       --results intelligence/ml/data/ocr_results_mlkit.jsonl
///
/// ## How to run
///
/// Requires a connected device or emulator with ML Kit models available.
/// The dataset rows whose `image_path` doesn't resolve to a real file are
/// skipped with a warning — the test does not fail on missing images so that
/// CI stays green before real photos are added.
///
///   flutter test test/services/scan/ocr_eval_runner_test.dart \
///       --dart-define=OCR_BACKEND=mlkit \
///       --dart-define=DATASET_PATH=intelligence/ml/data/ocr_eval_dataset.jsonl \
///       --dart-define=OUT_PATH=intelligence/ml/data/ocr_results_mlkit.jsonl
///
/// Defaults (all overridable via --dart-define):
///   OCR_BACKEND = mlkit
///   DATASET_PATH = intelligence/ml/data/ocr_eval_dataset.jsonl
///   OUT_PATH     = intelligence/ml/data/ocr_results_mlkit.jsonl
///
/// ## Status: SCAFFOLD — gaps to fill when plan-012 A+B land
///
/// GAP 1: [OcrService] currently needs a real Flutter environment for path_provider
///        and ML Kit.  Replace `_runMlKit` with the real call once the service is
///        injectable / testable with a stub file-system.
///
/// GAP 2: `image_path` in the dataset is relative to repo root.  The runner
///        needs a way to find the absolute repo root from inside `flutter test`.
///        The `--dart-define=REPO_ROOT=/abs/path` pattern (used in the
///        resolution feature export test) is the precedent.
///
/// GAP 3: Real photos in `intelligence/ml/data/ocr_samples/` don't exist yet.
///        Without them the test runs zero images and writes an empty JSONL
///        (which the Python scorer handles gracefully).
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';

// Import OcrService only when real ML Kit is available.
// During scaffold phase, this is commented out; uncomment after plan-012 A+B.
// import 'package:mitlist/services/scan/ocr_service.dart';

// ---------------------------------------------------------------------------
// Constants (overridable via --dart-define)
// ---------------------------------------------------------------------------

const String _backend =
    String.fromEnvironment('OCR_BACKEND', defaultValue: 'mlkit');

const String _datasetPath = String.fromEnvironment(
  'DATASET_PATH',
  defaultValue: 'intelligence/ml/data/ocr_eval_dataset.jsonl',
);

const String _outPath = String.fromEnvironment(
  'OUT_PATH',
  defaultValue: 'intelligence/ml/data/ocr_results_mlkit.jsonl',
);

// Repo root: pass via --dart-define=REPO_ROOT=/abs/path (mirrors
// resolution_feature_export_test pattern).  Falls back to CWD which works
// when running `flutter test` from the frontend/ directory.
const String _repoRoot = String.fromEnvironment('REPO_ROOT', defaultValue: '');

// ---------------------------------------------------------------------------
// Dataset row (matches ocr_eval.schema.md)
// ---------------------------------------------------------------------------

class _DatasetRow {
  final String imagePath;
  final String inputType;
  final List<String> groundTruthLines;
  final String? note;

  const _DatasetRow({
    required this.imagePath,
    required this.inputType,
    required this.groundTruthLines,
    this.note,
  });

  factory _DatasetRow.fromJson(Map<String, dynamic> json) {
    return _DatasetRow(
      imagePath: json['image_path'] as String,
      inputType: json['input_type'] as String? ?? 'print',
      groundTruthLines: (json['ground_truth_lines'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      note: json['note'] as String?,
    );
  }

  static List<_DatasetRow> parseJsonl(String content) {
    final rows = <_DatasetRow>[];
    for (final line in const LineSplitter().convert(content)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      rows.add(
          _DatasetRow.fromJson(jsonDecode(trimmed) as Map<String, dynamic>));
    }
    return rows;
  }
}

// ---------------------------------------------------------------------------
// OCR backends
// ---------------------------------------------------------------------------

/// Calls the real [OcrService] (ML Kit Latin).
///
/// GAP: Uncomment the OcrService import above and wire this up once
/// plan-012 A+B land and OcrService is injectable.
Future<List<String>> _runMlKit(String absoluteImagePath) async {
  // SCAFFOLD — replace with real call:
  //   final svc = OcrService();
  //   final lines = await svc.recogniseFromPath(absoluteImagePath);
  //   await svc.dispose();
  //   return lines.map((l) => l.text).toList();
  throw UnimplementedError(
    'ML Kit runner not yet wired. '
    'Fill in _runMlKit() after plan-012 A+B land.',
  );
}

/// Stub runner for dry-run without real models or images.
Future<List<String>> _runStub(
    List<String> groundTruth, String inputType) async {
  // Simulate mild print noise or heavier handwriting noise.
  // This is identical to the Python stub so both produce comparable outputs.
  final severity = inputType == 'print' ? 0.1 : 0.45;
  final rng = _SeededRandom(42);
  return groundTruth.map((line) {
    final chars = line.split('');
    final result = <String>[];
    for (final c in chars) {
      if (rng.nextDouble() < severity * 0.15) {
        // deletion
      } else if (rng.nextDouble() < severity * 0.10) {
        result.add('a');
      } else if (rng.nextDouble() < severity * 0.08) {
        result.add('x');
      } else {
        result.add(c);
      }
    }
    return result.join();
  }).toList();
}

// ---------------------------------------------------------------------------
// Minimal seeded random (avoids dart:math import complexity in test context)
// ---------------------------------------------------------------------------

class _SeededRandom {
  int _state;
  _SeededRandom(this._state);
  double nextDouble() {
    _state = (_state * 1664525 + 1013904223) & 0xFFFFFFFF;
    return (_state & 0x7FFFFFFF) / 0x7FFFFFFF;
  }
}

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

Future<void> _runEval({required bool stubMode}) async {
  // Resolve repo root.
  final repoRoot = _repoRoot.isNotEmpty
      ? Directory(_repoRoot)
      : Directory.current.parent; // frontend/../ = repo root when cwd=frontend

  final datasetFile = File('${repoRoot.path}/$_datasetPath');
  if (!datasetFile.existsSync()) {
    debugPrint('[ocr_eval_runner] dataset not found: ${datasetFile.path}');
    debugPrint('[ocr_eval_runner] Run in stub mode with a populated dataset.');
    return;
  }

  final rows = _DatasetRow.parseJsonl(datasetFile.readAsStringSync());
  if (rows.isEmpty) {
    debugPrint(
        '[ocr_eval_runner] dataset has no active rows (all commented out)');
    return;
  }

  final results = <Map<String, dynamic>>[];
  var skipped = 0;

  for (final row in rows) {
    final absPath = '${repoRoot.path}/${row.imagePath}';
    final imgFile = File(absPath);

    if (!stubMode && !imgFile.existsSync()) {
      debugPrint('[ocr_eval_runner] image not found, skipping: $absPath');
      skipped++;
      continue;
    }

    final stopwatch = Stopwatch()..start();
    List<String> recognized;
    String? runnerNote;

    if (stubMode) {
      recognized = await _runStub(row.groundTruthLines, row.inputType);
    } else {
      try {
        recognized = await _runMlKit(absPath);
      } on UnimplementedError catch (e) {
        recognized = const [];
        runnerNote = 'UnimplementedError: ${e.message}';
        skipped++;
      } catch (e) {
        recognized = const [];
        runnerNote = 'Error: $e';
        skipped++;
      }
    }

    stopwatch.stop();

    results.add({
      'image_path': row.imagePath,
      'input_type': row.inputType,
      'backend': _backend,
      'recognized_lines': recognized,
      'latency_ms': stopwatch.elapsedMicroseconds / 1000.0,
      if (runnerNote != null) 'note': runnerNote,
    });
  }

  // Write output JSONL.
  final outFile = File('${repoRoot.path}/$_outPath');
  outFile.parent.createSync(recursive: true);
  final sink = outFile.openWrite();
  for (final r in results) {
    sink.writeln(jsonEncode(r));
  }
  await sink.flush();
  await sink.close();

  debugPrint(
      '[ocr_eval_runner] wrote ${results.length} results → ${outFile.path}');
  if (skipped > 0) {
    debugPrint(
        '[ocr_eval_runner] skipped $skipped rows (missing images or errors)');
  }
  debugPrint('[ocr_eval_runner] score with:');
  debugPrint('  python3 intelligence/ml/eval/ocr_eval.py --mode score \\');
  debugPrint('      --dataset $_datasetPath \\');
  debugPrint('      --results $_outPath');
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Structural test — verifies dataset parsing and result JSONL writing
  // without requiring real images or ML Kit.
  group('OCR eval runner — structural (stub mode)', () {
    test('parses dataset JSONL correctly (schema contract)', () {
      // JSONL = one JSON object per line; objects must not wrap across lines.
      const jsonl = '''
# comment
{"image_path": "ocr_samples/p1.jpg", "input_type": "print", "ground_truth_lines": ["Milch", "Eier"], "note": "test"}
{"image_path": "ocr_samples/h1.jpg", "input_type": "handwriting", "ground_truth_lines": ["mlch", "Egg"]}
''';
      final rows = _DatasetRow.parseJsonl(jsonl);
      expect(rows, hasLength(2));
      expect(rows[0].inputType, 'print');
      expect(rows[0].groundTruthLines, ['Milch', 'Eier']);
      expect(rows[1].inputType, 'handwriting');
      expect(rows[1].note, isNull);
    });

    test('stub runner produces one output per input line', () async {
      final out = await _runStub(['Milch', 'Eier', 'Bananen'], 'print');
      expect(out, hasLength(3));
    });

    test('stub runner introduces more noise for handwriting', () async {
      // Print should have fewer deletions/subs than handwriting on same input.
      const lines = ['Milchkaffee', 'Weizenmehl', 'Haferflocken'];
      final print = await _runStub(lines, 'print');
      final hw = await _runStub(lines, 'handwriting');
      // Handwriting strings should be shorter (more deletions) on average.
      final printLen = print.join().length;
      final hwLen = hw.join().length;
      // This is probabilistic (seeded), so check direction rather than exact.
      expect(hwLen, lessThanOrEqualTo(printLen));
    });
  });

  // Full runner — skip if dataset or images are not present (CI-safe).
  // Activate locally once you have real photos and dataset rows.
  group('OCR eval runner — full (requires real images)', () {
    test('runs in stub mode and writes output JSONL', () async {
      // Uses stub mode so this passes even without real images.
      // To run with real ML Kit: set stubMode: false and ensure images exist.
      await _runEval(stubMode: true);
      // No assertion — the test passes if it completes without error.
      // Check the output file manually or score with ocr_eval.py.
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
