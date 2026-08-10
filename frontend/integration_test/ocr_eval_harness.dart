import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mitlist/services/scan/extraction_service.dart';
import 'package:mitlist/services/scan/ocr_service.dart';

import '../tool/ocr_eval_support.dart';

void runOcrEval({
  required String manifestBase64,
  required Map<String, String> imagePayloads,
}) {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('records the on-device OCR benchmark', (_) async {
    final manifest = OcrEvalManifest.decode(
      utf8.decode(base64Decode(manifestBase64)),
    );
    final ocr = OcrService();
    final extraction = ExtractionService();
    final results = <Map<String, dynamic>>[];
    final errors = <String>[];

    try {
      for (final sample in manifest.samples) {
        final encodedImage = imagePayloads[sample.id];
        if (encodedImage == null || encodedImage.isEmpty) {
          errors.add('${sample.id}: image payload is missing');
          results.add({
            'id': sample.id,
            'filename': sample.filename,
            'lines': <dynamic>[],
            'error': 'image payload is missing',
          });
          continue;
        }

        final sourceBytes = Uint8List.fromList(base64Decode(encodedImage));
        final stopwatch = Stopwatch()..start();
        try {
          final lines = await ocr.recognise(sourceBytes);
          stopwatch.stop();
          results.add({
            'id': sample.id,
            'filename': sample.filename,
            'input_type': sample.inputType,
            'latency_ms': stopwatch.elapsedMicroseconds / 1000,
            'preprocessing': 'portable_ppocrv6',
            'source_bytes': sourceBytes.length,
            'ocr_input_bytes': sourceBytes.length,
            'lines': [
              for (final line in lines)
                {
                  'text': line.text,
                  'confidence': line.confidence,
                  'mark_status': extraction.extract(line).markStatus.name,
                  'alternatives': [
                    for (final alternative in line.alternatives)
                      {
                        'text': alternative.text,
                        'relative_score': alternative.relativeScore,
                      },
                  ],
                  if (line.bbox case final box?)
                    'bbox': {
                      'left': box.left,
                      'top': box.top,
                      'width': box.width,
                      'height': box.height,
                    },
                },
            ],
          });
        } catch (error, stackTrace) {
          stopwatch.stop();
          errors.add('${sample.id}: $error');
          results.add({
            'id': sample.id,
            'filename': sample.filename,
            'latency_ms': stopwatch.elapsedMicroseconds / 1000,
            'preprocessing': 'portable_ppocrv6',
            'lines': <dynamic>[],
            'error': '$error',
            'stack_trace': '$stackTrace',
          });
        }
      }
    } finally {
      await ocr.dispose();
    }

    binding.reportData = {
      'schema_version': 1,
      'backend': 'ppocrv6_small_det_medium_rec_onnx',
      'samples': results,
    };
    expect(errors, isEmpty, reason: errors.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
