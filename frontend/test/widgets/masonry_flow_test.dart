import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/widgets/masonry_flow.dart';

void main() {
  group('MasonryFlow.assign', () {
    test('fills the shortest column, so tall cards do not stack up', () {
      // Heights 10, 10, 30, 10: the 30 lands in a column, and the one after it
      // must go to the other column rather than continuing round-robin.
      final buckets =
          MasonryFlow.assign(4, 2, (i) => const [10.0, 10.0, 30.0, 10.0][i]);

      expect(buckets[0], [0, 2]);
      expect(buckets[1], [1, 3]);
    });

    test('ties go left, keeping reading order for equal cards', () {
      final buckets = MasonryFlow.assign(6, 3, (_) => 20);

      expect(buckets[0], [0, 3]);
      expect(buckets[1], [1, 4]);
      expect(buckets[2], [2, 5]);
    });

    test('every item is placed exactly once', () {
      final buckets = MasonryFlow.assign(17, 4, (i) => 40.0 + (i * 37) % 120);
      final placed = buckets.expand((b) => b).toList()..sort();

      expect(placed, List.generate(17, (i) => i));
    });

    test('handles an empty set and a single column', () {
      expect(MasonryFlow.assign(0, 3, (_) => 10), [[], [], []]);
      expect(MasonryFlow.assign(3, 1, (_) => 10), [
        [0, 1, 2]
      ]);
    });
  });

  testWidgets('lays children out in columns and lets each keep its height',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: MasonryFlow(
              columnCount: 2,
              spacing: 20,
              itemCount: 3,
              estimateExtent: (i) => const [100.0, 50.0, 50.0][i],
              itemBuilder: (_, i) => SizedBox(
                height: const [100.0, 50.0, 50.0][i],
                child: Text('card$i'),
              ),
            ),
          ),
        ),
      ),
    );

    // Two columns of (400 - 20) / 2.
    expect(tester.getSize(find.text('card0')).width, 190);

    // card1 and card2 share the right column: the second sits below the first,
    // at its real height plus the run spacing — not stretched to match card0.
    final card1 = tester.getTopLeft(find.text('card1'));
    final card2 = tester.getTopLeft(find.text('card2'));
    expect(card1.dx, greaterThan(tester.getTopLeft(find.text('card0')).dx));
    expect(card2.dx, card1.dx);
    expect(card2.dy, card1.dy + 50 + 20);
  });
}
