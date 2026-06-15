import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'resolution_features.dart';

/// Plan 037 — the calibrated scorer. `P(correct) = sigmoid(w·features + b)`.
///
/// Pure: a dot-product and a sigmoid. The weights are the only learned artifact
/// and they are tiny ([kResolutionFeatureCount] floats + bias), fit at build
/// time on the eval set and shipped as a versioned bundle. Until a fit ships,
/// the hand-set defaults below make the ensemble good out of the box.
///
/// The default weights are deliberately interpretable: the strongest
/// disambiguator is [canonicalNameSim] (a word colliding as an alias of the
/// wrong item still matches the RIGHT item's own name best), then a confirmed
/// household alias, then the model/prior signals.
class CalibratedScorer {
  final List<double> weights;
  final double bias;

  /// Auto-accept at/above this P; below [tauReview] → ask; between → review.
  final double tauAuto;
  final double tauReview;

  CalibratedScorer({
    List<double>? weights,
    double? bias,
    double? tauAuto,
    double? tauReview,
  })  : weights = weights ?? kDefaultWeights,
        bias = bias ?? kDefaultBias,
        tauAuto = tauAuto ?? 0.85,
        tauReview = tauReview ?? 0.50 {
    assert(this.weights.length == kResolutionFeatureCount,
        'weights must have $kResolutionFeatureCount entries');
  }

  double score(List<double> features) {
    assert(features.length == weights.length);
    var z = bias;
    for (var i = 0; i < weights.length; i++) {
      z += weights[i] * features[i];
    }
    return 1.0 / (1.0 + math.exp(-z));
  }

  /// The shipped, versioned weights bundle produced by the build-time fitter
  /// (`intelligence/ml/eval/resolution_eval.py`).
  static const String assetPath = 'assets/grocery/resolution_weights.json';

  /// Loads the fitted weights bundle, **failing soft to the hand-set defaults**
  /// when it is absent, malformed, or fit on a different feature layout. So the
  /// resolver is always good out of the box, and a future fit ships by dropping
  /// the (versioned) JSON into assets — no app release, no code change.
  ///
  /// Parity guard: a bundle whose `feature_names` don't match
  /// [kResolutionFeatureNames] exactly (order included) is rejected — weights
  /// fit on a different feature order would be silently, dangerously wrong.
  static Future<CalibratedScorer> load({AssetBundle? bundle}) async {
    try {
      final raw = await (bundle ?? rootBundle).loadString(assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;

      final weights = (json['weights'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList();
      if (weights == null || weights.length != kResolutionFeatureCount) {
        return CalibratedScorer();
      }
      final names = (json['feature_names'] as List?)?.cast<String>();
      if (names != null && !listEquals(names, kResolutionFeatureNames)) {
        return CalibratedScorer();
      }
      return CalibratedScorer(
        weights: weights,
        bias: (json['bias'] as num?)?.toDouble(),
        tauAuto: (json['tau_auto'] as num?)?.toDouble(),
        tauReview: (json['tau_review'] as num?)?.toDouble(),
      );
    } catch (_) {
      return CalibratedScorer();
    }
  }

  // Order matches kResolutionFeatureNames. Hand-set defaults tuned on the
  // starter eval set to reach 100% precision@auto-accept at baseline-equivalent
  // coverage; replaced by the build-time logistic fit once a real eval set
  // exists (intelligence/ml/eval/resolution_eval.py).
  // aliasSim, nameSim, clsProb, embCos, agreement, hhAlias, freq, recency, cooc, exact
  static const List<double> kDefaultWeights = [
    1.4, // aliasStringSim
    4.4, // canonicalNameSim  ← primary disambiguator (own name > secondary alias)
    2.2, // classifierProb
    1.8, // embedderCosine
    0.8, // sourceAgreement
    2.6, // isHouseholdAlias
    1.8, // householdFreq
    0.5, // recency
    1.4, // listCooccurrence
    0.4, // isExactAlias
  ];

  static const double kDefaultBias = -2.7;
}
