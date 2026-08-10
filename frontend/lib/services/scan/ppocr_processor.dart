import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Model-ready tensor plus the resized image used to produce it.
class PpOcrImageTensor {
  const PpOcrImageTensor({
    required this.data,
    required this.width,
    required this.height,
  });

  final Float32List data;
  final int width;
  final int height;
}

/// Axis-aligned text region in original-image pixels.
class PpOcrRegion {
  const PpOcrRegion({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.score,
  });

  final int left;
  final int top;
  final int right;
  final int bottom;
  final double score;

  int get width => right - left;
  int get height => bottom - top;
  double get centerY => (top + bottom) / 2;
}

class PpOcrRecognizedRegion {
  const PpOcrRecognizedRegion({
    required this.region,
    required this.text,
    required this.confidence,
    this.crossedOut = false,
    this.alternatives = const [],
  });

  final PpOcrRegion region;
  final String text;
  final double confidence;
  final bool crossedOut;
  final List<PpOcrDecodedText> alternatives;
}

class PpOcrDecodedText {
  const PpOcrDecodedText(this.text, this.confidence);

  final String text;
  final double confidence;
}

/// Portable PP-OCRv6 image transforms and post-processing.
///
/// This intentionally uses only Dart and `package:image`; Android and iOS run
/// exactly the same code. ONNX Runtime is responsible only for graph execution.
class PpOcrProcessor {
  const PpOcrProcessor({this.detectorMaxSide = 1600});

  final int detectorMaxSide;

  img.Image decode(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('Unsupported scan image.');
    return img.bakeOrientation(decoded);
  }

  /// Matches PP-OCRv6 detector preprocessing: BGR, ImageNet normalization,
  /// CHW layout, and dimensions rounded to a multiple of 32.
  PpOcrImageTensor detectorTensor(img.Image source) {
    final scale = math.min(
      1.0,
      detectorMaxSide / math.max(source.width, source.height),
    );
    final width = math.max(32, ((source.width * scale) / 32).round() * 32);
    final height = math.max(32, ((source.height * scale) / 32).round() * 32);
    final resized = width == source.width && height == source.height
        ? source
        : img.copyResize(
            source,
            width: width,
            height: height,
            interpolation: img.Interpolation.linear,
          );
    const means = [0.485, 0.456, 0.406];
    const stds = [0.229, 0.224, 0.225];
    final plane = width * height;
    final tensor = Float32List(plane * 3);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = resized.getPixel(x, y);
        final offset = y * width + x;
        final channels = [pixel.b, pixel.g, pixel.r];
        for (var channel = 0; channel < 3; channel++) {
          tensor[channel * plane + offset] =
              ((channels[channel] / 255.0) - means[channel]) / stds[channel];
        }
      }
    }
    return PpOcrImageTensor(data: tensor, width: width, height: height);
  }

  /// Portable approximation of Paddle's DB post-process.
  ///
  /// DB produces connected foreground text regions. We flood-fill those
  /// regions, reject weak components, then apply the same area/perimeter
  /// expansion principle as Paddle's `unclip` operation. Rotated components
  /// are conservatively represented by axis-aligned boxes; recognition crops
  /// receive extra vertical padding to retain ascenders and strike marks.
  List<PpOcrRegion> detectorRegions(
    List<List<double>> probability, {
    required int originalWidth,
    required int originalHeight,
    double threshold = 0.2,
    double boxThreshold = 0.45,
    double unclipRatio = 1.4,
  }) {
    if (probability.isEmpty || probability.first.isEmpty) return const [];
    final height = probability.length;
    final width = probability.first.length;
    final visited = Uint8List(width * height);
    final queue = Int32List(width * height);
    final regions = <PpOcrRegion>[];

    for (var startY = 0; startY < height; startY++) {
      for (var startX = 0; startX < width; startX++) {
        final start = startY * width + startX;
        if (visited[start] != 0 || probability[startY][startX] <= threshold) {
          continue;
        }
        var head = 0;
        var tail = 0;
        queue[tail++] = start;
        visited[start] = 1;
        var minX = startX;
        var maxX = startX;
        var minY = startY;
        var maxY = startY;
        var scoreSum = 0.0;
        var pixels = 0;

        while (head < tail) {
          final index = queue[head++];
          final y = index ~/ width;
          final x = index - y * width;
          scoreSum += probability[y][x];
          pixels++;
          minX = math.min(minX, x);
          maxX = math.max(maxX, x);
          minY = math.min(minY, y);
          maxY = math.max(maxY, y);
          for (var dy = -1; dy <= 1; dy++) {
            final nextY = y + dy;
            if (nextY < 0 || nextY >= height) continue;
            for (var dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              final nextX = x + dx;
              if (nextX < 0 || nextX >= width) continue;
              final next = nextY * width + nextX;
              if (visited[next] != 0 ||
                  probability[nextY][nextX] <= threshold) {
                continue;
              }
              visited[next] = 1;
              queue[tail++] = next;
            }
          }
        }

        final componentWidth = maxX - minX + 1;
        final componentHeight = maxY - minY + 1;
        final score = pixels == 0 ? 0.0 : scoreSum / pixels;
        if (pixels < 10 ||
            componentWidth < 3 ||
            componentHeight < 3 ||
            score < boxThreshold) {
          continue;
        }
        final area = componentWidth * componentHeight.toDouble();
        final perimeter = 2.0 * (componentWidth + componentHeight);
        final expand = math.max(2.0, area * unclipRatio / perimeter);
        final scaleX = originalWidth / width;
        final scaleY = originalHeight / height;
        final left =
            ((minX - expand) * scaleX).floor().clamp(0, originalWidth - 1);
        final top =
            ((minY - expand) * scaleY).floor().clamp(0, originalHeight - 1);
        final right = ((maxX + 1 + expand) * scaleX)
            .ceil()
            .clamp(left + 1, originalWidth);
        final bottom = ((maxY + 1 + expand) * scaleY)
            .ceil()
            .clamp(top + 1, originalHeight);
        if (right - left >= 8 && bottom - top >= 8) {
          regions.add(PpOcrRegion(
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            score: score,
          ));
        }
      }
    }
    regions.sort((a, b) {
      final row = a.centerY.compareTo(b.centerY);
      return row == 0 ? a.left.compareTo(b.left) : row;
    });
    return regions;
  }

  img.Image crop(img.Image source, PpOcrRegion region) {
    final verticalPad = math.max(2, (region.height * 0.08).round());
    final horizontalPad = math.max(2, (region.height * 0.04).round());
    final left = math.max(0, region.left - horizontalPad);
    final top = math.max(0, region.top - verticalPad);
    final right = math.min(source.width, region.right + horizontalPad);
    final bottom = math.min(source.height, region.bottom + verticalPad);
    return img.copyCrop(
      source,
      x: left,
      y: top,
      width: right - left,
      height: bottom - top,
    );
  }

  /// Matches Paddle's dynamic recognition resize: 48px high, minimum 320px
  /// tensor width, aspect-preserving content, zero padding, BGR/CHW, [-1, 1].
  PpOcrImageTensor recognitionTensor(img.Image source) {
    const height = 48;
    final contentWidth = math.max(
      1,
      math.min(3200, (height * source.width / source.height).ceil()),
    );
    final width = math.max(320, contentWidth);
    final resized = img.copyResize(
      source,
      width: contentWidth,
      height: height,
      interpolation: img.Interpolation.linear,
    );
    final plane = width * height;
    final tensor = Float32List(plane * 3);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < contentWidth; x++) {
        final pixel = resized.getPixel(x, y);
        final offset = y * width + x;
        tensor[offset] = pixel.b / 127.5 - 1.0;
        tensor[plane + offset] = pixel.g / 127.5 - 1.0;
        tensor[2 * plane + offset] = pixel.r / 127.5 - 1.0;
      }
    }
    return PpOcrImageTensor(data: tensor, width: width, height: height);
  }

  PpOcrDecodedText decodeCtc(
    List<List<double>> logits,
    List<String> characters,
  ) {
    final text = StringBuffer();
    var confidenceSum = 0.0;
    var emitted = 0;
    var previous = -1;
    for (final timestep in logits) {
      if (timestep.isEmpty) continue;
      var bestIndex = 0;
      var bestScore = timestep.first;
      for (var index = 1; index < timestep.length; index++) {
        if (timestep[index] > bestScore) {
          bestIndex = index;
          bestScore = timestep[index];
        }
      }
      if (bestIndex != 0 && bestIndex != previous) {
        if (bestIndex <= characters.length) {
          text.write(characters[bestIndex - 1]);
        } else if (bestIndex == characters.length + 1) {
          text.write(' ');
        }
        confidenceSum += bestScore;
        emitted++;
      }
      previous = bestIndex;
    }
    return PpOcrDecodedText(
      text.toString().trim(),
      emitted == 0 ? 0 : confidenceSum / emitted,
    );
  }

  /// Returns the greedy CTC result followed by distinct prefix-beam readings.
  ///
  /// PP-OCR's exported post-process is CTC. Greedy decoding discards every
  /// second-best character even when a whole-word alternative is plausible.
  /// Keeping a very small beam lets the later on-device grocery resolver use
  /// German vocabulary and household history without another model run.
  List<PpOcrDecodedText> decodeCtcCandidates(
    List<List<double>> logits,
    List<String> characters, {
    int beamWidth = 8,
    int classesPerStep = 6,
    int maxAlternatives = 5,
  }) {
    final greedy = decodeCtc(logits, characters);
    if (logits.isEmpty || beamWidth < 2 || classesPerStep < 2) {
      return [greedy];
    }

    var beams = <String, _CtcBeam>{
      '': const _CtcBeam(
          tokens: [], blank: 0, nonBlank: double.negativeInfinity),
    };
    for (final timestep in logits) {
      if (timestep.isEmpty) continue;
      final logProbabilities = _asLogProbabilities(timestep);
      final topClasses = _topClassIndices(logProbabilities, classesPerStep);
      if (!topClasses.contains(0)) topClasses.add(0);
      final next = <String, _CtcBeam>{};

      void updateBlank(_CtcBeam source, double score) {
        final key = _tokenKey(source.tokens);
        final current = next[key];
        next[key] = _CtcBeam(
          tokens: source.tokens,
          blank: _logAdd(current?.blank ?? double.negativeInfinity, score),
          nonBlank: current?.nonBlank ?? double.negativeInfinity,
        );
      }

      void updateNonBlank(List<int> tokens, double score) {
        final key = _tokenKey(tokens);
        final current = next[key];
        next[key] = _CtcBeam(
          tokens: current?.tokens ?? tokens,
          blank: current?.blank ?? double.negativeInfinity,
          nonBlank:
              _logAdd(current?.nonBlank ?? double.negativeInfinity, score),
        );
      }

      for (final beam in beams.values) {
        final total = _logAdd(beam.blank, beam.nonBlank);
        for (final classIndex in topClasses) {
          final logP = logProbabilities[classIndex];
          if (classIndex == 0) {
            updateBlank(beam, total + logP);
            continue;
          }
          final previous = beam.tokens.isEmpty ? -1 : beam.tokens.last;
          if (classIndex == previous) {
            // Repeating a class without an intervening blank stays on the same
            // CTC prefix. A repeat after blank appends another character.
            updateNonBlank(beam.tokens, beam.nonBlank + logP);
            updateNonBlank([...beam.tokens, classIndex], beam.blank + logP);
          } else {
            updateNonBlank([...beam.tokens, classIndex], total + logP);
          }
        }
      }
      final ranked = next.values.toList()
        ..sort((a, b) => b.total.compareTo(a.total));
      beams = {
        for (final beam in ranked.take(beamWidth)) _tokenKey(beam.tokens): beam,
      };
    }

    final ranked = beams.values.where((beam) => beam.tokens.isNotEmpty).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    if (ranked.isEmpty) return [greedy];
    final strongest = ranked.first.total;
    final results = <PpOcrDecodedText>[greedy];
    final seen = <String>{greedy.text};
    for (final beam in ranked) {
      final text = _decodeTokens(beam.tokens, characters).trim();
      if (text.isEmpty || !seen.add(text)) continue;
      results.add(PpOcrDecodedText(text, math.exp(beam.total - strongest)));
      if (results.length > maxAlternatives) break;
    }
    return results;
  }

  /// Joins fragments occupying the same visual row. This recovered split
  /// phrases such as `Olive | oil` and reduced unmatched sample predictions
  /// from nine to two in the six-image benchmark.
  List<PpOcrRecognizedRegion> mergeLineFragments(
    List<PpOcrRecognizedRegion> input,
  ) {
    final pending = input.where((line) => line.text.trim().isNotEmpty).toList()
      ..sort((a, b) {
        final row = a.region.centerY.compareTo(b.region.centerY);
        return row == 0 ? a.region.left.compareTo(b.region.left) : row;
      });
    final groups = <List<PpOcrRecognizedRegion>>[];
    for (final line in pending) {
      List<PpOcrRecognizedRegion>? target;
      for (final group in groups.reversed) {
        final center = group
                .map((item) => item.region.centerY * item.region.width)
                .reduce((a, b) => a + b) /
            group.map((item) => item.region.width).reduce((a, b) => a + b);
        final minHeight = group
            .map((item) => item.region.height)
            .fold(line.region.height, math.min);
        if ((line.region.centerY - center).abs() <= minHeight * 0.65) {
          target = group;
          break;
        }
      }
      (target ?? (groups..add(<PpOcrRecognizedRegion>[])).last).add(line);
    }

    final merged = <PpOcrRecognizedRegion>[];
    for (final group in groups) {
      group.sort((a, b) => a.region.left.compareTo(b.region.left));
      final left = group.map((e) => e.region.left).reduce(math.min);
      final top = group.map((e) => e.region.top).reduce(math.min);
      final right = group.map((e) => e.region.right).reduce(math.max);
      final bottom = group.map((e) => e.region.bottom).reduce(math.max);
      final joined = group
          .map((e) => e.text.trim())
          .join(' ')
          .replaceAll(RegExp(r'-\s+'), '-')
          .trim();
      merged.add(PpOcrRecognizedRegion(
        region: PpOcrRegion(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          score: group.map((e) => e.region.score).reduce(math.min),
        ),
        text: joined,
        confidence: group.map((e) => e.confidence).reduce(math.min),
        crossedOut: group.any((e) => e.crossedOut),
        alternatives: _mergeAlternatives(group, joined),
      ));
    }
    merged.sort((a, b) => a.region.centerY.compareTo(b.region.centerY));
    return merged;
  }

  List<PpOcrDecodedText> _mergeAlternatives(
    List<PpOcrRecognizedRegion> group,
    String primary,
  ) {
    var combinations = <PpOcrDecodedText>[const PpOcrDecodedText('', 1)];
    for (final region in group) {
      final choices = <PpOcrDecodedText>[
        PpOcrDecodedText(region.text, 1),
        ...region.alternatives,
      ];
      final next = <PpOcrDecodedText>[];
      for (final prefix in combinations) {
        for (final choice in choices) {
          final text = '${prefix.text} ${choice.text}'
              .trim()
              .replaceAll(RegExp(r'-\s+'), '-');
          next.add(PpOcrDecodedText(
            text,
            prefix.confidence * choice.confidence,
          ));
        }
      }
      next.sort((a, b) => b.confidence.compareTo(a.confidence));
      final seen = <String>{};
      combinations = [
        for (final candidate in next)
          if (seen.add(candidate.text)) candidate,
      ].take(8).toList();
    }
    return combinations
        .where((candidate) => candidate.text != primary)
        .take(5)
        .toList(growable: false);
  }

  /// Conservative, portable strikethrough signal based on a long dark stroke
  /// through the middle half of a recognized line crop.
  bool hasStrikethrough(img.Image crop) {
    if (crop.width < 24 || crop.height < 12) return false;
    final gray = img.grayscale(crop);
    var mean = 0.0;
    for (final pixel in gray) {
      mean += pixel.r;
    }
    mean /= gray.width * gray.height;
    final darkThreshold = math.min(160.0, mean - 35.0);
    if (darkThreshold < 40) return false;
    final startY = (gray.height * 0.25).floor();
    final endY = (gray.height * 0.75).ceil();
    var strongestCoverage = 0.0;
    for (var y = startY; y < endY; y++) {
      var dark = 0;
      for (var x = 0; x < gray.width; x++) {
        if (gray.getPixel(x, y).r < darkThreshold) dark++;
      }
      strongestCoverage = math.max(strongestCoverage, dark / gray.width);
    }
    if (strongestCoverage >= 0.42) return true;

    // A handwritten strike is commonly diagonal, which spreads its pixels
    // across several raster rows and defeats the horizontal projection above.
    // Sample shallow virtual lines through the crop and require continuous ink
    // across most of the width. Ordinary cursive can be dense, but it does not
    // stay aligned to one straight path for that distance.
    final radius = math.max(1, (gray.height * 0.015).round());
    final sampleCount = (gray.width + 1) ~/ 2;
    for (var riseStep = -4; riseStep <= 4; riseStep++) {
      final totalRise = gray.height * riseStep * 0.075;
      for (var centerY = startY; centerY < endY; centerY += 2) {
        var dark = 0;
        for (var x = 0; x < gray.width; x += 2) {
          final progress = gray.width <= 1 ? 0.0 : x / (gray.width - 1) - 0.5;
          final y = (centerY + totalRise * progress).round();
          var hit = false;
          for (var dy = -radius; dy <= radius; dy++) {
            final sampleY = y + dy;
            if (sampleY >= 0 &&
                sampleY < gray.height &&
                gray.getPixel(x, sampleY).r < darkThreshold) {
              hit = true;
              break;
            }
          }
          if (hit) dark++;
        }
        if (dark / sampleCount >= 0.62) return true;
      }
    }
    return false;
  }
}

class _CtcBeam {
  const _CtcBeam({
    required this.tokens,
    required this.blank,
    required this.nonBlank,
  });

  final List<int> tokens;
  final double blank;
  final double nonBlank;
  double get total => _logAdd(blank, nonBlank);
}

double _logAdd(double a, double b) {
  if (a == double.negativeInfinity) return b;
  if (b == double.negativeInfinity) return a;
  final larger = math.max(a, b);
  return larger + math.log(math.exp(a - larger) + math.exp(b - larger));
}

String _tokenKey(List<int> tokens) => tokens.join(',');

List<double> _asLogProbabilities(List<double> values) {
  final sum = values.fold<double>(0, (total, value) => total + value);
  final probabilities = values.every((value) => value >= 0 && value <= 1) &&
      sum >= 0.8 &&
      sum <= 1.2;
  if (probabilities) {
    return values.map((value) => math.log(math.max(value, 1e-30))).toList();
  }
  final maximum = values.reduce(math.max);
  final denominator = values.fold<double>(
      0, (total, value) => total + math.exp(value - maximum));
  final logDenominator = maximum + math.log(denominator);
  return values.map((value) => value - logDenominator).toList();
}

List<int> _topClassIndices(List<double> values, int count) {
  final indices = <int>[];
  for (var index = 0; index < values.length; index++) {
    var insertAt = 0;
    while (insertAt < indices.length &&
        values[indices[insertAt]] >= values[index]) {
      insertAt++;
    }
    if (insertAt < count) {
      indices.insert(insertAt, index);
      if (indices.length > count) indices.removeLast();
    }
  }
  return indices;
}

String _decodeTokens(List<int> tokens, List<String> characters) {
  final text = StringBuffer();
  for (final index in tokens) {
    if (index > 0 && index <= characters.length) {
      text.write(characters[index - 1]);
    } else if (index == characters.length + 1) {
      text.write(' ');
    }
  }
  return text.toString();
}
