# Plan 023: `formatCurrency` renders zero-decimal currencies correctly

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- frontend/lib/utils/format_currency.dart`
> If it changed, compare the excerpt below to the live code first; on mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

`formatCurrency` divides the stored integer amount by 100 and always formats with
two decimal places. That is correct for USD/EUR/etc., but wrong for zero-decimal
currencies (JPY, KRW, HUF, and others) that have no minor unit. A ¥500 amount
renders as "¥5.00" or "¥500.00" depending on how the backend stores it — either
a 100× magnitude error or a nonsensical decimal. This is a visible money-display
bug on the finance screens for any household using a zero-decimal currency.

## Current state

```dart
// frontend/lib/utils/format_currency.dart:1-11
String formatCurrency(int cents, String currencyCode) {
  final isNegative = cents < 0;
  final absCents = cents.abs().clamp(0, 999999999);
  final symbol = currencySymbol(currencyCode);
  final value = (absCents / 100).toStringAsFixed(2);   // ← always /100, always 2dp
  final prefix = isNegative ? '-' : '';
  if (_postfixCurrencies.contains(currencyCode.toUpperCase())) {
    return '$prefix$value $symbol';
  }
  return '$prefix$symbol$value';
}
```
`currencySymbol` (`format_currency.dart:16-67`) already knows JPY (`¥`), KRW
(`₩`), HUF (`Ft`), CNY (`¥`). `_postfixCurrencies` (`:69-75`) is the symbol-
placement set (SEK/NOK/DKK/PLN/CZK) — unrelated to decimals; do not overload it.

**Key open question — how does the backend store zero-decimal amounts?**
The parameter is named `cents` and every caller passes an integer minor-unit
amount. You must determine whether the backend stores JPY as whole yen (amount =
500 for ¥500) or as "cents" (amount = 50000). Check the Go finance model/service
for any currency-aware scaling. If the backend already stores JPY as whole yen
(no ×100), then the fix is: for zero-decimal currencies, do **not** divide by 100
and do **not** add decimals. If the backend stores everything ×100 uniformly, the
fix is: divide by 100 but render with 0 decimals. Resolve this before Step 1 —
see STOP conditions.

## Commands you will need

| Purpose  | Command                                             | Expected |
|----------|-----------------------------------------------------|----------|
| Analyze  | `cd frontend && dart analyze lib/`                  | `No issues found!` |
| Test     | `cd frontend && flutter test test/utils/` (or wherever the new test lands) | pass |
| Backend grep | `grep -rn "currency" backend/internal/services/finance_service.go backend/internal/models/` | inspect for scaling |

## Scope

**In scope**:
- `frontend/lib/utils/format_currency.dart`
- `frontend/test/utils/format_currency_test.dart` (create; adjust folder to match repo test layout)

**Out of scope**:
- The backend money storage/model — do NOT change how amounts are stored. This
  plan is display-only. If you discover a storage bug, STOP and report it.
- `currencySymbol` glyphs — they are correct.

## Git workflow

- Branch: `advisor/023-currency-zero-decimal`
- Conventional commit: `fix(money): format zero-decimal currencies without a minor unit`.

## Steps

### Step 0 (investigate, no code change): determine backend scaling

Read `backend/internal/services/finance_service.go` and the finance model for any
currency-aware multiply/divide. Confirm whether zero-decimal amounts are stored
scaled ×100 or as whole units. Write the answer into the new test file's header
comment so the assertion values are justified.

### Step 1: Add a zero-decimal currency set and branch on it

Add a `const _zeroDecimalCurrencies = { 'JPY', 'KRW', 'HUF', 'CLP', 'ISK', ... }`
(use the standard ISO 4217 zero-decimal list; at minimum the ones with symbols
already defined: JPY, KRW, HUF). In `formatCurrency`, when
`currencyCode.toUpperCase()` is in that set, format the integer amount without
decimals — divided by 100 or not, per the Step 0 finding. Keep the existing
prefix/postfix symbol placement logic unchanged.

**Verify**: `cd frontend && dart analyze lib/` → `No issues found!`

### Step 2: Tests

Create `format_currency_test.dart` (mirror an existing test under
`frontend/test/`). Cover:
- USD 12345 → `$123.45` (unchanged behavior — regression guard).
- JPY 500 (using the storage convention from Step 0) → `¥500` (no decimals).
- KRW and HUF one case each.
- Negative JPY → `-¥500`.
- A postfix currency (e.g. SEK) still places the symbol after.

**Verify**: `cd frontend && flutter test <new test path>` → all pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd frontend && dart analyze lib/` exits 0
- [ ] `grep -n "_zeroDecimalCurrencies\|zeroDecimal" frontend/lib/utils/format_currency.dart` → present
- [ ] New test file exists; the JPY/KRW/HUF and USD-regression cases pass
- [ ] `cd frontend && flutter test <new test path>` exits 0
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- Step 0 reveals the backend stores zero-decimal currencies inconsistently, or
  that the true fix requires a backend change — this plan is display-only.
- The excerpt no longer matches the live `format_currency.dart` (drift).

## Maintenance notes

- If the backend later normalizes all currencies to a single scaling, revisit
  this branch.
- Reviewer: verify the assertion values in the test against the Step 0 storage
  finding — the whole correctness of the fix rests on that convention.
