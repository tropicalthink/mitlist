import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mitlist/services/scan/document_rectifier_service.dart';

void main() {
  group('mapStreamRectToImage — rotation mapping table', () {
    // Stream rect: l=0.1, t=0.2, r=0.5, b=0.9
    // Expected JPEG-space rects after clockwise rotation by sensorOrientation.
    //
    // Rotation formula for a point (x, y) rotated clockwise by θ:
    //   0°  → (x, y)
    //   90° → (1−y, x)
    //   180°→ (1−x, 1−y)
    //   270°→ (y, 1−x)
    //
    // We rotate each corner of the input rect and take the bounding box.

    test('0° — identity', () {
      final h = _hint(l: 0.1, t: 0.2, r: 0.5, b: 0.9, orientation: 0);
      final m = mapStreamRectToImage(h);
      // p1 = rot(0.1, 0.2) = (0.1, 0.2)
      // p2 = rot(0.5, 0.9) = (0.5, 0.9)
      expect(m.l, closeTo(0.1, 1e-9));
      expect(m.t, closeTo(0.2, 1e-9));
      expect(m.r, closeTo(0.5, 1e-9));
      expect(m.b, closeTo(0.9, 1e-9));
    });

    test('90° — clockwise rotation', () {
      final h = _hint(l: 0.1, t: 0.2, r: 0.5, b: 0.9, orientation: 90);
      final m = mapStreamRectToImage(h);
      // p1 = rot(0.1, 0.2) = (1−0.2, 0.1) = (0.8, 0.1)
      // p2 = rot(0.5, 0.9) = (1−0.9, 0.5) = (0.1, 0.5)
      // bbox: l=min(0.8,0.1)=0.1, t=min(0.1,0.5)=0.1
      //        r=max(0.8,0.1)=0.8, b=max(0.1,0.5)=0.5
      expect(m.l, closeTo(0.1, 1e-9));
      expect(m.t, closeTo(0.1, 1e-9));
      expect(m.r, closeTo(0.8, 1e-9));
      expect(m.b, closeTo(0.5, 1e-9));
    });

    test('180° — half turn', () {
      final h = _hint(l: 0.1, t: 0.2, r: 0.5, b: 0.9, orientation: 180);
      final m = mapStreamRectToImage(h);
      // p1 = rot(0.1, 0.2) = (0.9, 0.8)
      // p2 = rot(0.5, 0.9) = (0.5, 0.1)
      // bbox: l=0.5, t=0.1, r=0.9, b=0.8
      expect(m.l, closeTo(0.5, 1e-9));
      expect(m.t, closeTo(0.1, 1e-9));
      expect(m.r, closeTo(0.9, 1e-9));
      expect(m.b, closeTo(0.8, 1e-9));
    });

    test('270° — counter-clockwise 90°', () {
      final h = _hint(l: 0.1, t: 0.2, r: 0.5, b: 0.9, orientation: 270);
      final m = mapStreamRectToImage(h);
      // p1 = rot(0.1, 0.2) = (0.2, 1−0.1) = (0.2, 0.9)
      // p2 = rot(0.5, 0.9) = (0.9, 1−0.5) = (0.9, 0.5)
      // bbox: l=0.2, t=0.5, r=0.9, b=0.9
      expect(m.l, closeTo(0.2, 1e-9));
      expect(m.t, closeTo(0.5, 1e-9));
      expect(m.r, closeTo(0.9, 1e-9));
      expect(m.b, closeTo(0.9, 1e-9));
    });

    test('360° treated same as 0°', () {
      final h = _hint(l: 0.1, t: 0.2, r: 0.5, b: 0.9, orientation: 360);
      final m = mapStreamRectToImage(h);
      expect(m.l, closeTo(0.1, 1e-9));
      expect(m.t, closeTo(0.2, 1e-9));
      expect(m.r, closeTo(0.5, 1e-9));
      expect(m.b, closeTo(0.9, 1e-9));
    });
  });

  group('cropToNormalizedRect — happy path', () {
    test('crops to approximately the padded box', () {
      // 400×600 solid-colour image.
      final source = img.fill(
        img.Image(width: 400, height: 600),
        color: img.ColorRgb8(200, 200, 200),
      );
      final jpegBytes = Uint8List.fromList(img.encodeJpg(source, quality: 92));

      // Crop centre half: l=0.25, t=0.25, r=0.75, b=0.75
      final result = cropToNormalizedRect(
        jpegBytes,
        l: 0.25,
        t: 0.25,
        r: 0.75,
        b: 0.75,
        pad: 0.06,
      );

      expect(result, isNotNull);
      final decoded = img.decodeImage(result!)!;

      // Expected padded box: lp=0.19, tp=0.19, rp=0.81, bp=0.81
      // boxW = 0.62, boxH = 0.62
      // pixel dims ≈ round(0.62 * 400) × round(0.62 * 600) = 248 × 372
      expect(decoded.width, closeTo(248, 2));
      expect(decoded.height, closeTo(372, 2));
    });
  });

  group('cropToNormalizedRect — guards', () {
    late Uint8List jpegBytes;

    setUp(() {
      final source = img.fill(
        img.Image(width: 400, height: 600),
        color: img.ColorRgb8(100, 100, 100),
      );
      jpegBytes = Uint8List.fromList(img.encodeJpg(source, quality: 92));
    });

    test('returns null for a sliver box (width < 0.25)', () {
      // l=0.49, r=0.51 → boxW≈0.02 after pad — still well below 0.25 unless
      // pad lifts it; with pad=0.06 boxW = 0.51+0.06 - (0.49-0.06) = 0.14 → null
      final result = cropToNormalizedRect(
        jpegBytes,
        l: 0.49,
        t: 0.0,
        r: 0.51,
        b: 1.0,
        pad: 0.06,
      );
      expect(result, isNull);
    });

    test('returns null for ~full-frame box', () {
      final result = cropToNormalizedRect(
        jpegBytes,
        l: 0.0,
        t: 0.0,
        r: 1.0,
        b: 1.0,
        pad: 0.06,
      );
      expect(result, isNull);
    });
  });
}

/// Helper to build a [CaptureCropHint] concisely.
CaptureCropHint _hint({
  required double l,
  required double t,
  required double r,
  required double b,
  required int orientation,
}) =>
    CaptureCropHint(
      left: l,
      top: t,
      right: r,
      bottom: b,
      sensorOrientation: orientation,
    );
