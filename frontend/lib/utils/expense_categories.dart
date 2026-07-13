import '../l10n/app_localizations.dart';

/// Stable category keys stored on the expense (`Expense.category`). Keys are
/// language-independent so household members on different locales still group
/// expenses the same way; the display label is resolved per-locale via
/// [expenseCategoryLabel].
const List<String> expenseCategoryKeys = <String>[
  'groceries',
  'dining',
  'transport',
  'utilities',
  'household',
  'entertainment',
  'health',
  'other',
];

/// Localised label for a stored category [key]. Unknown/legacy values fall back
/// to the "Other" label so old rows still read sensibly.
String expenseCategoryLabel(AppLocalizations l10n, String key) {
  switch (key) {
    case 'groceries':
      return l10n.expenseCategoryGroceries;
    case 'dining':
      return l10n.expenseCategoryDining;
    case 'transport':
      return l10n.expenseCategoryTransport;
    case 'utilities':
      return l10n.expenseCategoryUtilities;
    case 'household':
      return l10n.expenseCategoryHousehold;
    case 'entertainment':
      return l10n.expenseCategoryEntertainment;
    case 'health':
      return l10n.expenseCategoryHealth;
    default:
      return l10n.expenseCategoryOther;
  }
}
