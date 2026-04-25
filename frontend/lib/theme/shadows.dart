import 'package:flutter/material.dart';
import 'colors.dart';

class MitlistShadows {
  static const List<BoxShadow> shadowNone = [
    BoxShadow(color: Colors.transparent, offset: Offset(0, 0), blurRadius: 0),
  ];

  static const List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: MitlistColors.neutral950,
      offset: Offset(2, 2),
      blurRadius: 0,
    ),
  ];

  static const List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: MitlistColors.neutral950,
      offset: Offset(4, 4),
      blurRadius: 0,
    ),
  ];

  static const List<BoxShadow> shadowStrong = [
    BoxShadow(
      color: MitlistColors.neutral950,
      offset: Offset(6, 6),
      blurRadius: 0,
    ),
  ];

  static const List<BoxShadow> shadowFloating = [
    BoxShadow(
      color: MitlistColors.neutral950,
      offset: Offset(8, 8),
      blurRadius: 0,
    ),
  ];
}
