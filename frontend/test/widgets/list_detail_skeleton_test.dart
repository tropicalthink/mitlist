import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/widgets/list/list_detail_skeleton.dart';

void main() {
  testWidgets('loading skeleton is safe inside the refresh scroll wrapper',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 600),
              child: const ListDetailSkeleton(),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(ListDetailSkeleton), findsOneWidget);
  });
}
