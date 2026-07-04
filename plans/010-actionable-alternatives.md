# Plan 010: Make resolver alternatives actionable — ids end-to-end, one tap on the tile

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- frontend/lib/services/scan/canonical_resolver_service.dart frontend/lib/services/scan/resolution/ensemble_resolver.dart frontend/lib/services/scan/scan_models.dart frontend/lib/services/scan/scan_pipeline_service.dart frontend/lib/screens/scanner/scan_review_screen.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/003-correction-write-integrity.md (uses its `userConfirmed` flag so a tapped alternative counts as a confirmed correction)
- **Category**: bug / ux
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

The ensemble computes ranked alternatives for every scanned line, but they surface only inside the item-editor sheet — one modal deep — and even there, tapping a "did you mean" chip **only replaces the display text**; the canonical id keeps pointing at the wrong item. So the resolver's second-best candidate is (a) nearly invisible and (b) broken when found: the item saves with alternative's name but the loser's canonical link, which then feeds wrong aisle sorting and — worse — a wrong alias correction. Root cause: `alternatives` travel as bare display names with no ids. This plan carries `(id, name)` pairs end-to-end and renders one-tap alternative chips directly on review/ask tiles.

## Current state

- `frontend/lib/services/scan/canonical_resolver_service.dart:9-25` — `ResolveResult.alternatives` is `List<String>`.
- `frontend/lib/services/scan/resolution/ensemble_resolver.dart:70-81` — the ensemble has the ids in hand and throws them away:

```dart
    final alternatives =
        scored.skip(1).take(3).map((s) => _preferredName(s.c.item)).toList();
```

- Legacy path fills names too: `canonical_resolver_service.dart:154-158` (fuzzy second-best) and `:201` (classifier `preds.skip(1).map((p) => p.label)` — labels are canonical names, ids resolvable via alias lookup, but for the legacy path an empty alternatives list is acceptable — see Step 2).
- `frontend/lib/services/scan/scan_models.dart:55+` — `GroceryPrediction.alternatives` is `List<String>`.
- `frontend/lib/services/scan/scan_pipeline_service.dart:142` (approx) — copies `resolve.alternatives` into the prediction.
- The only render — `scan_review_screen.dart:1031-1049`, inside `_ItemEditorSheet`:

```dart
        if (widget.prediction.alternatives.isNotEmpty) ...[
          Text(l10n.scanReviewDidYouMean, ...),
          Wrap(
            children: widget.prediction.alternatives
                .map((alt) => ActionChip(
                      label: Text(alt),
                      onPressed: () => _nameCtrl.text = alt,   // ← name only, id unchanged
                    ))
```

- The tile (`scan_review_screen.dart:744-856`) shows a state dot + "best guess" but no alternatives affordance; `review`/`ask` items require opening the editor.
- Edits funnel through `_updateItem(index, updated)` (line 259), which after Plan 003 sets `userConfirmed` when canonical id or display name changed.
- Design system: chips are `AppChip` (`frontend/lib/widgets/chip.dart`); note the editor sheet currently uses raw Material `ActionChip` — replace with `AppChip` while you're in there (AGENTS.md anti-pattern list forbids raw Material equivalents where a design-system component exists).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze | `cd frontend && dart analyze lib/` | exit 0 |
| Tests | `cd frontend && flutter test test/services/` | pass |
| Full | `cd frontend && flutter test` | pass |

## Scope

**In scope**:
- `frontend/lib/services/scan/canonical_resolver_service.dart` (ResolveResult shape)
- `frontend/lib/services/scan/resolution/ensemble_resolver.dart`
- `frontend/lib/services/scan/scan_models.dart`
- `frontend/lib/services/scan/scan_pipeline_service.dart`
- `frontend/lib/screens/scanner/scan_review_screen.dart`
- `frontend/test/services/` (touch-ups where the List<String> shape is asserted)

**Out of scope**:
- l10n additions — reuse the existing `scanReviewDidYouMean` string for the tile chips.
- The composer/typing surface — that's direction work (Plan 018-adjacent), not this fix.
- Shopping-trip screen (uses `.canonicalItemId` only; alternatives unused there).

## Git workflow

- Branch: `advisor/010-actionable-alternatives`
- Commit style: `feat(scan): alternatives carry canonical ids; one-tap correction on review tiles`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: New value type + ResolveResult change

In `canonical_resolver_service.dart`, add next to `ResolveResult`:

```dart
/// A ranked runner-up resolution the user can switch to in one tap.
class ResolveAlternative {
  final String canonicalItemId;
  final String displayName;
  const ResolveAlternative({required this.canonicalItemId, required this.displayName});
}
```

Change `ResolveResult.alternatives` to `List<ResolveAlternative>` (keep the field name).

### Step 2: Fill it with ids

- `ensemble_resolver.dart:70-72`:

```dart
    final alternatives = scored
        .skip(1)
        .take(3)
        .map((s) => ResolveAlternative(
              canonicalItemId: s.c.canonicalItemId,
              displayName: _preferredName(s.c.item),
            ))
        .toList();
```

- Legacy path (`canonical_resolver_service.dart`): the fuzzy second-best at lines 154-158 has `alt.id` available — wrap it. The classifier-fallback alternatives at line 201 have labels but no resolved ids — return `const []` there instead (a name without an id is exactly the bug this plan removes; the legacy path is not the production scan path).

**Verify**: `cd frontend && dart analyze lib/` → reports the remaining `List<String>` consumers as errors — that's your worklist for Step 3; no *other* categories of error should appear

### Step 3: Thread through the prediction and pipeline

- `scan_models.dart`: `GroceryPrediction.alternatives` → `List<ResolveAlternative>` (import the type; keep `copyWith` handling).
- `scan_pipeline_service.dart`: the copy site compiles unchanged once types align.
- Fix any test compile errors in `frontend/test/services/` by constructing `ResolveAlternative(...)` where strings were asserted; assert on `.displayName` to keep the tests' meaning.

**Verify**: `cd frontend && dart analyze lib/` → exit 0; `flutter test test/services/` → pass

### Step 4: One-tap chips on the tile

In the review tile (`_ReviewItemTile`-equivalent around `scan_review_screen.dart:744-856`): when `needsAction && prediction.alternatives.isNotEmpty`, render below the existing title row a horizontal `Wrap` of up to 3 `AppChip`s, label `alt.displayName`, whose tap applies the alternative through the existing funnel:

```dart
    onSelected: (_) => onChanged(prediction.copyWith(
      displayName: alt.displayName,
      canonicalItemId: alt.canonicalItemId,
      confidenceLevel: ConfidenceLevel.autoAccept,
      confidenceScore: 1.0,
    )),
```

(The tile already receives `onChanged` → `_updateItem`; Plan 003's funnel marks this `userConfirmed`, so the tapped alternative becomes a real correction on add-to-list.) Keep the tile compact: chips only for `review`/`ask` states, single row, overflow-safe (`Wrap` with `runSpacing`, or a horizontal `ListView` at fixed height like the composer does — match `list_composer_bar.dart:63-75`).

### Step 5: Fix the editor sheet chips

In `_ItemEditorSheet` (line 1031+): chips now iterate `ResolveAlternative`s; on press, set BOTH `_nameCtrl.text = alt.displayName` AND stash the id in a local `String? _selectedAltId`, and in `_save` (line 984) include `canonicalItemId: _selectedAltId ?? widget.prediction.canonicalItemId`. If the user edits the name after tapping a chip, clear `_selectedAltId` (a hand-typed name is not the alternative anymore) — hook `_nameCtrl.addListener`. Replace `ActionChip` with `AppChip`.

**Verify**: `cd frontend && dart analyze lib/` → exit 0; `cd frontend && flutter test` → pass

### Step 6: Widget test

Add `frontend/test/widgets/scan_review_alternatives_test.dart` (pattern: pump the tile widget directly if it's a standalone class, else the screen with a fake prediction list): a prediction in `review` state with one alternative → chip visible; tap → `onChanged` called with the alternative's id AND `ConfidenceLevel.autoAccept`.

**Verify**: `cd frontend && flutter test test/widgets/scan_review_alternatives_test.dart` → pass

## Test plan

- Step 6 widget test (tile chip applies id + state).
- Editor-sheet regression: chip tap then save → prediction carries the alternative id; chip tap then manual name edit then save → original id kept, typed name kept (the listener-clear case).
- Existing suites in `test/services/` re-pass after the type change.

## Done criteria

- [ ] `grep -n "List<String> alternatives\|alternatives = const \[\]" frontend/lib/services/scan/scan_models.dart frontend/lib/services/scan/canonical_resolver_service.dart` → no `List<String>` alternatives remain
- [ ] `grep -n "ActionChip" frontend/lib/screens/scanner/scan_review_screen.dart` → no matches
- [ ] New widget test passes; `cd frontend && flutter test` exits 0
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Plan 003's `userConfirmed` flag is absent from `GroceryPrediction` — dependency not landed; tapped alternatives would silently skip correction learning.
- The tile widget receives predictions but no `onChanged` callback (structure changed) — report the actual wiring.
- The type change fans out beyond the five in-scope lib files (someone else consumes `alternatives`) — list the extra consumers and stop.

## Maintenance notes

- Alternatives now carry ids — Plan 018's typing-surface work can reuse `ResolveAlternative` directly.
- Reviewer should scrutinize: the editor sheet's stale-id clearing (Step 5) and that legacy-path classifier alternatives were dropped, not id-faked.
