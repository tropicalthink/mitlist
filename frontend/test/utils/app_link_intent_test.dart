import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/services/widgets/app_shortcuts.dart';
import 'package:mitlist/services/widgets/widget_snapshot_sync.dart';
import 'package:mitlist/utils/app_link_intent.dart';

const _hh = '11111111-1111-4111-8111-111111111111';
const _list = '22222222-2222-4222-8222-222222222222';

void main() {
  group('AppLinkIntent', () {
    test('switches household and keeps the list composer flag', () {
      final intent =
          AppLinkIntent.parse(Uri.parse('/lists/$_list?group=$_hh&add=1'))!;
      expect(intent.groupId, _hh);
      expect(intent.location, '/lists/$_list?add=1');
      expect(intent.openExpenseSheet, isFalse);
    });

    test('opens the expense sheet with a prefilled amount', () {
      final intent = AppLinkIntent.parse(
          Uri.parse('/money?group=$_hh&add=1&amount_cents=1234'))!;
      expect(intent.location, '/money');
      expect(intent.openExpenseSheet, isTrue);
      expect(intent.initialAmount, '12.34');
    });

    test('ignores a malformed household and a bad amount', () {
      final intent = AppLinkIntent.parse(
          Uri.parse('/money?group=nope&add=1&amount_cents=x'))!;
      expect(intent.groupId, isNull);
      expect(intent.initialAmount, isNull);
      expect(intent.location, '/money');
    });

    test('leaves links without widget parameters alone', () {
      expect(AppLinkIntent.parse(Uri.parse('/lists/$_list?add=1')), isNull);
      expect(AppLinkIntent.parse(Uri.parse('/chores')), isNull);
    });
  });

  group('AppShortcuts.locationFor', () {
    const defaults = WidgetDefaults(householdId: _hh, listId: _list);

    test('points every shortcut at a C5 link', () {
      expect(AppShortcuts.locationFor(AppShortcuts.addItem, defaults),
          '/lists/$_list?group=$_hh&add=1');
      expect(AppShortcuts.locationFor(AppShortcuts.scan, defaults), '/scanner');
      expect(AppShortcuts.locationFor(AppShortcuts.logExpense, defaults),
          '/money?group=$_hh&add=1');
      expect(AppShortcuts.locationFor(AppShortcuts.choresToday, defaults),
          '/chores?group=$_hh');
    });

    test('falls back to the tabs before the first snapshot', () {
      expect(AppShortcuts.locationFor(AppShortcuts.addItem, null), '/lists');
      expect(AppShortcuts.locationFor(AppShortcuts.logExpense, null),
          '/money?add=1');
      expect(AppShortcuts.locationFor('unknown', null), '/home');
    });
  });
}
