class MitlistAnimations {
  static const Duration micro = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration banner = Duration(milliseconds: 350);
  static const Duration page = Duration(milliseconds: 300);
  static const Duration toast = Duration(milliseconds: 300);

  // Keep skeleton motion subtle and snappy; long shimmer cycles read as "slow".
  static const Duration skeleton = Duration(milliseconds: 900);

  static const double fadeOffset = 10.0;
  static const double cardEnterOffset = 8.0;
  static const double toastOffset = 20.0;
}
