import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

enum CaptureQualityLevel { poor, okay, good }

class CaptureQualityResult {
  const CaptureQualityResult({
    required this.level,
    required this.score,
    required this.hint,
    required this.sharpness,
    required this.brightness,
    required this.contrast,
    required this.glareRatio,
  });

  final CaptureQualityLevel level;
  final double score;
  final String hint;
  final double sharpness;
  final double brightness;
  final double contrast;
  final double glareRatio;

  bool get isUsable => level != CaptureQualityLevel.poor;
}

class CaptureQualityService {
  const CaptureQualityService();

  CaptureQualityResult assess(Uint8List bytes) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return _invalid();
    }
    if (decoded == null || decoded.width < 64 || decoded.height < 64) {
      return _invalid();
    }

    final stepX = math.max(1, decoded.width ~/ 96);
    final stepY = math.max(1, decoded.height ~/ 96);
    return _assessImage(decoded, stepX: stepX, stepY: stepY);
  }

  CaptureQualityResult assessLumaPlane({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
    int pixelStride = 1,
  }) {
    if (width < 64 || height < 64 || bytes.isEmpty || bytesPerRow <= 0) {
      return _invalid();
    }

    try {
      final stepX = math.max(1, width ~/ 96);
      final stepY = math.max(1, height ~/ 96);
      final values = <double>[];
      var glare = 0;
      var sum = 0.0;

      for (var y = 0; y < height; y += stepY) {
        for (var x = 0; x < width; x += stepX) {
          final index = y * bytesPerRow + x * pixelStride;
          if (index < 0 || index >= bytes.length) continue;
          final luma = bytes[index].toDouble();
          values.add(luma);
          sum += luma;
          if (luma > 245) glare++;
        }
      }

      if (values.isEmpty) return _invalid();
      final sharpness = _sharpnessLuma(
        bytes,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        pixelStride: pixelStride,
        stepX: stepX,
        stepY: stepY,
      );
      return _fromStats(
        values: values,
        sum: sum,
        glare: glare,
        sharpness: sharpness,
      );
    } catch (_) {
      return _invalid();
    }
  }

  CaptureQualityResult _assessImage(
    img.Image decoded, {
    required int stepX,
    required int stepY,
  }) {
    final values = <double>[];
    var glare = 0;
    var sum = 0.0;

    for (var y = 0; y < decoded.height; y += stepY) {
      for (var x = 0; x < decoded.width; x += stepX) {
        final p = decoded.getPixel(x, y);
        final luma = _luma(p).toDouble();
        values.add(luma);
        sum += luma;
        if (p.r > 245 && p.g > 245 && p.b > 245) glare++;
      }
    }

    return _fromStats(
      values: values,
      sum: sum,
      glare: glare,
      sharpness: _sharpness(decoded, stepX: stepX, stepY: stepY),
    );
  }

  CaptureQualityResult _fromStats({
    required List<double> values,
    required double sum,
    required int glare,
    required double sharpness,
  }) {
    final n = values.length;
    final mean = sum / n;
    var variance = 0.0;
    for (final v in values) {
      final d = v - mean;
      variance += d * d;
    }
    final contrast = math.sqrt(variance / n) / 128.0;
    final brightness = mean / 255.0;
    final glareRatio = glare / n;

    final brightnessScore = _bell(brightness, center: 0.58, width: 0.34);
    final contrastScore = (contrast / 0.55).clamp(0.0, 1.0);
    final sharpnessScore = (sharpness / 0.16).clamp(0.0, 1.0);
    final glareScore = (1.0 - glareRatio / 0.18).clamp(0.0, 1.0);
    final score = (sharpnessScore * 0.42) +
        (contrastScore * 0.28) +
        (brightnessScore * 0.20) +
        (glareScore * 0.10);

    final hint = _hint(
      score: score,
      brightness: brightness,
      contrast: contrast,
      sharpness: sharpness,
      glareRatio: glareRatio,
    );
    final level = score >= 0.68
        ? CaptureQualityLevel.good
        : score >= 0.36
            ? CaptureQualityLevel.okay
            : CaptureQualityLevel.poor;

    return CaptureQualityResult(
      level: level,
      score: score,
      hint: hint,
      sharpness: sharpness,
      brightness: brightness,
      contrast: contrast,
      glareRatio: glareRatio,
    );
  }

  static CaptureQualityResult _invalid() {
    return const CaptureQualityResult(
      level: CaptureQualityLevel.poor,
      score: 0,
      hint: 'Try a clearer photo',
      sharpness: 0,
      brightness: 0,
      contrast: 0,
      glareRatio: 1,
    );
  }

  static int _luma(img.Pixel p) =>
      (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();

  static double _sharpness(
    img.Image image, {
    required int stepX,
    required int stepY,
  }) {
    var total = 0.0;
    var count = 0;
    final sx = math.max(1, stepX);
    final sy = math.max(1, stepY);

    for (var y = sy; y < image.height - sy; y += sy) {
      for (var x = sx; x < image.width - sx; x += sx) {
        final c = _luma(image.getPixel(x, y));
        final lap = (_luma(image.getPixel(x - sx, y)) +
                _luma(image.getPixel(x + sx, y)) +
                _luma(image.getPixel(x, y - sy)) +
                _luma(image.getPixel(x, y + sy)) -
                (4 * c))
            .abs();
        total += lap;
        count++;
      }
    }

    if (count == 0) return 0;
    return (total / count) / 255.0;
  }

  static double _sharpnessLuma(
    Uint8List bytes, {
    required int width,
    required int height,
    required int bytesPerRow,
    required int pixelStride,
    required int stepX,
    required int stepY,
  }) {
    var total = 0.0;
    var count = 0;
    final sx = math.max(1, stepX);
    final sy = math.max(1, stepY);

    int? lumaAt(int x, int y) {
      final index = y * bytesPerRow + x * pixelStride;
      if (index < 0 || index >= bytes.length) return null;
      return bytes[index];
    }

    for (var y = sy; y < height - sy; y += sy) {
      for (var x = sx; x < width - sx; x += sx) {
        final c = lumaAt(x, y);
        final l = lumaAt(x - sx, y);
        final r = lumaAt(x + sx, y);
        final t = lumaAt(x, y - sy);
        final b = lumaAt(x, y + sy);
        if (c == null || l == null || r == null || t == null || b == null) {
          continue;
        }
        total += (l + r + t + b - (4 * c)).abs();
        count++;
      }
    }

    if (count == 0) return 0;
    return (total / count) / 255.0;
  }

  static double _bell(
    double value, {
    required double center,
    required double width,
  }) {
    final d = ((value - center).abs() / width).clamp(0.0, 1.0);
    return 1.0 - d;
  }

  static String _hint({
    required double score,
    required double brightness,
    required double contrast,
    required double sharpness,
    required double glareRatio,
  }) {
    if (sharpness < 0.07) return 'Hold steady';
    if (brightness < 0.28) return 'Find more light';
    if (brightness > 0.86 || glareRatio > 0.16) return 'Reduce glare';
    if (contrast < 0.22) return 'Move closer';
    if (score >= 0.72) return 'Ready to scan';
    return 'Looks usable';
  }
}
