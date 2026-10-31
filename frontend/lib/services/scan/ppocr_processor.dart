import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'resolution/string_sim.dart';

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

/// One reading the lexicon decoder may choose for a line, with the prior
/// belief (natural log) that this household wrote it.
class OcrLexiconEntry {
  const OcrLexiconEntry(this.text, this.logPrior);

  final String text;
  final double logPrior;
}

/// A recognised region's evidence in the form the lexicon decoder scores:
/// per-timestep log-probabilities over the decodable (Latin) classes,
/// renormalised over them. Index 0 is the CTC blank.
class PpOcrLineEvidence {
  const PpOcrLineEvidence(this.logProbabilities);

  final List<Float64List> logProbabilities;
}

/// How the photo was enlarged and straightened before reading, so boxes can
/// be mapped back onto the photo the caller holds (training crops, review).
class PpOcrGeometry {
  const PpOcrGeometry({
    required this.originalWidth,
    required this.originalHeight,
    this.scale = 1,
    this.rotationDegrees = 0,
    this.rotatedWidth = 0,
    this.rotatedHeight = 0,
  });

  final int originalWidth;
  final int originalHeight;

  /// Enlargement applied first (1 = none).
  final double scale;

  /// Rotation applied after scaling (0 = none), as passed to img.copyRotate.
  final double rotationDegrees;
  final int rotatedWidth;
  final int rotatedHeight;

  /// The axis-aligned box on the original photo covering [region].
  PpOcrRegion mapBack(PpOcrRegion region) {
    var xs = <double>[region.left.toDouble(), region.right.toDouble()];
    var ys = <double>[region.top.toDouble(), region.bottom.toDouble()];
    var corners = <(double, double)>[
      for (final x in xs)
        for (final y in ys) (x, y),
    ];
    if (rotationDegrees != 0) {
      // Inverse of img.copyRotate: destination (x, y) samples the scaled
      // source at (w2 + X cos a + Y sin a, h2 - X sin a + Y cos a).
      final radians = rotationDegrees * math.pi / 180;
      final ca = math.cos(radians);
      final sa = math.sin(radians);
      final w2 = 0.5 * originalWidth * scale;
      final h2 = 0.5 * originalHeight * scale;
      final dw2 = 0.5 * rotatedWidth;
      final dh2 = 0.5 * rotatedHeight;
      corners = [
        for (final (x, y) in corners)
          (
            w2 + (x - dw2) * ca + (y - dh2) * sa,
            h2 - (x - dw2) * sa + (y - dh2) * ca,
          ),
      ];
    }
    xs = [for (final (x, _) in corners) x / scale];
    ys = [for (final (_, y) in corners) y / scale];
    final left = xs.reduce(math.min).floor().clamp(0, originalWidth - 1);
    final top = ys.reduce(math.min).floor().clamp(0, originalHeight - 1);
    return PpOcrRegion(
      left: left,
      top: top,
      right: xs.reduce(math.max).ceil().clamp(left + 1, originalWidth),
      bottom: ys.reduce(math.max).ceil().clamp(top + 1, originalHeight),
      score: region.score,
    );
  }
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

  /// Enlarges a small photo (a thumbnail, a cropped screenshot) so its
  /// handwriting reaches the recognizer at a readable height. Photos already
  /// [minLongSide] or larger are returned unchanged.
  img.Image normalizeScale(
    img.Image source, {
    int minLongSide = 1200,
    int targetLongSide = 1600,
  }) {
    final longSide = math.max(source.width, source.height);
    if (longSide >= minLongSide || longSide == 0) return source;
    final scale = targetLongSide / longSide;
    return img.copyResize(
      source,
      width: (source.width * scale).round(),
      height: (source.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
  }

  /// The dominant slant of the text lines in degrees (positive: lines run
  /// down to the right), from the elongated components of the detector map.
  /// Returns 0 when there are too few lines to tell.
  double estimateSkewDegrees(
    List<List<double>> probability, {
    double threshold = 0.2,
  }) {
    if (probability.isEmpty || probability.first.isEmpty) return 0;
    final height = probability.length;
    final width = probability.first.length;
    final visited = Uint8List(width * height);
    final queue = Int32List(width * height);
    final angles = <(double, int)>[];
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
        var n = 0;
        var sx = 0.0, sy = 0.0, sxx = 0.0, syy = 0.0, sxy = 0.0;
        while (head < tail) {
          final index = queue[head++];
          final y = index ~/ width;
          final x = index - y * width;
          n++;
          sx += x;
          sy += y;
          sxx += x * x;
          syy += y * y;
          sxy += x * y;
          for (var dy = -1; dy <= 1; dy++) {
            final nextY = y + dy;
            if (nextY < 0 || nextY >= height) continue;
            for (var dx = -1; dx <= 1; dx++) {
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
        if (n < 40) continue;
        final mx = sx / n, my = sy / n;
        final cxx = sxx / n - mx * mx;
        final cyy = syy / n - my * my;
        final cxy = sxy / n - mx * my;
        final spread = math.sqrt((cxx - cyy) * (cxx - cyy) + 4 * cxy * cxy);
        final major = (cxx + cyy + spread) / 2;
        final minor = (cxx + cyy - spread) / 2;
        // Only clearly line-shaped blobs (about 3:1 or longer) say anything
        // about the slant; dots and single letters do not.
        if (minor <= 0 || major / minor < 9) continue;
        final angle = 0.5 * math.atan2(2 * cxy, cxx - cyy) * 180 / math.pi;
        if (angle.abs() > 45) continue;
        angles.add((angle, n));
      }
    }
    if (angles.length < 3) return 0;
    angles.sort((a, b) => a.$1.compareTo(b.$1));
    final total = angles.fold<int>(0, (sum, a) => sum + a.$2);
    var running = 0;
    for (final (angle, weight) in angles) {
      running += weight;
      if (running * 2 >= total) return angle;
    }
    return angles.last.$1;
  }

  /// Rotates [source] by [degrees] (as img.copyRotate), filling the exposed
  /// corners with white so the detector does not read them as ink.
  img.Image rotate(img.Image source, double degrees) {
    final copy = img.Image.from(source)
      ..backgroundColor = img.ColorRgb8(255, 255, 255);
    return img.copyRotate(
      copy,
      angle: degrees,
      interpolation: img.Interpolation.linear,
    );
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

  /// The recognizer classes worth decoding for grocery lists: the CTC blank,
  /// the space class, and every Latin-script character. The bundled dictionary
  /// holds 18,708 classes, 18,208 of them CJK and other scripts, which a
  /// German/English/French/Spanish list never contains. Restricting decoding to
  /// this set removes impossible glyphs and makes each timestep ~37× cheaper.
  static Int32List latinClasses(List<String> characters) {
    final allowed = <int>[0];
    for (var i = 0; i < characters.length; i++) {
      if (_isLatinCharacter(characters[i])) allowed.add(i + 1);
    }
    allowed.add(characters.length + 1);
    return Int32List.fromList(allowed);
  }

  static bool _isLatinCharacter(String character) {
    if (character.runes.length != 1) return false;
    final c = character.runes.single;
    return (c >= 0x20 && c <= 0x7E) || // ASCII
        (c >= 0xA0 && c <= 0x24F) || // Latin-1, Extended-A/B (ß ä é ñ œ ½ ×)
        (c >= 0x1E00 && c <= 0x1EFF) || // Latin Extended Additional
        (c >= 0x2010 && c <= 0x2027) || // dashes, quotes, bullets
        c == 0x20AC; // €
  }

  PpOcrDecodedText decodeCtc(
    List<List<double>> logits,
    List<String> characters, {
    Int32List? allowedClasses,
  }) {
    final text = StringBuffer();
    var confidenceSum = 0.0;
    var emitted = 0;
    var previous = -1;
    for (final timestep in logits) {
      if (timestep.isEmpty) continue;
      var bestIndex = 0;
      var bestScore = timestep.first;
      if (allowedClasses == null) {
        for (var index = 1; index < timestep.length; index++) {
          if (timestep[index] > bestScore) {
            bestIndex = index;
            bestScore = timestep[index];
          }
        }
      } else {
        for (final index in allowedClasses) {
          if (index < timestep.length && timestep[index] > bestScore) {
            bestIndex = index;
            bestScore = timestep[index];
          }
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
    Int32List? allowedClasses,
  }) {
    final greedy =
        decodeCtc(logits, characters, allowedClasses: allowedClasses);
    if (logits.isEmpty || beamWidth < 2 || classesPerStep < 2) {
      return [greedy];
    }
    // Whether the graph emits probabilities or raw logits is a property of
    // the model, so decide once rather than per timestep.
    final firstStep = logits.firstWhere((step) => step.isNotEmpty,
        orElse: () => const <double>[]);
    final emitsProbabilities = _looksLikeProbabilities(firstStep);

    var beams = <String, _CtcBeam>{
      '': const _CtcBeam(
          tokens: [], blank: 0, nonBlank: double.negativeInfinity),
    };
    for (final timestep in logits) {
      if (timestep.isEmpty) continue;
      // Work on the allowed classes only; `classOf` maps a position in that
      // compact view back to the model's class index.
      final values = allowedClasses == null
          ? timestep
          : [
              for (final index in allowedClasses)
                if (index < timestep.length) timestep[index],
            ];
      int classOf(int position) =>
          allowedClasses == null ? position : allowedClasses[position];
      final logProbabilities = _asLogProbabilities(values, emitsProbabilities);
      final topPositions = _topClassIndices(logProbabilities, classesPerStep);
      // Position 0 is the blank in both views.
      if (!topPositions.contains(0)) topPositions.add(0);
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
        for (final position in topPositions) {
          final logP = logProbabilities[position];
          final classIndex = classOf(position);
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

  /// Per-timestep log-probabilities over [allowedClasses] (position 0 is the
  /// blank), renormalised over that set. The lexicon decoder scores every
  /// candidate against the same evidence, so their likelihoods compare.
  PpOcrLineEvidence lineEvidence(
    List<List<double>> logits,
    Int32List allowedClasses,
  ) {
    final firstStep = logits.firstWhere((step) => step.isNotEmpty,
        orElse: () => const <double>[]);
    final emitsProbabilities = _looksLikeProbabilities(firstStep);
    final steps = <Float64List>[];
    for (final timestep in logits) {
      if (timestep.isEmpty) continue;
      final values = [
        for (final index in allowedClasses)
          index < timestep.length ? timestep[index] : 0.0,
      ];
      steps.add(Float64List.fromList(
          _asLogProbabilities(values, emitsProbabilities)));
    }
    return PpOcrLineEvidence(steps);
  }

  /// Maps each decodable character to its position in [allowedClasses].
  static Map<String, int> positionsByCharacter(
    List<String> characters,
    Int32List allowedClasses,
  ) {
    final result = <String, int>{};
    for (var position = 1; position < allowedClasses.length; position++) {
      final classIndex = allowedClasses[position];
      if (classIndex == characters.length + 1) {
        result[' '] = position;
      } else if (classIndex >= 1 && classIndex <= characters.length) {
        result[characters[classIndex - 1]] = position;
      }
    }
    return result;
  }

  /// log P(evidence | text): the CTC forward algorithm summed over every
  /// alignment of [text], not just the single best path. Returns -infinity
  /// when a character cannot be decoded or the line is too short for it.
  static double ctcLogLikelihood(
    PpOcrLineEvidence evidence,
    String text,
    Map<String, int> positionsByCharacter,
  ) {
    final labels = <int>[];
    for (final rune in text.runes) {
      final position = positionsByCharacter[String.fromCharCode(rune)];
      if (position == null) return double.negativeInfinity;
      labels.add(position);
    }
    final steps = evidence.logProbabilities;
    if (labels.isEmpty || steps.isEmpty) return double.negativeInfinity;
    // Extended label sequence: blank, l1, blank, l2, ..., blank.
    final extended = Int32List(labels.length * 2 + 1);
    for (var i = 0; i < labels.length; i++) {
      extended[2 * i + 1] = labels[i];
    }
    final width = extended.length;
    var alpha = Float64List(width)
      ..fillRange(0, width, double.negativeInfinity);
    alpha[0] = steps[0][extended[0]];
    alpha[1] = steps[0][extended[1]];
    var next = Float64List(width);
    for (var t = 1; t < steps.length; t++) {
      final step = steps[t];
      for (var s = 0; s < width; s++) {
        var total = alpha[s];
        if (s >= 1) total = _logAdd(total, alpha[s - 1]);
        if (s >= 2 && extended[s] != 0 && extended[s] != extended[s - 2]) {
          total = _logAdd(total, alpha[s - 2]);
        }
        next[s] = total == double.negativeInfinity
            ? double.negativeInfinity
            : total + step[extended[s]];
      }
      final swap = alpha;
      alpha = next;
      next = swap;
    }
    return _logAdd(alpha[width - 1], alpha[width - 2]);
  }

  /// Chooses between the recognizer's own reading and [lexicon] words by
  /// posterior: visual likelihood (CTC forward) plus prior. The raw reading
  /// always competes with prior [rawLogPrior], so a word the household has
  /// never written ("Yildiz sauce") is kept as read, never forced onto the
  /// nearest known word. Returns the winner first, with its posterior over
  /// everything scored as the confidence.
  static List<PpOcrDecodedText> decodeWithLexicon(
    PpOcrLineEvidence evidence,
    String rawText,
    Iterable<OcrLexiconEntry> lexicon,
    Map<String, int> positionsByCharacter, {
    double rawLogPrior = -2.3,
  }) {
    final scored = <String, double>{};
    void consider(String text, double logPrior) {
      final likelihood = ctcLogLikelihood(evidence, text, positionsByCharacter);
      if (likelihood == double.negativeInfinity) return;
      final score = likelihood + logPrior;
      final previous = scored[text];
      if (previous == null || score > previous) scored[text] = score;
    }

    if (rawText.isNotEmpty) consider(rawText, rawLogPrior);
    for (final entry in lexicon) {
      // Handwriting capitalises freely; the prior belongs to the word.
      for (final form in _caseForms(entry.text)) {
        consider(form, entry.logPrior);
      }
    }
    if (scored.isEmpty) return [PpOcrDecodedText(rawText, 0)];
    final ranked = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    var normaliser = double.negativeInfinity;
    for (final entry in ranked) {
      normaliser = _logAdd(normaliser, entry.value);
    }
    return [
      for (final entry in ranked.take(6))
        PpOcrDecodedText(entry.key, math.exp(entry.value - normaliser)),
    ];
  }

  /// Bullet marks a list line may begin with. They are scored as part of the
  /// reading so "-chicken thight" can still be "- chicken thighs"; extraction
  /// strips them afterwards.
  static const List<String> kLineBullets = ['', '-', '- ', '• ', '* '];

  /// Lexicon decoding for one visual line made of [parts] (fragments left to
  /// right) with raw readings [rawParts]. A multi-word entry may span the
  /// fragments, split between words in order ("dunklen | Balsamico-essig").
  /// Returns the chosen text for each fragment, or null to keep the raw
  /// readings.
  static List<String>? decodeLineWithLexicon(
    List<PpOcrLineEvidence> parts,
    List<String> rawParts,
    Iterable<OcrLexiconEntry> lexicon,
    Map<String, int> positionsByCharacter, {
    required double rawLogPrior,
    double maxVisualGapPerCharacter = kMaxVisualGapPerCharacter,
  }) {
    if (parts.isEmpty || parts.length != rawParts.length) return null;
    var rawLikelihood = 0.0;
    for (var i = 0; i < parts.length; i++) {
      rawLikelihood +=
          ctcLogLikelihood(parts[i], rawParts[i], positionsByCharacter);
    }
    final rawScore = rawLogPrior + rawLikelihood;
    // A word may only replace the reading if it explains the image nearly as
    // well. Priors decide between words the pixels support; they never make
    // the decoder see a word the pixels do not show ("Yildiz sauce" is not
    // "Hoisin sauce", however often the household buys hoisin).
    final rawLength = rawParts.fold<int>(0, (sum, part) => sum + part.length);
    final rawBare = _bare(rawParts.join(' '));
    final likelihoodFloor =
        rawLikelihood - maxVisualGapPerCharacter * math.max(1, rawLength);
    var bestScore = rawScore;
    List<String>? best;
    for (final entry in lexicon) {
      // Cheap reject: a reading far off in length can never pass the visual
      // floor, and the CTC forward pass is the expensive part.
      final length = entry.text.length;
      if ((length - rawLength).abs() > math.max(4, rawLength * 0.6)) continue;
      for (final form in _caseForms(entry.text)) {
        // Fragments also break inside hyphenated words ("Balsamico-|essig").
        final words = form
            .split(' ')
            .expand((word) => word.split(RegExp(r'(?<=-)')))
            .where((word) => word.isNotEmpty)
            .toList();
        if (words.length < parts.length) continue;
        for (final split in _splits(words, parts.length)) {
          for (final bullet in kLineBullets) {
            final texts = [
              for (var i = 0; i < split.length; i++)
                i == 0 ? '$bullet${split[i]}' : split[i],
            ];
            var likelihood = 0.0;
            for (var i = 0; i < parts.length; i++) {
              likelihood +=
                  ctcLogLikelihood(parts[i], texts[i], positionsByCharacter);
              if (likelihood < likelihoodFloor) break;
            }
            if (likelihood < likelihoodFloor) continue;
            // A word must share most of its letters with what was read. Short
            // smudges and background print ("0iz4", "baThexa") otherwise fit
            // some short word ("fig", "beer") within the visual allowance.
            if (stringSimilarity(_bare(texts.join(' ')), rawBare) <
                kMinReadingSimilarity) {
              continue;
            }
            final score = entry.logPrior + likelihood;
            if (score > bestScore) {
              bestScore = score;
              best = texts;
            }
          }
        }
      }
    }
    return best;
  }

  /// Every way to cut [words] into [parts] contiguous, non-empty groups.
  static Iterable<List<String>> _splits(List<String> words, int parts) sync* {
    if (parts == 1) {
      yield [_joinWords(words)];
      return;
    }
    for (var cut = 1; cut <= words.length - parts + 1; cut++) {
      final head = _joinWords(words.sublist(0, cut));
      for (final rest in _splits(words.sublist(cut), parts - 1)) {
        yield [head, ...rest];
      }
    }
  }

  /// Rejoins split words: a piece ending in "-" was cut at a hyphen, not a
  /// space.
  static String _joinWords(List<String> words) {
    final out = StringBuffer();
    for (var i = 0; i < words.length; i++) {
      out.write(words[i]);
      if (i + 1 < words.length && !words[i].endsWith('-')) out.write(' ');
    }
    return out.toString();
  }

  /// Minimum spelling similarity between a lexicon reading and the
  /// recognizer's own, bullets and case aside.
  static const double kMinReadingSimilarity = 0.5;

  static String _bare(String text) => normaliseText(
      text.replaceFirst(RegExp(r'^[\s\-–—•*+]+'), ''));

  /// How much worse (natural log, per raw character) a lexicon reading may
  /// explain the image than the recognizer's own reading.
  static const double kMaxVisualGapPerCharacter = 1.5;

  static Iterable<String> _caseForms(String text) sync* {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final lower = trimmed.toLowerCase();
    final capitalised = lower[0].toUpperCase() + lower.substring(1);
    final seen = <String>{};
    for (final form in [trimmed, lower, capitalised]) {
      if (seen.add(form)) yield form;
    }
  }

  /// Groups non-empty fragments into visual rows, each row left to right and
  /// rows top to bottom.
  List<List<PpOcrRecognizedRegion>> lineGroups(
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
    // A wide horizontal gap inside one row is a column break ("Klopapier ...
    // PENNY", "Goose Island ... + Burgers"), not a space between words.
    final split = <List<PpOcrRecognizedRegion>>[];
    for (final group in groups) {
      group.sort((a, b) => a.region.left.compareTo(b.region.left));
      final heights = group.map((e) => e.region.height).toList()..sort();
      final lineHeight = heights[heights.length ~/ 2];
      var current = <PpOcrRecognizedRegion>[group.first];
      for (final fragment in group.skip(1)) {
        final gap = fragment.region.left - current.last.region.right;
        if (gap > lineHeight * kColumnGapLineHeights) {
          split.add(current);
          current = [fragment];
        } else {
          current.add(fragment);
        }
      }
      split.add(current);
    }
    return split;
  }

  /// A horizontal gap wider than this many line heights separates columns.
  static const double kColumnGapLineHeights = 1.6;

  /// Joins fragments occupying the same visual row. This recovered split
  /// phrases such as `Olive | oil` and reduced unmatched sample predictions
  /// from nine to two in the six-image benchmark.
  List<PpOcrRecognizedRegion> mergeLineFragments(
    List<PpOcrRecognizedRegion> input,
  ) {
    final merged = <PpOcrRecognizedRegion>[];
    for (final group in lineGroups(input)) {
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

bool _looksLikeProbabilities(List<double> values) {
  if (values.isEmpty) return false;
  final sum = values.fold<double>(0, (total, value) => total + value);
  return values.every((value) => value >= 0 && value <= 1) &&
      sum >= 0.8 &&
      sum <= 1.2;
}

/// Log-probabilities over [values], renormalised over just these classes so a
/// restricted class set still forms a distribution.
List<double> _asLogProbabilities(List<double> values, bool areProbabilities) {
  if (areProbabilities) {
    final logs =
        values.map((value) => math.log(math.max(value, 1e-30))).toList();
    final maximum = logs.reduce(math.max);
    final denominator = logs.fold<double>(
        0, (total, value) => total + math.exp(value - maximum));
    final logDenominator = maximum + math.log(denominator);
    return logs.map((value) => value - logDenominator).toList();
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
