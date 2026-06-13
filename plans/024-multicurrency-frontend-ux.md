# Plan 024: Let a user record an expense in a foreign currency and see balances converted to the household currency

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat fea883d3..HEAD -- frontend/lib/models/finance_models.dart frontend/lib/repositories/finance_repository.dart frontend/lib/sheets/expense_creation_sheet.dart frontend/lib/storage/app_database.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (touches the offline-first outbox path and the local Drift schema)
- **Depends on**: `plans/023-multicurrency-backend-fx.md` (the backend must
  accept and store `base_amount`/`fx_rate` first; this plan sends them)
- **Category**: direction
- **Planned at**: commit `fea883d3`, 2026-06-13

## Why this matters

Plan 023 makes the backend convert foreign-currency expenses to the household's
base currency and compute balances in it. But the frontend currently pins every
expense to the group currency (`expense_creation_sheet.dart:135` sets
`_currency = group.currency` and there is no picker), so the new capability is
unreachable. This plan surfaces it: pick a currency on an expense, enter the FX
rate, see a live "≈ converted" preview, and read the original + converted amount
in the expense list/detail. The conversion contract (splits live in base
currency) is honored end to end.

## Current state

Files and roles:
- `frontend/lib/models/finance_models.dart` — `Expense` and
  `CreateExpenseRequest` (and `UpdateExpenseRequest`) data classes with
  `fromJson`/`toJson`.
- `frontend/lib/repositories/finance_repository.dart` — offline-first writes via
  the outbox; `createExpenseOfflineFirst` enqueues the request JSON, and
  `_syncCreateExpense` reconstructs a `CreateExpenseRequest` from that JSON when
  draining. **Both serialize/deserialize must carry the new fields.**
- `frontend/lib/sheets/expense_creation_sheet.dart` — the creation form;
  `_currency` is fixed to the group currency today.
- `frontend/lib/storage/app_database.dart` — Drift schema; `expensesTable` and
  the `schemaVersion`/migration block (currently at v4 per the offline-sync
  notes — confirm by reading the file).
- `frontend/lib/utils/format_currency.dart` — `formatCurrency(int cents, String code)`
  and `currencySymbol(code)`. Reuse for display.
- `frontend/lib/widgets/app_currency_dropdown.dart` — `AppCurrencyDropdown`
  (label "Currency", the 13-currency list). Reuse for the picker.
- `frontend/lib/sheets/expense_detail_sheet.dart` and
  `frontend/lib/screens/money/expenses_screen.dart` — display surfaces.

Excerpt — current `CreateExpenseRequest.toJson` (`finance_models.dart`):

```dart
  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'payer_id': payerId,
        'amount': amount,
        'description': description,
        'category': category,
        'currency': currency,
        // ...
      };
```

Excerpt — the outbox round-trip that must carry the fields
(`finance_repository.dart`, `createExpenseOfflineFirst` enqueues
`'request': req.toJson()`; `_syncCreateExpense` rebuilds):

```dart
    final req = api.CreateExpenseRequest(
      groupId: requestRaw['group_id'] as String,
      payerId: requestRaw['payer_id'] as String,
      amount: requestRaw['amount'] as int,
      // ...
      currency: requestRaw['currency'] as String? ?? 'USD',
      // ...
    );
```

Excerpt — currency is pinned today (`expense_creation_sheet.dart`):

```dart
  String _currency = 'USD';
  // ...
  _currency = group.currency; // in the group-resolve init
```

Conventions to match (from the project memory + AGENTS.md):
- Money stored as integer cents (`int`). FX rate is a `double`.
- Design system: `AppInput`, `AppButton`, `AppDropdown`/`AppCurrencyDropdown`,
  `MitlistSpacing` tokens, `textTheme` styles — never raw Material widgets or
  hardcoded pixels/colors.
- Amount-entry sheets show currency on the field and a live breakdown — see
  `expense_creation_sheet.dart` `computeSplitSummary` and the `_CurrencyPrefix`
  widget already in that file (memory note in `project_mitlist.md`).
- Offline-first: writes go through the outbox; any new field must survive the
  enqueue→drain round-trip (see `frontend/plans/` and the offline-sync notes).

## The contract from plan 023 (must honor)

- Send `base_amount` (int cents) and `fx_rate` (double) on create/update.
- `base_amount = round(amount * fx_rate)`; when the chosen currency equals the
  group currency, `fx_rate = 1.0` and `base_amount = amount`.
- **Split amounts entered by the user are in BASE currency.** When a non-group
  currency is selected, the split inputs and the live split summary operate on
  `base_amount`, not `amount`. The simplest correct UX: compute `base_amount`
  first, then drive `computeSplitSummary(totalCents: baseAmount, ...)` with the
  base currency for display.

## Commands you will need

| Purpose        | Command (run from `frontend/`)        | Expected            |
|----------------|---------------------------------------|---------------------|
| Codegen (Drift)| `dart run build_runner build --delete-conflicting-outputs` | exit 0; `app_database.g.dart` regenerated |
| Analyze        | `dart analyze lib/`                   | no errors           |
| Tests          | `flutter test`                        | all PASS            |

If `build_runner` is not how this repo regenerates Drift, confirm via
`grep -n "build_runner\|drift_dev" frontend/pubspec.yaml`. If absent, STOP.

## Scope

**In scope**:
- `frontend/lib/models/finance_models.dart`
- `frontend/lib/repositories/finance_repository.dart`
- `frontend/lib/sheets/expense_creation_sheet.dart`
- `frontend/lib/storage/app_database.dart` (+ regenerated `app_database.g.dart`)
- `frontend/lib/sheets/expense_detail_sheet.dart` (display only)
- `frontend/lib/screens/money/expenses_screen.dart` (display only)
- `frontend/test/` — a new widget/unit test (see Test plan)

**Out of scope**:
- Recurring-expense currency UI (backend deferred it in 023).
- Settlement-entry currency (settlements are base-currency by contract).
- Any automatic FX-rate fetching / external API — the rate is user-entered.
- Refactoring the split-summary engine beyond passing it `base_amount`.

## Git workflow

- Branch: `advisor/024-multicurrency-frontend-ux`
- Commit per step; conventional-commit style (e.g.
  `feat: record expenses in a foreign currency with FX conversion`).
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Add `baseAmount`/`fxRate` to the models

In `finance_models.dart`, add `final int baseAmount;` and `final double fxRate;`
to both `Expense` and `CreateExpenseRequest` (and `UpdateExpenseRequest` if it
carries amount/currency). Defaults: `baseAmount` required where `amount` is
required; `fxRate` defaults `1.0`. Wire them into every `fromJson`
(`base_amount` as int with the same `parseJsonInt64` helper used for `amount`;
`fx_rate` as `(json['fx_rate'] as num?)?.toDouble() ?? 1.0`) and `toJson`
(`'base_amount': baseAmount, 'fx_rate': fxRate`).

**Verify**: `dart analyze lib/models/finance_models.dart` → no errors.

### Step 2: Carry the fields through the offline outbox

In `finance_repository.dart`:
- `createExpenseOfflineFirst`: the optimistic local `api.Expense(...)` must set
  `baseAmount: req.baseAmount, fxRate: req.fxRate`.
- `_syncCreateExpense`: when rebuilding `api.CreateExpenseRequest` from
  `requestRaw`, add `baseAmount: requestRaw['base_amount'] as int,`
  `fxRate: (requestRaw['base_amount'] == null) ? 1.0 : (requestRaw['fx_rate'] as num?)?.toDouble() ?? 1.0`.
- `updateExpenseOfflineFirst` / `_syncUpdateExpense`: same treatment for the
  patch path if it carries amount/currency.
- `_toExpensesRow` / `_toExpense`: map the two new columns (added in Step 3).

**Verify**: `dart analyze lib/repositories/finance_repository.dart` → no errors
(it will still error until Step 3 adds the Drift columns — that is expected;
proceed to Step 3 then re-run).

### Step 3: Add the columns to the local Drift schema and bump the version

In `app_database.dart`, add to `ExpensesTable` (match the existing column
style):

```dart
  IntColumn get baseAmount => integer().withDefault(const Constant(0))();
  RealColumn get fxRate => real().withDefault(const Constant(1.0))();
```

Bump `schemaVersion` by one and add a migration `from`-step that
`m.addColumn(expensesTable, expensesTable.baseAmount)` and `...fxRate`, and
backfills `base_amount = amount` for existing rows (a `customStatement`
`UPDATE expenses_table SET base_amount = amount WHERE base_amount = 0;` — use
the actual generated table name). Follow the exact pattern of the previous
migration step in this file (the v3→v4 index migration from plan 013).

Regenerate: `dart run build_runner build --delete-conflicting-outputs`.

**Verify**: codegen exits 0; `dart analyze lib/` → no errors (Steps 2 + 3 now
resolve together).

### Step 4: Currency picker + FX rate + live conversion in the creation sheet

In `expense_creation_sheet.dart`:
- Add state: `double _fxRate = 1.0;` and keep `_currency`.
- Below the amount field, render `AppCurrencyDropdown(value: _currency, onChanged: ...)`.
  Default `_currency` to the group currency (unchanged init).
- When `_currency != group.currency`, reveal an FX-rate `AppInput`
  (numeric, label e.g. `Rate (1 $_currency = ? ${group.currency})`), and show a
  live preview line: `formatCurrency(amount, _currency)` ` ≈ `
  `formatCurrency(baseAmount, group.currency)` where
  `baseAmount = (amount * _fxRate).round()`. When equal, hide the rate field and
  force `_fxRate = 1.0`.
- In `_onCreate`, compute `final baseAmount = (_currency == groupCurrency) ? amount : (amount * _fxRate).round();`
  Pass `totalCents: baseAmount` and `currency: groupCurrency` into
  `computeSplitSummary` (splits are base-currency per the contract). Add
  `baseAmount: baseAmount, fxRate: _currency == groupCurrency ? 1.0 : _fxRate`
  to the `CreateExpenseRequest`.
- Validate `_fxRate > 0` when a foreign currency is selected; block create with
  an inline error otherwise (mirror the existing `_amountError` pattern).

Keep within the design system (no raw widgets; spacing via `MitlistSpacing`).

**Verify**: `dart analyze lib/` → no errors.

### Step 5: Show original + converted in detail/list

In `expense_detail_sheet.dart` and `expenses_screen.dart`, where the amount is
rendered: if `expense.fxRate != 1.0` (or `expense.currency != groupCurrency`),
show both, e.g. `formatCurrency(expense.amount, expense.currency)` with a muted
secondary `≈ formatCurrency(expense.baseAmount, groupCurrency)`. Otherwise show
the single amount as today. Resolve the group currency the same way these
screens already do (they read the active group).

**Verify**: `dart analyze lib/` → no errors.

### Step 6: Tests + full suite (see Test plan).

**Verify**: `flutter test` → all PASS.

## Test plan

- New unit test `frontend/test/finance_models_test.dart` (or extend an existing
  finance test): `CreateExpenseRequest.toJson` includes `base_amount`/`fx_rate`,
  and `Expense.fromJson` round-trips them (incl. the `fx_rate` absent → `1.0`
  default and the `parseJsonInt64` path for `base_amount`).
- If a finance repository/outbox test exists (the offline-sync cycle added
  several under `frontend/test/`), add a case asserting a foreign-currency
  `createExpenseOfflineFirst` enqueues a payload that, when drained via
  `_syncCreateExpense`, reconstructs the request with `baseAmount`/`fxRate`
  intact. Model it after the existing outbox tests
  (`grep -rln "createExpenseOfflineFirst\|_syncCreateExpense\|OutboxDrainer" frontend/test/`).
- Verification: `flutter test` → all PASS including the new test(s).

## Done criteria

ALL must hold:

- [ ] `dart run build_runner build --delete-conflicting-outputs` exits 0
- [ ] `dart analyze lib/` reports no errors
- [ ] `flutter test` all PASS, including the new finance test
- [ ] `grep -n "base_amount" frontend/lib/models/finance_models.dart` shows it in
      both `toJson` and `fromJson`
- [ ] `grep -n "AppCurrencyDropdown" frontend/lib/sheets/expense_creation_sheet.dart`
      returns a match (picker wired)
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The "Current state" excerpts don't match the live code (drift since `fea883d3`).
- The backend (plan 023) is not merged / does not accept `base_amount`/`fx_rate`
  — sending them would be ignored or rejected. Verify 023's status in
  `plans/README.md` first; if it is not DONE, STOP.
- Drift codegen fails or the schema-version bump conflicts with a migration
  added after this plan was written.
- `computeSplitSummary` cannot be driven on `base_amount` without a larger
  refactor than "pass a different total + currency" — report rather than rework
  the split engine.

## Maintenance notes

- The FX rate is **user-entered, captured at create time, and immutable** unless
  the expense is edited. There is intentionally no live-rate fetch (offline-first,
  no-telemetry ethos). If auto-rates are added later, gate them behind an opt-in.
- Reviewer scrutiny: confirm the new fields survive the **offline outbox**
  round-trip (Step 2) — an expense created offline must sync with its
  `base_amount`/`fx_rate` intact, not silently default to `amount`/`1.0`.
- The `exact` split-mode-in-foreign-currency edge (splits entered in base) is the
  most error-prone UX; the live preview in Step 4 is what keeps it honest.
