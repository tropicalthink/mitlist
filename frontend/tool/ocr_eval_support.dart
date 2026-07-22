import 'dart:convert';

enum GroundTruthStatus { active, crossedOut, illegible }

GroundTruthStatus _parseStatus(String value) => switch (value) {
      'active' => GroundTruthStatus.active,
      'crossed_out' => GroundTruthStatus.crossedOut,
      'illegible' => GroundTruthStatus.illegible,
      _ => throw FormatException('Unknown OCR ground-truth status: $value'),
    };

class OcrGroundTruthLine {
  final String? text;
  final GroundTruthStatus status;

  const OcrGroundTruthLine({required this.text, required this.status});

  factory OcrGroundTruthLine.fromJson(Map<String, dynamic> json) {
    final status = _parseStatus(json['status'] as String);
    final text = json['text'] as String?;
    if (status == GroundTruthStatus.illegible && text != null) {
      throw const FormatException('Illegible lines must have null text.');
    }
    if (status != GroundTruthStatus.illegible &&
        (text == null || text.trim().isEmpty)) {
      throw const FormatException('Readable lines must have non-empty text.');
    }
    return OcrGroundTruthLine(text: text, status: status);
  }
}

class OcrEvalSample {
  final String id;
  final String filename;
  final String inputType;
  final List<OcrGroundTruthLine> lines;
  final String? note;

  const OcrEvalSample({
    required this.id,
    required this.filename,
    required this.inputType,
    required this.lines,
    this.note,
  });

  factory OcrEvalSample.fromJson(Map<String, dynamic> json) => OcrEvalSample(
        id: json['id'] as String,
        filename: json['filename'] as String,
        inputType: json['input_type'] as String,
        lines: (json['lines'] as List<dynamic>)
            .map((line) => OcrGroundTruthLine.fromJson(
                (line as Map<dynamic, dynamic>).cast<String, dynamic>()))
            .toList(growable: false),
        note: json['note'] as String?,
      );
}

class OcrEvalManifest {
  final int schemaVersion;
  final String locale;
  final List<OcrEvalSample> samples;

  const OcrEvalManifest({
    required this.schemaVersion,
    required this.locale,
    required this.samples,
  });

  factory OcrEvalManifest.decode(String content) {
    final json =
        (jsonDecode(content) as Map<dynamic, dynamic>).cast<String, dynamic>();
    final manifest = OcrEvalManifest(
      schemaVersion: json['schema_version'] as int,
      locale: json['locale'] as String,
      samples: (json['samples'] as List<dynamic>)
          .map((sample) => OcrEvalSample.fromJson(
              (sample as Map<dynamic, dynamic>).cast<String, dynamic>()))
          .toList(growable: false),
    );
    if (manifest.schemaVersion != 1) {
      throw FormatException(
          'Unsupported OCR manifest schema ${manifest.schemaVersion}.');
    }
    final ids = manifest.samples.map((sample) => sample.id).toSet();
    if (ids.length != manifest.samples.length) {
      throw const FormatException('OCR sample ids must be unique.');
    }
    return manifest;
  }
}

String normalizeOcrText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

int editDistance<T>(List<T> expected, List<T> actual) {
  if (expected.isEmpty) return actual.length;
  if (actual.isEmpty) return expected.length;

  var previous = List<int>.generate(actual.length + 1, (index) => index);
  for (var row = 1; row <= expected.length; row++) {
    final current = List<int>.filled(actual.length + 1, 0)..[0] = row;
    for (var column = 1; column <= actual.length; column++) {
      final substitution = previous[column - 1] +
          (expected[row - 1] == actual[column - 1] ? 0 : 1);
      final deletion = previous[column] + 1;
      final insertion = current[column - 1] + 1;
      current[column] = [substitution, deletion, insertion]
          .reduce((left, right) => left < right ? left : right);
    }
    previous = current;
  }
  return previous.last;
}

double _lineSubstitutionCost(String expected, String actual) {
  final expectedRunes = normalizeOcrText(expected).runes.toList();
  final actualRunes = normalizeOcrText(actual).runes.toList();
  final denominator = expectedRunes.length > actualRunes.length
      ? expectedRunes.length
      : actualRunes.length;
  if (denominator == 0) return 0;
  return editDistance(expectedRunes, actualRunes) / denominator;
}

class _LineAlignment {
  final int? expectedIndex;
  final int? actualIndex;
  final double cost;

  const _LineAlignment(this.expectedIndex, this.actualIndex, this.cost);
}

List<_LineAlignment> _alignLines(List<String> expected, List<String> actual) {
  final costs = List.generate(
    expected.length + 1,
    (_) => List<double>.filled(actual.length + 1, 0),
  );
  final moves = List.generate(
    expected.length + 1,
    (_) => List<String>.filled(actual.length + 1, ''),
  );
  for (var row = 1; row <= expected.length; row++) {
    costs[row][0] = row.toDouble();
    moves[row][0] = 'delete';
  }
  for (var column = 1; column <= actual.length; column++) {
    costs[0][column] = column.toDouble();
    moves[0][column] = 'insert';
  }

  for (var row = 1; row <= expected.length; row++) {
    for (var column = 1; column <= actual.length; column++) {
      final substitutionCost = _lineSubstitutionCost(
        expected[row - 1],
        actual[column - 1],
      );
      final substitution = costs[row - 1][column - 1] + substitutionCost;
      final deletion = costs[row - 1][column] + 1;
      final insertion = costs[row][column - 1] + 1;
      if (substitution <= deletion && substitution <= insertion) {
        costs[row][column] = substitution;
        moves[row][column] = 'substitute';
      } else if (deletion <= insertion) {
        costs[row][column] = deletion;
        moves[row][column] = 'delete';
      } else {
        costs[row][column] = insertion;
        moves[row][column] = 'insert';
      }
    }
  }

  final result = <_LineAlignment>[];
  var row = expected.length;
  var column = actual.length;
  while (row > 0 || column > 0) {
    final move = moves[row][column];
    if (move == 'substitute') {
      result.add(_LineAlignment(
        row - 1,
        column - 1,
        _lineSubstitutionCost(expected[row - 1], actual[column - 1]),
      ));
      row--;
      column--;
    } else if (move == 'delete') {
      result.add(_LineAlignment(row - 1, null, 1));
      row--;
    } else {
      result.add(_LineAlignment(null, column - 1, 1));
      column--;
    }
  }
  return result.reversed.toList(growable: false);
}

Map<String, dynamic> scoreOcrEvaluation(
  OcrEvalManifest manifest,
  Map<String, dynamic> resultDocument,
) {
  final rawSamples = resultDocument['samples'] as List<dynamic>? ?? const [];
  final resultsById = <String, Map<String, dynamic>>{
    for (final raw in rawSamples)
      (raw as Map<dynamic, dynamic>)['id'] as String:
          raw.cast<String, dynamic>(),
  };

  var totalExpectedCharacters = 0;
  var totalCharacterErrors = 0;
  var totalExpectedWords = 0;
  var totalWordErrors = 0;
  var readableLines = 0;
  var matchedReadableLines = 0;
  var exactReadableLines = 0;
  var unmatchedPredictions = 0;
  var crossedOutLines = 0;
  var detectedCrossedOutLines = 0;
  var illegibleRegions = 0;
  var totalLatencyMs = 0.0;
  var latencySamples = 0;
  final perSample = <Map<String, dynamic>>[];
  final missingSamples = <String>[];

  for (final sample in manifest.samples) {
    final result = resultsById[sample.id];
    if (result == null) {
      missingSamples.add(sample.id);
      continue;
    }
    final predictions = (result['lines'] as List<dynamic>? ?? const [])
        .map((line) => (line as Map<dynamic, dynamic>).cast<String, dynamic>())
        .toList(growable: false);
    final readable = sample.lines
        .where((line) => line.status != GroundTruthStatus.illegible)
        .toList(growable: false);
    illegibleRegions += sample.lines
        .where((line) => line.status == GroundTruthStatus.illegible)
        .length;
    final expectedTexts = readable.map((line) => line.text!).toList();
    final actualTexts = predictions
        .map((line) => line['text'] as String? ?? '')
        .toList(growable: false);
    final expectedDocument = normalizeOcrText(expectedTexts.join('\n'));
    final actualDocument = normalizeOcrText(actualTexts.join('\n'));
    final expectedCharacters = expectedDocument.runes.toList();
    final actualCharacters = actualDocument.runes.toList();
    final expectedWords =
        expectedDocument.isEmpty ? <String>[] : expectedDocument.split(' ');
    final actualWords =
        actualDocument.isEmpty ? <String>[] : actualDocument.split(' ');
    final characterErrors = editDistance(expectedCharacters, actualCharacters);
    final wordErrors = editDistance(expectedWords, actualWords);
    totalExpectedCharacters += expectedCharacters.length;
    totalCharacterErrors += characterErrors;
    totalExpectedWords += expectedWords.length;
    totalWordErrors += wordErrors;
    readableLines += readable.length;

    var sampleMatched = 0;
    var sampleExact = 0;
    var sampleExtras = 0;
    for (final alignment in _alignLines(expectedTexts, actualTexts)) {
      if (alignment.expectedIndex == null) {
        sampleExtras++;
        unmatchedPredictions++;
        continue;
      }
      final groundTruth = readable[alignment.expectedIndex!];
      if (groundTruth.status == GroundTruthStatus.crossedOut) {
        crossedOutLines++;
      }
      if (alignment.actualIndex == null || alignment.cost > 0.5) continue;
      sampleMatched++;
      matchedReadableLines++;
      if (alignment.cost == 0) {
        sampleExact++;
        exactReadableLines++;
      }
      if (groundTruth.status == GroundTruthStatus.crossedOut) {
        final predictedStatus =
            predictions[alignment.actualIndex!]['mark_status'] as String?;
        if (predictedStatus == 'crossedOut' ||
            predictedStatus == 'crossed_out') {
          detectedCrossedOutLines++;
        }
      }
    }

    final latency = (result['latency_ms'] as num?)?.toDouble();
    if (latency != null) {
      totalLatencyMs += latency;
      latencySamples++;
    }
    perSample.add({
      'id': sample.id,
      'cer': expectedCharacters.isEmpty
          ? 0
          : characterErrors / expectedCharacters.length,
      'wer': expectedWords.isEmpty ? 0 : wordErrors / expectedWords.length,
      'readable_line_recall':
          readable.isEmpty ? 0 : sampleMatched / readable.length,
      'exact_lines': sampleExact,
      'unmatched_predictions': sampleExtras,
      if (latency != null) 'latency_ms': latency,
      if (result['error'] != null) 'error': result['error'],
    });
  }

  return {
    'schema_version': 1,
    'backend': resultDocument['backend'] ?? 'unknown',
    'sample_count': manifest.samples.length,
    'evaluated_sample_count': perSample.length,
    'missing_samples': missingSamples,
    'readable_line_count': readableLines,
    'crossed_out_line_count': crossedOutLines,
    'illegible_region_count': illegibleRegions,
    'cer': totalExpectedCharacters == 0
        ? 0
        : totalCharacterErrors / totalExpectedCharacters,
    'wer': totalExpectedWords == 0 ? 0 : totalWordErrors / totalExpectedWords,
    'readable_line_recall':
        readableLines == 0 ? 0 : matchedReadableLines / readableLines,
    'exact_line_rate':
        readableLines == 0 ? 0 : exactReadableLines / readableLines,
    'crossed_out_detection_recall':
        crossedOutLines == 0 ? 0 : detectedCrossedOutLines / crossedOutLines,
    'unmatched_prediction_count': unmatchedPredictions,
    'mean_latency_ms':
        latencySamples == 0 ? null : totalLatencyMs / latencySamples,
    'notes': [
      'Accuracy is case-insensitive and punctuation-normalized.',
      'Illegible regions are excluded from CER/WER.',
      'Unmatched predictions are a conservative hallucination signal; region-level hallucination scoring requires bounding-box annotations.',
    ],
    'samples': perSample,
  };
}
