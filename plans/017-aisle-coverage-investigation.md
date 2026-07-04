# Plan 017: Investigate why aisle coverage is 7% and prepare the fix

> **Executor instructions**: This is an INVESTIGATE plan — its deliverable is a
> report plus small mechanical improvements, not a feature. Follow the steps,
> honor STOP conditions, and when done update `plans/README.md` and write your
> findings into a `## Findings` section appended to THIS file.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- intelligence/ml/build_store_aisles.py intelligence/ml/data/aisles.jsonl frontend/assets/grocery/store_aisles.json`

## Status

- **Priority**: P3
- **Effort**: M (investigation S; the data-generation follow-up costs API money and is a human decision)
- **Risk**: LOW
- **Depends on**: none
- **Category**: data / investigate
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

Store-aisle intelligence (shopping-path sorting on trips and in scan review) only works for items with an aisle row. The shipped asset covers **223 of 3,242 seed items (~7%)** across 808 rows — most items fall into the "Other" bucket, so the feature reads as broken even where it's wired correctly. Two candidate causes, both partially confirmed by reading: the generation step only ever produced ~978 source rows (the README's "~9,600 rows" was the plan, not the run — Prompt 4 was marked "optional"), and the build script drops ~17% of those on name-resolution misses (978 source → 808 asset rows). This plan quantifies both, fixes the mechanical resolution loss, and hands the human a precise, costed re-generation command.

## Current state

- `frontend/assets/grocery/store_aisles.json` — version 1, 808 rows, 223 distinct `canonical_item_id`s, 10+ stores (`de_rewe`, `en_tesco`, `en_kroger_us`, …).
- `intelligence/ml/data/aisles.jsonl` — 978 lines (the generation output that exists).
- `intelligence/ml/build_store_aisles.py` — 87 lines. Resolution logic (lines 32-45): maps source rows to seed ids via normalised `name_en` → `name_de` → `aliases_en/de` fallback; counts an `unresolved` variable (read lines 50-87 for how/whether it reports). **It never consults `name_fr`/`name_es` or `aliases_fr/es`** even though the v5 seed carries all four languages.
- Generation: `intelligence/README.md:42` — Prompt 4 (`run --prompt 4 --all`) produces store-aisle data; `config/batches.yaml` defines the batch matrix; the dashboard/progress DB (`intelligence/progress.db`) records what actually ran. Generation requires `DEEPSEEK_API_KEY` and costs real money (`estimate` subcommand exists).
- Consumers expecting coverage: `frontend/lib/screens/shopping/shopping_trip_screen.dart:171-186` (per-item `getStoreAisle`), scan review's `_refreshAisles`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Rebuild asset | `python3 intelligence/ml/build_store_aisles.py` | writes the asset; prints stats |
| Generation status | `cd intelligence && python3 -m generator.runner status` | shows Prompt 4 batch completion |
| Cost estimate | `cd intelligence && python3 -m generator.runner estimate` | prints cost table |

Do NOT run any `generator.runner run` command — it spends API credit; that decision is the maintainer's.

## Scope

**In scope**:
- `intelligence/ml/build_store_aisles.py` (reporting + resolution improvements)
- This plan file (the Findings section)
- `frontend/assets/grocery/store_aisles.json` — regenerate ONLY if Step 2's script change resolves more of the *existing* source rows (version bump to 2 required — the loader is version-gated, `grocery_seed_loader.dart:102-107`)

**Out of scope**:
- Running data generation (costs money; report the command + estimate instead).
- Any Flutter code.

## Git workflow

- Branch: `advisor/017-aisle-coverage-investigation`
- Commit style: `chore(intelligence): quantify + reduce aisle build resolution loss`

## Steps

### Step 1: Quantify the two losses

1. Generation shortfall: `python3 -m generator.runner status` (from `intelligence/`) — record how many Prompt 4 batches are complete vs defined in `config/batches.yaml`. Also `sqlite3 intelligence/progress.db ".tables"` and inspect if status output is unclear.
2. Resolution loss: run `python3 intelligence/ml/build_store_aisles.py` against the current inputs and record its unresolved count. If the script doesn't print per-store/per-reason detail, add it (unresolved examples, top-20).
3. Distinct-item math: 978 source rows → how many distinct (store, item) pairs, how many distinct items → the ceiling today's data allows even at 0% resolution loss.

### Step 2: Reduce resolution loss mechanically

In `resolve()` (build script lines 40-45): add `name_fr`/`name_es` and `aliases_fr/es` fallbacks; strip parenthetical qualifiers before matching (`norm()` already collapses whitespace — check unresolved examples for patterns like plurals the alias map misses). Rebuild; record the new unresolved count and distinct-item coverage. If coverage improved, bump `ASSET_VERSION` to 2, regenerate the asset, and commit both (script + asset). If the FR/ES fallback resolves nothing (source data is EN/DE-only), say so and revert the asset churn.

### Step 3: Write the Findings + recommendation

Append to this file: the numbers from Steps 1–2, and the go/no-go input for the maintainer: the exact generation command (`python3 -m generator.runner run --prompt 4 --all`), the cost estimate output, and the projected coverage if Prompt 4 completes (distinct items in the batch definitions × observed resolution rate).

**Verify**: `python3 intelligence/ml/build_store_aisles.py` exits 0 and prints the new stats; `git status` shows only in-scope files

## Done criteria

- [ ] Findings section appended with: batches complete/total, unresolved before/after, distinct-item coverage before/after, generation cost estimate
- [ ] Build script reports unresolved counts + examples on every run
- [ ] If the asset was regenerated: version bumped to 2 and row/item counts increased
- [ ] `plans/README.md` status row updated

## STOP conditions

- `progress.db` is absent or unreadable → report generation status as "unknown" and continue with resolution-loss work only.
- Rebuilding the asset changes rows for items that were previously resolved (regression in resolve()) → do not commit the asset; report the diff.
- Any temptation to run generation "just a little" — no. Report the command.

## Maintenance notes

- Once the maintainer runs Prompt 4 to completion, the fix is: rebuild via this script, bump version, commit — the loader reseeds automatically.
- Plan 012's parity-checker pattern applies here too: a coverage gate (`distinct aisle items / seed items > X%`) could join CI once coverage is intentional rather than accidental.

## Findings

Run date: 2026-07-03.

### Generation status

`cd intelligence && python3 -m generator.runner status` reports Prompt 4 as complete:

- Prompt 4: 4/4 batches complete
- Rows generated: 978
- Recorded Prompt 4 cost: $0.0484
- Current estimate for Prompt 4: 4 batches, about $0.11 with `deepseek-chat`

`sqlite3` is not installed in this environment, so the progress database was not inspected directly. The runner status output was clear enough to use as the source of truth.

### Source-data ceiling

The committed `intelligence/ml/data/aisles.jsonl` has:

- 978 source rows
- 15 stores
- 973 distinct `(store, canonical_name_en)` source pairs
- 396 distinct English source names, 268 German, 319 French, 282 Spanish

Even with perfect resolution, the current source only covers a few hundred seed items. The low shipped coverage is primarily a data breadth problem, not just a resolver problem.

### Resolution before/after

Before this plan's script change, rebuilding against the current seed resolved:

- 823/978 rows
- 155 unresolved
- 84% row resolution

After adding FR/ES name and alias fallback plus parenthetical stripping:

- 871/978 rows
- 107 unresolved
- 89% row resolution
- 233 distinct canonical items
- 851 distinct resolved store/item pairs

The asset was regenerated as `store_aisles.json` version 2 because row and item coverage increased.

### Remaining unresolved examples

Top examples printed by the builder include item variants still absent from the seed or aliases: clementines, cherry tomatoes, vine tomatoes, yellow/green bell pepper, red/green chili, red kuri squash, butternut squash, romanesco, pointed cabbage, celery stalks, spring onions, turmeric, green olives, and several milk/curd variants.

### Recommendation

Do not spend API credit on more Prompt 4 generation until the maintainer decides whether the intended aisle vocabulary should include these finer product variants or whether they should map to broader seed items. The next paid command, if approved, is:

```bash
cd intelligence
python3 -m generator.runner run --prompt 4 --all
```

Because Prompt 4 is already complete locally, use `--force` only if the maintainer explicitly wants to regenerate existing aisle rows:

```bash
python3 -m generator.runner run --prompt 4 --all --force
```

Projected coverage from merely rerunning the same 4 Prompt 4 batches is low: at the observed 89% resolution rate, the existing source shape supports roughly 870 rows and about 230 distinct seed items. Meaningful coverage improvement requires expanding the Prompt 4 batch definitions or prompt output target, then rebuilding with this script.
