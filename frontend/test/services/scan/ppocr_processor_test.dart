import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mitlist/services/scan/ppocr_processor.dart';

void main() {
  const processor = PpOcrProcessor();

  test('detector tensor is BGR CHW with ImageNet normalization', () {
    final image = img.Image(width: 64, height: 32)
      ..clear(img.ColorRgb8(255, 0, 0));

    final tensor = processor.detectorTensor(image);

    expect(tensor.width, 64);
    expect(tensor.height, 32);
    final plane = tensor.width * tensor.height;
    expect(tensor.data[0], closeTo((0 - 0.485) / 0.229, 1e-5));
    expect(tensor.data[plane], closeTo((0 - 0.456) / 0.224, 1e-5));
    expect(tensor.data[2 * plane], closeTo((1 - 0.406) / 0.225, 1e-5));
  });

  test('recognition tensor preserves aspect ratio and zero pads to 320', () {
    final image = img.Image(width: 96, height: 48)
      ..clear(img.ColorRgb8(255, 255, 255));

    final tensor = processor.recognitionTensor(image);

    expect(tensor.width, 320);
    expect(tensor.height, 48);
    expect(tensor.data.first, closeTo(1, 1e-5));
    expect(tensor.data[95], closeTo(1, 1e-5));
    expect(tensor.data[96], 0);
  });

  test('DB post-process returns expanded original-coordinate components', () {
    final probability = List.generate(
      10,
      (y) => List.generate(
        20,
        (x) => x >= 3 && x <= 11 && y >= 2 && y <= 6 ? 0.9 : 0.0,
      ),
    );

    final regions = processor.detectorRegions(
      probability,
      originalWidth: 200,
      originalHeight: 100,
    );

    expect(regions, hasLength(1));
    expect(regions.single.left, lessThan(30));
    expect(regions.single.right, greaterThan(120));
    expect(regions.single.top, lessThan(20));
    expect(regions.single.bottom, greaterThan(70));
    expect(regions.single.score, closeTo(0.9, 1e-5));
  });

  test('CTC decoder removes blanks and repeated classes and supports spaces',
      () {
    List<double> classAt(int index) => [
          for (var i = 0; i < 4; i++) i == index ? 0.95 : 0.01,
        ];

    final decoded = processor.decodeCtc(
      [classAt(1), classAt(1), classAt(0), classAt(2), classAt(3), classAt(1)],
      ['a', 'b'],
    );

    expect(decoded.text, 'ab a');
    expect(decoded.confidence, closeTo(0.95, 1e-5));
  });

  test('CTC beam keeps a plausible non-greedy whole-word alternative', () {
    List<double> probabilities(double a, double b) => [0.05, a, b];

    final candidates = processor.decodeCtcCandidates(
      [
        probabilities(0.55, 0.40),
        probabilities(0.05, 0.90),
      ],
      ['a', 'b'],
      beamWidth: 6,
      classesPerStep: 3,
    );

    expect(candidates.first.text, 'ab');
    expect(candidates.map((candidate) => candidate.text), contains('b'));
    expect(
      candidates.skip(1).every(
            (candidate) =>
                candidate.confidence >= 0 && candidate.confidence <= 1,
          ),
      isTrue,
    );
  });

  test('line merger joins same-row fragments in left-to-right order', () {
    const right = PpOcrRecognizedRegion(
      region: PpOcrRegion(
        left: 90,
        top: 12,
        right: 150,
        bottom: 42,
        score: 0.9,
      ),
      text: 'oil',
      confidence: 0.8,
    );
    const left = PpOcrRecognizedRegion(
      region: PpOcrRegion(
        left: 10,
        top: 10,
        right: 80,
        bottom: 40,
        score: 0.95,
      ),
      text: 'Olive',
      confidence: 0.9,
    );

    final merged = processor.mergeLineFragments([right, left]);

    expect(merged, hasLength(1));
    expect(merged.single.text, 'Olive oil');
    expect(merged.single.confidence, 0.8);
    expect(merged.single.region.left, 10);
    expect(merged.single.region.right, 150);
  });

  test('strikethrough detector requires a long middle stroke', () {
    final crossed = img.Image(width: 120, height: 32)
      ..clear(img.ColorRgb8(255, 255, 255));
    for (var x = 4; x < 116; x++) {
      crossed.setPixelRgb(x, 16, 0, 0, 0);
      crossed.setPixelRgb(x, 17, 0, 0, 0);
    }
    final diagonal = img.Image(width: 120, height: 32)
      ..clear(img.ColorRgb8(255, 255, 255));
    for (var x = 4; x < 116; x++) {
      final y = 12 + ((x - 4) * 7 / 112).round();
      diagonal.setPixelRgb(x, y, 0, 0, 0);
      diagonal.setPixelRgb(x, y + 1, 0, 0, 0);
    }
    final plain = img.Image(width: 120, height: 32)
      ..clear(img.ColorRgb8(255, 255, 255));
    for (var y = 5; y < 28; y++) {
      plain.setPixelRgb(30, y, 0, 0, 0);
      plain.setPixelRgb(70, y, 0, 0, 0);
    }

    expect(processor.hasStrikethrough(crossed), isTrue);
    expect(processor.hasStrikethrough(diagonal), isTrue);
    expect(processor.hasStrikethrough(plain), isFalse);
  });

  group('lexicon decoding', () {
    // Classes: 0 blank, then the characters below; a final space class.
    const chars = ['a', 'b', 'c', 'i', 'r', 'e', 'f'];
    final allowed =
        Int32List.fromList([for (var i = 0; i <= chars.length + 1; i++) i]);
    final positions = PpOcrProcessor.positionsByCharacter(chars, allowed);

    /// Evidence whose most likely reading at each step is [peaks] (one
    /// character per step, '_' for blank), with [peak] probability.
    PpOcrLineEvidence evidence(List<String> peaks, {double peak = 0.9}) {
      final classes = allowed.length;
      return PpOcrLineEvidence([
        for (final p in peaks)
          Float64List.fromList([
            for (var c = 0; c < classes; c++)
              math.log(c == (p == '_' ? 0 : positions[p]!)
                  ? peak
                  : (1 - peak) / (classes - 1)),
          ]),
      ]);
    }

    test('forward likelihood matches the sum over every alignment', () {
      final ev = evidence(['a', '_', 'b'], peak: 0.6);
      // Brute force: every class sequence of length 3 that collapses to "ab".
      var total = 0.0;
      final classes = allowed.length;
      for (var x = 0; x < classes; x++) {
        for (var y = 0; y < classes; y++) {
          for (var z = 0; z < classes; z++) {
            final seq = [x, y, z];
            final collapsed = <int>[];
            int? previous;
            for (final c in seq) {
              if (c != previous && c != 0) collapsed.add(c);
              previous = c;
            }
            if (collapsed.length == 2 &&
                collapsed[0] == positions['a'] &&
                collapsed[1] == positions['b']) {
              total += math.exp(ev.logProbabilities[0][x] +
                  ev.logProbabilities[1][y] +
                  ev.logProbabilities[2][z]);
            }
          }
        }
      }
      expect(PpOcrProcessor.ctcLogLikelihood(ev, 'ab', positions),
          closeTo(math.log(total), 1e-9));
      expect(
          PpOcrProcessor.ctcLogLikelihood(ev, 'abc', positions) <
              PpOcrProcessor.ctcLogLikelihood(ev, 'ab', positions),
          isTrue);
      expect(PpOcrProcessor.ctcLogLikelihood(ev, 'aQ', positions),
          double.negativeInfinity);
    });

    test('a household word the pixels support replaces a misread', () {
      // Read as "fice"; the first stroke is ambiguous between f and r.
      final ev = PpOcrLineEvidence([
        Float64List.fromList([
          for (var c = 0; c < allowed.length; c++)
            math.log(c == positions['f']
                ? 0.55
                : c == positions['r']
                    ? 0.4
                    : 0.05 / 7),
        ]),
        ...evidence(['i', 'c', 'e']).logProbabilities,
      ]);
      final chosen = PpOcrProcessor.decodeLineWithLexicon(
        [ev],
        ['fice'],
        const [OcrLexiconEntry('rice', -2)],
        positions,
        rawLogPrior: -12,
      );
      expect(chosen, ['rice']);
    });

    test('a word the pixels do not show is never forced', () {
      final chosen = PpOcrProcessor.decodeLineWithLexicon(
        [
          evidence(['b', 'a', 'c', 'e'])
        ],
        ['bace'],
        const [OcrLexiconEntry('rice', 0)],
        positions,
        rawLogPrior: -40,
      );
      expect(chosen, isNull);
    });

    test('an item can span the fragments of one line', () {
      final chosen = PpOcrProcessor.decodeLineWithLexicon(
        [
          evidence(['a', 'b', 'e']),
          evidence(['c', 'a', 'r', 'e'])
        ],
        ['abe', 'care'],
        const [OcrLexiconEntry('abe care', -1)],
        positions,
        rawLogPrior: -15,
      );
      expect(chosen, ['abe', 'care']);
    });
  });

  group('photo geometry', () {
    const processor = PpOcrProcessor();

    /// A detector map with three text lines slanted by [degrees].
    List<List<double>> slantedLines(double degrees) {
      const w = 400, h = 300;
      final map = List.generate(h, (_) => List<double>.filled(w, 0));
      final t = math.tan(degrees * math.pi / 180);
      for (final baseline in [80, 150, 220]) {
        for (var x = 60; x < 340; x++) {
          final y = (baseline + (x - 200) * t).round();
          for (var dy = -3; dy <= 3; dy++) {
            if (y + dy >= 0 && y + dy < h) map[y + dy][x] = 0.9;
          }
        }
      }
      return map;
    }

    test('reads the slant of the lines', () {
      for (final degrees in [-12.0, -4.0, 0.0, 7.0, 15.0]) {
        expect(processor.estimateSkewDegrees(slantedLines(degrees)),
            closeTo(degrees, 1.0));
      }
    });

    test('rotating by minus the slant levels the lines', () {
      // A dark line slanted by 10 degrees on a white page.
      final page = img.Image(width: 400, height: 300)
        ..clear(img.ColorRgb8(255, 255, 255));
      final t = math.tan(10 * math.pi / 180);
      for (var x = 60; x < 340; x++) {
        final y = (150 + (x - 200) * t).round();
        for (var dy = -3; dy <= 3; dy++) {
          page.setPixelRgb(x, y + dy, 0, 0, 0);
        }
      }
      final level = processor.rotate(page, -10);
      final map = [
        for (var y = 0; y < level.height; y++)
          [
            for (var x = 0; x < level.width; x++)
              level.getPixel(x, y).r < 128 ? 0.9 : 0.0,
          ],
      ];
      expect(processor.estimateSkewDegrees([...map, ...map, ...map]).abs(),
          lessThan(1.0));
      // The corners the rotation exposes are white, not black ink.
      expect(level.getPixel(0, 0).r, greaterThan(200));
    });

    test('boxes map back onto the original photo', () {
      final page = img.Image(width: 800, height: 600);
      final rotated = processor.rotate(page, -10);
      final geometry = PpOcrGeometry(
        originalWidth: 800,
        originalHeight: 600,
        scale: 1,
        rotationDegrees: -10,
        rotatedWidth: rotated.width,
        rotatedHeight: rotated.height,
      );
      // The rotated canvas centre is the photo centre.
      final centre = geometry.mapBack(PpOcrRegion(
        left: rotated.width ~/ 2 - 1,
        top: rotated.height ~/ 2 - 1,
        right: rotated.width ~/ 2 + 1,
        bottom: rotated.height ~/ 2 + 1,
        score: 1,
      ));
      expect(centre.left, inInclusiveRange(397, 401));
      expect(centre.top, inInclusiveRange(297, 301));
      final scaled = const PpOcrGeometry(
              originalWidth: 400, originalHeight: 300, scale: 4)
          .mapBack(const PpOcrRegion(
              left: 400, top: 400, right: 800, bottom: 480, score: 1));
      expect([scaled.left, scaled.top, scaled.right, scaled.bottom],
          [100, 100, 200, 120]);
    });

    test('small photos are enlarged, large ones left alone', () {
      final small = processor.normalizeScale(img.Image(width: 350, height: 300));
      expect(small.width, 1600);
      final large = img.Image(width: 1600, height: 1200);
      expect(identical(processor.normalizeScale(large), large), isTrue);
    });

    test('a wide gap inside a row splits columns', () {
      PpOcrRecognizedRegion at(int left, int right, String text) =>
          PpOcrRecognizedRegion(
            region: PpOcrRegion(
                left: left, top: 100, right: right, bottom: 140, score: 1),
            text: text,
            confidence: 1,
          );
      final groups = processor.lineGroups([
        at(10, 120, '1 Bund'),
        at(135, 300, 'Basilikum'),
        at(600, 700, 'PENNY'),
      ]);
      expect(groups.map((g) => g.map((r) => r.text).join(' ')),
          ['1 Bund Basilikum', 'PENNY']);
    });
  });
}
