// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'ocr_eval_support.dart';

const _manifestPath = 'test/fixtures/ocr_eval_manifest.json';
const _targetPath = 'integration_test/ocr_eval_test.local.dart';
const _rawResultPath = 'build/ocr_eval_results_ppocrv6_device.json';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/run_ocr_eval.dart DEVICE_ID');
    exitCode = 64;
    return;
  }
  if (!File(_targetPath).existsSync()) {
    stderr.writeln(
      'Missing $_targetPath. Run tool/prepare_ocr_eval.dart first.',
    );
    exitCode = 66;
    return;
  }

  final process = await Process.start(
    'flutter',
    [
      'drive',
      '--driver=test_driver/ocr_eval_driver.dart',
      '--target=$_targetPath',
      '-d',
      arguments.single,
    ],
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;
  if (code != 0) {
    exitCode = code;
    return;
  }
  if (!File(_rawResultPath).existsSync()) {
    stderr.writeln('Device result was not written to $_rawResultPath.');
    exitCode = 74;
    return;
  }

  final manifest =
      OcrEvalManifest.decode(File(_manifestPath).readAsStringSync());
  final resultDocument = (jsonDecode(File(_rawResultPath).readAsStringSync())
          as Map<dynamic, dynamic>)
      .cast<String, dynamic>();
  final score = scoreOcrEvaluation(manifest, resultDocument);
  print('\n${const JsonEncoder.withIndent('  ').convert(score)}');
  print('\nRaw device output: $_rawResultPath');
}
