import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/ocr_eval_support.dart';

void main() {
  late OcrEvalManifest manifest;

  setUpAll(() {
    manifest = OcrEvalManifest.decode(
      File('test/fixtures/ocr_eval_manifest.json').readAsStringSync(),
    );
  });

  test('real sample manifest has readable and negative examples', () {
    final lines = manifest.samples.expand((sample) => sample.lines).toList();
    expect(manifest.samples, hasLength(6));
    expect(
      lines.where((line) => line.status != GroundTruthStatus.illegible),
      hasLength(45),
    );
    expect(
      lines.where((line) => line.status == GroundTruthStatus.crossedOut),
      hasLength(6),
    );
    expect(
      lines.where((line) => line.status == GroundTruthStatus.illegible),
      hasLength(2),
    );
  });

  test('perfect device output scores perfectly', () {
    final results = <String, dynamic>{
      'backend': 'perfect_stub',
      'samples': [
        for (final sample in manifest.samples)
          {
            'id': sample.id,
            'latency_ms': 10,
            'lines': [
              for (final line in sample.lines)
                if (line.status != GroundTruthStatus.illegible)
                  {
                    'text': line.text,
                    'mark_status': line.status == GroundTruthStatus.crossedOut
                        ? 'crossedOut'
                        : 'normal',
                  },
            ],
          },
      ],
    };
    final score = scoreOcrEvaluation(manifest, results);
    expect(score['cer'], 0);
    expect(score['wer'], 0);
    expect(score['readable_line_recall'], 1);
    expect(score['exact_line_rate'], 1);
    expect(score['crossed_out_detection_recall'], 1);
    expect(score['unmatched_prediction_count'], 0);
  });

  test('missing and spurious text are surfaced', () {
    final fixture = OcrEvalManifest.decode(jsonEncode({
      'schema_version': 1,
      'locale': 'de-DE',
      'samples': [
        {
          'id': 'x',
          'filename': 'x.jpg',
          'input_type': 'handwriting',
          'lines': [
            {'text': 'Milch', 'status': 'active'},
            {'text': 'Kaffee', 'status': 'crossed_out'},
            {'text': null, 'status': 'illegible'},
          ],
        },
      ],
    }));
    final score = scoreOcrEvaluation(fixture, {
      'backend': 'bad_stub',
      'samples': [
        {
          'id': 'x',
          'lines': [
            {'text': 'Milsh', 'mark_status': 'normal'},
            {'text': 'invented', 'mark_status': 'normal'},
          ],
        },
      ],
    });
    expect(score['cer'], greaterThan(0));
    expect(score['wer'], greaterThan(0));
    expect(score['readable_line_recall'], lessThan(1));
    expect(score['crossed_out_detection_recall'], 0);
    expect(score['illegible_region_count'], 1);
  });
}
