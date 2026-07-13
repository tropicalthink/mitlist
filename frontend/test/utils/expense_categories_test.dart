import 'package:flutter_test/flutter_test.dart';
import 'package:mitlist/l10n/app_localizations_en.dart';
import 'package:mitlist/utils/expense_categories.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('maps known keys to their labels', () {
    expect(expenseCategoryLabel(l10n, 'groceries'), 'Groceries');
    expect(expenseCategoryLabel(l10n, 'dining'), 'Dining');
    expect(expenseCategoryLabel(l10n, 'other'), 'Other');
  });

  test('unknown / legacy values fall back to Other', () {
    expect(expenseCategoryLabel(l10n, ''), 'Other');
    expect(expenseCategoryLabel(l10n, 'misc-legacy'), 'Other');
  });

  test('every category key resolves to a non-empty label', () {
    for (final key in expenseCategoryKeys) {
      expect(expenseCategoryLabel(l10n, key), isNotEmpty);
    }
  });
}
