import 'package:flutter/widgets.dart';

/// A waterfall (Google Keep style) column flow: every child keeps its own
/// intrinsic height and cards stack up the shortest column, so a two-item list
/// looks like a two-item list instead of being stretched into the same box as
/// a four-item one.
///
/// Flutter has no lazy masonry sliver in the framework, so this lays every
/// child out eagerly — correct for a screen that already paginates into a
/// bounded page (tens of cards), not for an unbounded feed.
///
/// Placement is greedy over [estimateExtent] rather than measured height:
/// balancing has to happen *before* layout, so the estimate only decides which
/// column a card lands in. A rough estimate makes columns slightly uneven at
/// the bottom; it can never clip or overflow a card, because the real height
/// is still whatever the child lays out to.
class MasonryFlow extends StatelessWidget {
  const MasonryFlow({
    super.key,
    required this.columnCount,
    required this.itemCount,
    required this.itemBuilder,
    required this.estimateExtent,
    this.spacing = 0,
    double? runSpacing,
  }) : runSpacing = runSpacing ?? spacing;

  /// Number of columns. Clamped to at least one.
  final int columnCount;

  /// Horizontal gap between columns.
  final double spacing;

  /// Vertical gap between cards within a column.
  final double runSpacing;

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Approximate laid-out height of item [index], used only to pick the column
  /// with the least accumulated height.
  final double Function(int index) estimateExtent;

  /// Distributes indices into [columns] buckets, each time appending to the
  /// column that is currently shortest. Ties go to the leftmost column, which
  /// keeps the natural reading order for equal-height cards.
  static List<List<int>> assign(
    int itemCount,
    int columns,
    double Function(int index) estimateExtent,
  ) {
    final buckets = List.generate(columns, (_) => <int>[]);
    final heights = List<double>.filled(columns, 0);
    for (var i = 0; i < itemCount; i++) {
      var target = 0;
      for (var c = 1; c < columns; c++) {
        if (heights[c] < heights[target]) target = c;
      }
      buckets[target].add(i);
      heights[target] += estimateExtent(i);
    }
    return buckets;
  }

  @override
  Widget build(BuildContext context) {
    final columns = columnCount < 1 ? 1 : columnCount;
    final buckets = assign(itemCount, columns, estimateExtent);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < columns; c++) ...[
          if (c > 0) SizedBox(width: spacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var r = 0; r < buckets[c].length; r++) ...[
                  if (r > 0) SizedBox(height: runSpacing),
                  itemBuilder(context, buckets[c][r]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
