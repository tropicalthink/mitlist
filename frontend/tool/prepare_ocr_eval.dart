// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'ocr_eval_support.dart';

const _manifestPath = 'test/fixtures/ocr_eval_manifest.json';
const _outputPath = 'integration_test/ocr_eval_test.local.dart';

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/prepare_ocr_eval.dart /path/to/sample-images',
    );
    exitCode = 64;
    return;
  }

  final manifestFile = File(_manifestPath);
  if (!manifestFile.existsSync()) {
    stderr.writeln('Manifest not found: ${manifestFile.absolute.path}');
    exitCode = 66;
    return;
  }
  final manifestContent = manifestFile.readAsStringSync();
  final manifest = OcrEvalManifest.decode(manifestContent);
  final sampleDirectory = Directory(arguments.single);
  if (!sampleDirectory.existsSync()) {
    stderr.writeln('Sample directory not found: ${sampleDirectory.path}');
    exitCode = 66;
    return;
  }

  final encodedImages = <String, String>{};
  var totalBytes = 0;
  for (final sample in manifest.samples) {
    final image = File('${sampleDirectory.path}/${sample.filename}');
    if (!image.existsSync()) {
      stderr.writeln('Missing sample ${sample.id}: ${image.path}');
      exitCode = 66;
      return;
    }
    final bytes = image.readAsBytesSync();
    totalBytes += bytes.length;
    encodedImages[sample.id] = base64Encode(bytes);
  }

  final output = File(_outputPath);
  output.parent.createSync(recursive: true);
  final source = StringBuffer()
    ..writeln('// Generated locally by tool/prepare_ocr_eval.dart.')
    ..writeln('// Contains private sample photos. Do not commit.')
    ..writeln()
    ..writeln("import 'ocr_eval_harness.dart';")
    ..writeln()
    ..writeln('void main() => runOcrEval(')
    ..writeln(
      "  manifestBase64: '${base64Encode(utf8.encode(manifestContent))}',",
    )
    ..writeln('  imagePayloads: const {');
  for (final entry in encodedImages.entries) {
    source.writeln("    '${entry.key}': '${entry.value}',");
  }
  source
    ..writeln('  },')
    ..writeln(');');
  output.writeAsStringSync(source.toString());

  final fixtures = Directory('test/fixtures');
  for (final entity in fixtures.listSync()) {
    if (entity is File &&
        RegExp(r'ocr_eval\.local(?:\.\d+)?\.json$').hasMatch(entity.path)) {
      entity.deleteSync();
    }
  }
  print(
    'Prepared ${manifest.samples.length} private samples '
    '(${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MiB) at $_outputPath.',
  );
  print('The generated payload is gitignored and is not a production asset.');
}
