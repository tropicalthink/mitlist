import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/theme/spacing.dart';
import 'package:mitlist/widgets/hub/pinwall_section.dart';

void main() {
  group('pinwallHubLayout', () {
    // The regression this guards: the hub used a fixed 160dp card. Two of them
    // plus 16dp spacing need 336dp, so any viewport below that fell back to one
    // card per row with the rest of the row left empty. Raising the system
    // display-size setting on an ordinary phone is enough to get there.
    test('fits two columns even on viewports too narrow for two fixed cards',
        () {
      for (final width in [260.0, 300.0, 320.0, 335.0]) {
        final layout = pinwallHubLayout(width);
        expect(layout.columns, 2, reason: 'at ${width}dp');
        expect(layout.cardWidth, greaterThan(0), reason: 'at ${width}dp');
      }
    });

    test('columns exactly fill the available width at every size', () {
      for (final width in [260.0, 320.0, 360.0, 411.0, 600.0, 834.0, 1280.0]) {
        final layout = pinwallHubLayout(width);
        final used = layout.cardWidth * layout.columns +
            MitlistSpacing.md * (layout.columns - 1);
        expect(used, closeTo(width, 0.001),
            reason: 'row should leave no ragged gap at ${width}dp');
      }
    });

    test('wide surfaces take more columns instead of stretching cards', () {
      expect(pinwallHubLayout(411).columns, 2);
      expect(pinwallHubLayout(834).columns, 4);

      // Cards stay in a readable band rather than growing without bound.
      expect(pinwallHubLayout(1280).cardWidth, lessThan(340));
    });

    test('never exceeds four columns', () {
      expect(pinwallHubLayout(4000).columns, 4);
    });
  });
}
