import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/models/list_models.dart';
import 'package:mitlist/providers/chore_provider.dart';
import 'package:mitlist/providers/finance_provider.dart';
import 'package:mitlist/providers/list_provider.dart';
import 'package:mitlist/widgets/hub/stats_grid.dart';

void main() {
  testWidgets('StatsGrid renders skeleton when loading', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: StatsGridSkeleton()),
    );
    expect(find.byType(AppSkeleton), findsWidgets);
  });
}
