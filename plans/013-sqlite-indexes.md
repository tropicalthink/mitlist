# Plan 013: Add indexes to the Drift database's hot query columns (schema v4)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9c9b04f3..HEAD -- frontend/lib/storage/app_database.dart`
> On a mismatch with "Current state", treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW (additive DDL; index creation is safe on existing data)
- **Depends on**: plans/009-frontend-test-baseline.md
- **Category**: perf
- **Planned at**: commit `9c9b04f3`, 2026-06-11

## Why this matters

The local Drift/sqlite cache has **zero indexes** (`grep -in "index" lib/storage/app_database.dart`
matches nothing). Every watch stream — `watchListsByGroup`, `watchItemsByList`,
expenses/chores/pinwall by group — full-scans its table, and these queries re-run
on every SSE event, outbox drain, and pull-to-refresh. Cheap, mechanical fix.

## Current state

- `frontend/lib/storage/app_database.dart` — all table definitions and queries.
  `schemaVersion => 3` (:305). Migration pattern (:308–330): `MigrationStrategy`
  with `onCreate: (m) async => m.createAll()` and an `onUpgrade` using raw
  `customStatement(...)` blocks gated by `if (from < N)`.
- Hot query sites (verify each, then derive the index list from the actual
  `where` clauses — do not trust this list blindly):
  - `watchListsByGroup` / lists by `group_id` (~:359)
  - `watchItemsByList` / items by `list_id` (~:379)
  - expenses by `group_id` (~:549), finance summaries (~:566), chores cache
    (~:644), pinwall cache (~:672), hub caches (~:588, :696)
  - `outbox_ops` ordered scans (drain reads oldest first — check the orderBy)
  - `item_cooccurrence_table` / `purchase_history_table` lookups (~:1005)
- Drift supports indexes either via `@TableIndex(...)` annotations on table
  classes (requires build_runner regeneration of `app_database.g.dart`) or via
  raw `CREATE INDEX` customStatements in the migration. **Use raw
  `CREATE INDEX IF NOT EXISTS` statements** in both `onCreate` (after
  `m.createAll()`) and a new `if (from < 4)` block in `onUpgrade` — this matches
  the repo's existing raw-SQL migration style and avoids regenerating the 12k-line
  `.g.dart` file. Extract the statements into a single
  `Future<void> _createIndexes()` helper called from both places.

## Commands you will need

| Purpose | Command (run in `frontend/`) | Expected on success |
|---------|------------------------------|---------------------|
| Deps    | `flutter pub get`            | exit 0              |
| Analyze | `dart analyze lib/`          | exit 0              |
| Tests   | `flutter test`               | all pass            |

## Scope

**In scope**:
- `frontend/lib/storage/app_database.dart` only (schemaVersion bump 3→4,
  `_createIndexes()` helper, onCreate/onUpgrade wiring)
- A small migration test under `frontend/test/`

**Out of scope**:
- `app_database.g.dart` — must not need regeneration with the raw-SQL approach;
  if your approach requires build_runner, you picked the wrong approach.
- Query/table definitions themselves; any data migration.

## Git workflow

- Branch: `perf/sqlite-indexes` off `new-main-fr`.
- One conventional commit (`perf: index hot query columns in local database (schema v4)`).
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Derive the index list from real queries

Read every `select(...)..where(...)` and `customSelect` in `app_database.dart`;
list each (table, column(s)) pair used for filtering in a watch/hot path. Expected
shape (confirm against code): `lists_table(group_id)`, `list_items_table(list_id)`,
`expenses_table(group_id)`, `finance_summaries(group_id)`,
`current_chores_caches(group_id)`, `pinwall_posts_caches(group_id)`,
`hub_group_caches(group_id)`, `hub_activity_caches(group_id)`,
`outbox_ops(created_at)`, `item_cooccurrence_table(group_id, item_a_id)` or as
queried, `purchase_history_table(group_id)`. Use the real snake_case table/column
names from the generated schema (check the `.named(...)` overrides in table defs).

### Step 2: Implement

Bump `schemaVersion` to 4. Add `_createIndexes()` issuing
`CREATE INDEX IF NOT EXISTS idx_<table>_<col> ON <table>(<col>);` per pair.
Call it at the end of `onCreate` and in `onUpgrade` under `if (from < 4)`.

**Verify**: `dart analyze lib/` → exit 0.

### Step 3: Migration test

New test (in-memory DB harness pattern from `frontend/test/frontend_flows_test.dart:~995`):
open a fresh `AppDatabase`, run
`customSelect("SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'")`
and assert the expected index names exist. (Fresh DB exercises onCreate; the
onUpgrade path shares the same helper, and `IF NOT EXISTS` makes double-apply safe.)

**Verify**: `flutter test` → all pass including the new test.

## Done criteria

- [ ] `dart analyze lib/` exits 0; `flutter test` exits 0
- [ ] `schemaVersion` is 4; `grep -c "CREATE INDEX IF NOT EXISTS" frontend/lib/storage/app_database.dart` ≥ 8
- [ ] Index test passes
- [ ] Only in-scope files modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `schemaVersion` is no longer 3 (someone else migrated — renumber carefully).
- Any hot query filters on a column you can't find in the schema (naming drift).

## Maintenance notes

- New filtered watch queries should get an index in the same helper + a new
  `from < N` block.
- Reviewer: confirm both onCreate and onUpgrade paths create the indexes, and
  that no `@TableIndex` was added (would silently require codegen).
