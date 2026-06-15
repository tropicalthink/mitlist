import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

enum CaptureBoundaryLevel { missing, partial, found }

class CaptureBoundaryResult {
  const CaptureBoundaryResult({
    required this.level,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.score,
    required this.hint,
  });

  final CaptureBoundaryLevel level;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double score;
  final String hint;

  bool get hasBounds => level != CaptureBoundaryLevel.missing;
  double get width => math.max(0, right - left);
  double get height => math.max(0, bottom - top);
  double get area => width * height;
}

class CaptureBoundaryService {
  const CaptureBoundaryService();

  CaptureBoundaryResult detectImage(Uint8List bytes) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return _missing('Frame the list');
    }
    if (decoded == null || decoded.width < 64 || decoded.height < 64) {
      return _missing('Frame the list');
    }

    final image = decoded;
    final stepX = math.max(1, image.width ~/ 120);
    final stepY = math.max(1, image.height ~/ 120);
    return _detect(
      width: image.width,
      height: image.height,
      stepX: stepX,
      stepY: stepY,
      lumaAt: (x, y) {
        final p = image.getPixel(x, y);
        return (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();
      },
    );
  }

  CaptureBoundaryResult detectLumaPlane({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
    int pixelStride = 1,
  }) {
    if (width < 64 || height < 64 || bytes.isEmpty || bytesPerRow <= 0) {
      return _missing('Frame the list');
    }

    final stepX = math.max(1, width ~/ 120);
    final stepY = math.max(1, height ~/ 120);
    return _detect(
      width: width,
      height: height,
      stepX: stepX,
      stepY: stepY,
      lumaAt: (x, y) {
        final index = y * bytesPerRow + x * pixelStride;
        if (index < 0 || index >= bytes.length) return null;
        return bytes[index];
      },
    );
  }

  CaptureBoundaryResult _detect({
    required int width,
    required int height,
    required int stepX,
    required int stepY,
    required int? Function(int x, int y) lumaAt,
  }) {
    var minLuma = 255;
    var maxLuma = 0;
    var sum = 0.0;
    var count = 0;

    for (var y = 0; y < height; y += stepY) {
      for (var x = 0; x < width; x += stepX) {
        final luma = lumaAt(x, y);
        if (luma == null) continue;
        minLuma = math.min(minLuma, luma);
        maxLuma = math.max(maxLuma, luma);
        sum += luma;
        count++;
      }
    }

    if (count == 0 || maxLuma - minLuma < 24) {
      return _missing('Find the list edges');
    }

    final mean = sum / count;
    final brightThreshold = math.max(145.0, mean + ((maxLuma - mean) * 0.32));
    final edgeThreshold = math.max(20, (maxLuma - minLuma) * 0.18);

    var minX = width;
    var minY = height;
    var maxX = 0;
    var maxY = 0;
    var candidateCount = 0;

    for (var y = stepY; y < height - stepY; y += stepY) {
      for (var x = stepX; x < width - stepX; x += stepX) {
        final c = lumaAt(x, y);
        final r = lumaAt(x + stepX, y);
        final b = lumaAt(x, y + stepY);
        if (c == null || r == null || b == null) continue;

        final edge = math.max((c - r).abs(), (c - b).abs());
        final candidate = c >= brightThreshold || edge >= edgeThreshold;
        if (!candidate) continue;

        minX = math.min(minX, x);
        minY = math.min(minY, y);
        maxX = math.max(maxX, x);
        maxY = math.max(maxY, y);
        candidateCount++;
      }
    }

    if (candidateCount < 8 || minX >= maxX || minY >= maxY) {
      return _missing('Find the list edges');
    }

    final left = (minX / width).clamp(0.0, 1.0);
    final top = (minY / height).clamp(0.0, 1.0);
    final right = (maxX / width).clamp(0.0, 1.0);
    final bottom = (maxY / height).clamp(0.0, 1.0);
    final boundsWidth = right - left;
    final boundsHeight = bottom - top;
    final area = boundsWidth * boundsHeight;
    final fillRatio = candidateCount / count;

    if (area < 0.16) {
      return _result(
        CaptureBoundaryLevel.partial,
        left,
        top,
        right,
        bottom,
        0.34,
        'Move closer',
      );
    }

    final edgeMargin =
        math.min(math.min(left, top), math.min(1 - right, 1 - bottom));
    final areaScore = _bell(area, center: 0.58, width: 0.48);
    final fillScore = _bell(fillRatio, center: 0.46, width: 0.54);
    final marginScore = (edgeMargin / 0.08).clamp(0.0, 1.0);
    final score =
        ((areaScore * 0.48) + (fillScore * 0.30) + (marginScore * 0.22))
            .clamp(0.0, 1.0);

    if (score >= 0.56) {
      return _result(
        CaptureBoundaryLevel.found,
        left,
        top,
        right,
        bottom,
        score,
        'Edges found',
      );
    }

    return _result(
      CaptureBoundaryLevel.partial,
      left,
      top,
      right,
      bottom,
      score,
      edgeMargin < 0.04 ? 'Leave room around edges' : 'Hold steady',
    );
  }

  static CaptureBoundaryResult _missing(String hint) {
    return CaptureBoundaryResult(
      level: CaptureBoundaryLevel.missing,
      left: 0,
      top: 0,
      right: 0,
      bottom: 0,
      score: 0,
      hint: hint,
    );
  }

  static CaptureBoundaryResult _result(
    CaptureBoundaryLevel level,
    double left,
    double top,
    double right,
    double bottom,
    double score,
    String hint,
  ) {
    return CaptureBoundaryResult(
      level: level,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      score: score,
      hint: hint,
    );
  }

  static double _bell(
    double value, {
    required double center,
    required double width,
  }) {
    final d = ((value - center).abs() / width).clamp(0.0, 1.0);
    return 1.0 - (d * d);
  }
}
