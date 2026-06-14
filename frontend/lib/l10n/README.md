# Flutter localization conventions

## Where things live

| File | Purpose |
|------|---------|
| `lib/l10n/app_en.arb` | English strings (template — always edit here first) |
| `lib/l10n/app_de.arb` | German translations |
| `lib/l10n/app_localizations.dart` | **Generated** — do not edit manually |

## Adding a string

1. Add the key + an `@`-description to `app_en.arb`:
   ```json
   "listEmptyState": "No items yet. Add one above.",
   "@listEmptyState": { "description": "Shown when a shopping list has no items" },
   ```
2. Add the same key (no `@`-entry needed) to `app_de.arb`:
   ```json
   "listEmptyState": "Noch keine Einträge. Oben hinzufügen.",
   ```
3. Regenerate: `flutter gen-l10n` (or `flutter pub get` if using `generate: true`).
4. Reference in code:
   ```dart
   final l10n = AppLocalizations.of(context)!;
   Text(l10n.listEmptyState)
   ```

## Key naming convention

`<screenOrFeature><Thing>` in camelCase. Examples:

- `welcomeTagline` — WelcomeScreen tagline
- `listEmptyState` — ListDetail empty state
- `expenseDeleteConfirm` — ExpenseDetailSheet delete confirmation

## What NOT to localize

- The brand name **`mitlist`** — always a string literal, never a key.
- Error messages routed through `friendlyErrorMessage(e)` — these are already user-facing but come from error classification, not UI strings.
- Developer-facing strings, log output, route names.

## Placeholders and plurals

For dynamic values use ICU message syntax in the ARB file and add a `@`-entry with `placeholders`:

```json
"itemCount": "{count, plural, =0{No items} =1{1 item} other{{count} items}}",
"@itemCount": {
  "description": "Item count with plural forms",
  "placeholders": { "count": { "type": "num", "format": "compact" } }
}
```

Full reference: https://docs.flutter.dev/ui/accessibility-and-internationalization/internationalization

## Adding a new language

1. Create `lib/l10n/app_<locale>.arb` with all keys from `app_en.arb`.
2. Add the locale to `AppLocalizations.supportedLocales` — this is done automatically
   by `flutter gen-l10n` from the presence of the new `.arb` file.
3. Run `flutter gen-l10n`.

## Incremental rollout

This pipeline was bootstrapped with `WelcomeScreen` as the reference. Convert other
screens one at a time: one PR per screen, add only that screen's keys to both ARB
files, run `flutter gen-l10n`, replace the literals.
