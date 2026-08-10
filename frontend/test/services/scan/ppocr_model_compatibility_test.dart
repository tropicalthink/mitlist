import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onnxruntime/onnxruntime.dart';

void main() {
  const detectorPath = 'assets/models/ocr/ppocrv6_small_det/inference.onnx';
  const recognizerPath = 'assets/models/ocr/ppocrv6_medium_rec/inference.onnx';

  final runCompatibility =
      Platform.environment['RUN_PPOCR_MODEL_COMPATIBILITY'] == '1';

  test('bundled PP-OCRv6 graphs load in the shipped ONNX Runtime', () {
    OrtEnv.instance.init();
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(2)
      ..setInterOpNumThreads(1)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    try {
      for (final path in [detectorPath, recognizerPath]) {
        final session = OrtSession.fromFile(File(path), options);
        try {
          expect(session.inputNames, ['x']);
          expect(session.outputNames, ['fetch_name_0']);
        } finally {
          session.release();
        }
      }
    } finally {
      options.release();
      OrtEnv.instance.release();
    }
  },
      skip: runCompatibility
          ? false
          : 'Set RUN_PPOCR_MODEL_COMPATIBILITY=1 for the native graph check.');
}
