# Plan 039: Share the note-card and stat-row widgets between pinwall section and board

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- frontend/lib/widgets/hub/pinwall_section.dart frontend/lib/screens/pinwall/pinwall_board_screen.dart`
> On any change, re-read both files before starting; on material mismatch, STOP.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED (two variants with different chrome; shared widget needs params)
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

`hub/pinwall_section.dart` (1700 lines) and `pinwall_board_screen.dart` (1869
lines) each re-implement the same pinwall concepts — note cards, quick stat rows,
a "tonight" ticket, a composer — in two divergent code paths (`_PinwallNoteCard`
vs `_BoardNoteCard`, `_*StatRow` vs `_BoardStatsCard`). 3.4k lines across two
files means every pinwall behavior or design change must be made twice and can
drift. Extracting the shared pieces into parameterized widgets removes the
duplication while keeping each surface's distinct chrome.

## Current state

- `frontend/lib/widgets/hub/pinwall_section.dart` — defines `_PinwallNoteCard`
  (~lines 1185–1696) and stat rows `_ChoresStatRow`/`_FinanceStatRow`/
  `_ListsStatRow`/`_TonightStatRow`. Imports `pinwall_board_screen.dart`
  (`pinwall_section.dart:20`).
- `frontend/lib/screens/pinwall/pinwall_board_screen.dart` — defines a parallel
  `_BoardNoteCard` (~1015–1241), `_BoardStatsCard`, `_BoardTonightTicket`.

Read both classes side by side before extracting. The **board** variant has
cork-canvas / draggable styling the **section** variant lacks — that chrome must
stay board-only; only the shared body (note content, stat presentation) is
extracted with variant parameters.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Analyze | `cd frontend && dart analyze lib/` | `No issues found!` |
| Test | `cd frontend && flutter test` | pass (sqlite-env note may apply) |

## Scope

**In scope**:
- `frontend/lib/widgets/hub/pinwall_section.dart`
- `frontend/lib/screens/pinwall/pinwall_board_screen.dart`
- New shared widgets under `frontend/lib/widgets/pinwall/` (create the folder),
  e.g. `pinwall_note_card.dart`, `pinwall_stat_rows.dart`
- `frontend/test/widgets/pinwall/` tests for the extracted widgets (create)

**Out of scope**:
- The board's drag/cork-canvas behavior — keep it in the board screen.
- Pinwall data/services — presentation only.
- Behavior changes — the two surfaces must look and behave as they do now.

## Git workflow

- Branch: `advisor/039-pinwall-shared-widgets`
- Commit per extracted widget; conventional commits, e.g.
  `refactor(pinwall): extract shared PinwallNoteCard`.

## Steps

### Step 0: Diff the two note-card implementations

Read `_PinwallNoteCard` and `_BoardNoteCard` and identify the shared body vs the
variant-specific parts. Write down (in the PR description or a scratch note) which
parameters the shared widget needs to cover both. If they have diverged so far
that < ~40% is genuinely shared, STOP and report — a forced shared widget with a
dozen flags is worse than two.

### Step 1: Extract the shared note card

Create `frontend/lib/widgets/pinwall/pinwall_note_card.dart` with a
parameterized `PinwallNoteCard` covering the common body; expose the board-only
chrome via composition (the board wraps the shared card in its cork/draggable
container) or a `variant` enum/flags for the small differences. Replace
`_PinwallNoteCard` and `_BoardNoteCard` usages with the shared widget.

**Verify**: `cd frontend && dart analyze lib/` → `No issues found!`; visually
identical is verified by the widget test in Step 3.

### Step 2: Extract the shared stat rows

Do the same for the stat-row family (`_*StatRow` and `_BoardStatsCard`
presentation) into `pinwall_stat_rows.dart`.

**Verify**: `cd frontend && dart analyze lib/` → `No issues found!`

### Step 3: Tests

Add widget tests under `frontend/test/widgets/pinwall/` that mount the shared
`PinwallNoteCard` and stat rows with sample data and assert they render the key
content. Model on any existing widget test (e.g.
`frontend/test/widgets/list_composer_canonical_test.dart`).

**Verify**: `cd frontend && flutter test test/widgets/pinwall/` → pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd frontend && dart analyze lib/` exits 0
- [ ] `frontend/lib/widgets/pinwall/pinwall_note_card.dart` exists and is used by BOTH the section and the board (grep both files import it)
- [ ] `grep -n "_PinwallNoteCard\|_BoardNoteCard" frontend/lib` → the duplicated private classes are gone (or reduced to thin board-chrome wrappers)
- [ ] New widget tests exist and pass
- [ ] `cd frontend && flutter test` passes (only the known welcome-screen case may fail)
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- Step 0 shows the two implementations share too little to justify a shared widget
  — report the overlap estimate; do not force it.
- Extraction requires touching pinwall services/providers — presentation only;
  STOP if data logic must move.

## Maintenance notes

- The board keeps its cork/drag chrome; only the body is shared. Future pinwall
  design changes now happen once.
- Reviewer: verify both surfaces render identically to before (the widget tests +
  a manual look), and that board-only chrome didn't leak into the shared widget.
