import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/scan/resolution/calibrated_scorer.dart';
import 'package:mitlist/services/scan/resolution/resolution_features.dart';

// CalibratedScorer.load — proves the shipped weights bundle is picked up when
// valid and FAILS SOFT to the hand defaults otherwise (missing asset, wrong
// feature layout, wrong length). The fail-soft + parity guard are what make it
// safe to ship a fitted bundle without an app release.

class _FakeBundle extends AssetBundle {
  final String? content;
  _FakeBundle(this.content);

  @override
  Future<ByteData> load(String key) async => throw UnimplementedError();

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final c = content;
    if (c == null) throw Exception('asset $key not found');
    return c;
  }
}

String _bundle({
  List<String>? featureNames,
  List<double>? weights,
  double bias = -1.0,
  double tauAuto = 0.9,
}) =>
    jsonEncode({
      'version': 1,
      'feature_names': featureNames ?? kResolutionFeatureNames,
      'weights':
          weights ?? List.filled(kResolutionFeatureCount, 0.5),
      'bias': bias,
      'tau_auto': tauAuto,
      'tau_review': 0.5,
    });

void main() {
  group('CalibratedScorer.load', () {
    test('loads a valid, parity-matching bundle', () async {
      final s = await CalibratedScorer.load(
        bundle: _FakeBundle(_bundle(bias: -2.0, tauAuto: 0.88)),
      );
      expect(s.weights, List.filled(kResolutionFeatureCount, 0.5));
      expect(s.bias, -2.0);
      expect(s.tauAuto, 0.88);
    });

    test('missing asset → hand defaults', () async {
      final s = await CalibratedScorer.load(bundle: _FakeBundle(null));
      expect(s.weights, CalibratedScorer.kDefaultWeights);
      expect(s.bias, CalibratedScorer.kDefaultBias);
    });

    test('parity guard: mismatched feature_names → defaults', () async {
      final wrongOrder = List<String>.from(kResolutionFeatureNames.reversed);
      final s = await CalibratedScorer.load(
        bundle: _FakeBundle(_bundle(featureNames: wrongOrder)),
      );
      expect(s.weights, CalibratedScorer.kDefaultWeights);
    });

    test('wrong weight length → defaults', () async {
      final s = await CalibratedScorer.load(
        bundle: _FakeBundle(_bundle(weights: const [1, 2, 3])),
      );
      expect(s.weights, CalibratedScorer.kDefaultWeights);
    });

    test('malformed JSON → defaults', () async {
      final s = await CalibratedScorer.load(bundle: _FakeBundle('{not json'));
      expect(s.weights, CalibratedScorer.kDefaultWeights);
    });
  });
}
