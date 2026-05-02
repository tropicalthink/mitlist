import 'package:flutter/animation.dart';

class MitlistAnimations {
  // ---- Durations -----------------------------------------------------------

  static const Duration micro = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration banner = Duration(milliseconds: 350);
  static const Duration page = Duration(milliseconds: 300);
  static const Duration toast = Duration(milliseconds: 300);

  // Keep skeleton motion subtle and snappy; long shimmer cycles read as "slow".
  static const Duration skeleton = Duration(milliseconds: 900);

  // Check / toggle feedback — snappy but visible.
  static const Duration checkToggle = Duration(milliseconds: 250);

  // Ambient loop for breathing / floating idle animations.
  static const Duration breatheLoop = Duration(milliseconds: 2400);

  // Staggered entrance — total window for a screen to settle.
  static const Duration entrance = Duration(milliseconds: 600);

  // Delay between each staggered element reveal.
  static const Duration staggerOffset = Duration(milliseconds: 150);

  // ---- Offsets -------------------------------------------------------------

  static const double fadeOffset = 10.0;
  static const double cardEnterOffset = 8.0;
  static const double toastOffset = 20.0;

  // Subtle vertical float for idle icons.
  static const double breatheAmplitude = 4.0;

  // ---- Easing curves — follow best practices: no bounce / elastic ----------

  // Smooth deceleration — element settles into place.
  static const Cubic easeEnter = Cubic(0.25, 1.0, 0.5, 1.0);

  // Quick exit — faster than entrance (≈ 75 %).
  static const Cubic easeExit = Cubic(0.4, 0.0, 0.2, 1.0);

  // Gentle sine-like wave for ambient looping (breathe / float).
  static const Cubic easeBreathe = Cubic(0.37, 0.0, 0.63, 1.0);
}
