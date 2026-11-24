import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/theme/member_colors.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('every member colour keeps the initials at 4.5:1 or more', () {
    for (final brightness in Brightness.values) {
      for (var i = 0; i < MemberColors.count; i++) {
        final roster = [for (var j = 0; j < MemberColors.count; j++) 'u$j'];
        final c = MemberColors.of('u$i', brightness, roster);
        expect(_contrast(c.background, c.foreground), greaterThanOrEqualTo(4.5),
            reason: '$brightness slot $i');
      }
    }
  });

  test('members of one household get distinct, stable colours', () {
    const roster = ['maya', 'jonas', 'priya', 'sam'];
    final slots = {for (final id in roster) MemberColors.indexFor(id, roster)};
    expect(slots, hasLength(roster.length));
    expect(MemberColors.indexFor('jonas', roster),
        MemberColors.indexFor('jonas', roster.reversed));
    // Without a roster: the same id always gets the same slot.
    expect(MemberColors.indexFor('someone'), MemberColors.indexFor('someone'));
  });
}
