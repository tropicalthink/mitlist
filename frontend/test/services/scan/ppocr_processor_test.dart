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
}
