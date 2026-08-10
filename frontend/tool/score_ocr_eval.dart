// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'ocr_eval_support.dart';

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/score_ocr_eval.dart '
      '<manifest.json> <device-results.json>',
    );
    exitCode = 64;
    return;
  }
  final manifestFile = File(arguments[0]);
  final resultsFile = File(arguments[1]);
  if (!manifestFile.existsSync() || !resultsFile.existsSync()) {
    stderr.writeln('Manifest and results files must both exist.');
    exitCode = 66;
    return;
  }

  final manifest = OcrEvalManifest.decode(manifestFile.readAsStringSync());
  final resultDocument =
      (jsonDecode(resultsFile.readAsStringSync()) as Map<dynamic, dynamic>)
          .cast<String, dynamic>();
  final score = scoreOcrEvaluation(manifest, resultDocument);
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(score));
}
