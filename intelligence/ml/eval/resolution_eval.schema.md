# Resolution eval dataset — schema & curation notes

The dataset that makes "insane correct rate" a **measured** number instead of a
claim. It is the ground truth the resolution engine (plan 037) is scored against,
and the labels the build-time logistic-regression scorer is calibrated on.

- **Location**: `intelligence/ml/data/resolution_eval.jsonl` (one JSON object per line).
- **Starter set**: 22 hand-curated rows committed by plan 037 — enough to wire and
  smoke the harness and capture a first baseline. **Not** enough to fit/trust
  calibrated weights; the maintainer grows it toward a few hundred real rows.
- **Ground truth uses real seed IDs**: every `expected_canonical_id` (and every id
  in `list_context` / `household_purchases`) must exist in
  `frontend/assets/grocery/seed.json`. Validate before committing:
  ```bash
  python3 - <<'PY'
  import json
  ids={it['id'] for it in json.load(open('frontend/assets/grocery/seed.json'))['items']}
  for ln in open('intelligence/ml/data/resolution_eval.jsonl'):
      r=json.loads(ln); 
      for cid in [r['expected_canonical_id'],*r.get('list_context',[]),*r.get('household_purchases',[])]:
          assert cid in ids, cid
  print("ok")
  PY
  ```

## Row schema

| field | type | required | meaning |
|---|---|---|---|
| `raw_text` | string | ✅ | exactly what the OCR/extraction layer emits for one line — pre-resolution. Keep the noise (digits-for-letters, dropped vowels, spurious splits, missing umlauts). |
| `expected_canonical_id` | string | ✅ | the correct seed canonical id this should resolve to. |
| `input_type` | `"print"` \| `"handwriting"` | ✅ | scored **separately** — never blend them into one accuracy number (`intelligence/plan.md §19`). |
| `note` | string | optional | human label of the difficulty/intent (which resolver path it stresses). Documentation only; not scored. |
| `list_context` | string[] | optional | canonical ids already on the current list when this item is being added. Feeds the co-occurrence signal; the prior-dependent cases live or die on this. |
| `household_purchases` | string[] | optional | canonical ids this household has bought before (most-frequent first is fine; the harness counts occurrences). Feeds the purchase-frequency/recency prior. |

## What the metrics mean (computed by the harness)

Scored per `input_type` **and** overall:

- **top-1 accuracy** — did `resolve()`'s chosen candidate equal `expected_canonical_id`? Raw correctness, ignoring confidence.
- **precision@auto-accept** — of the rows the engine *auto-accepted* (score ≥ τ_auto), what fraction were correct. This is the "genius" number — it must approach ~99%.
- **coverage** — fraction of rows auto-accepted. Precision is cheap if you abstain on everything; coverage keeps it honest. The goal is high precision **at** high coverage.
- **calibration** — across score buckets, does predicted P(correct) match observed correctness? A calibrated scorer is what lets τ_auto be *chosen* for a precision target instead of guessed.

## Curation principles

- **Keep the noise real.** `raw_text` is the OCR/extraction output, not a clean
  name. If it's clean, label it `print` and accept it's an easy row.
- **Cover the spread**: clean print, OCR digit/letter noise, dropped-vowel
  shorthand, spurious word splits, missing umlauts, cross-language semantic
  phrasing ("oat drink" → Hafermilch), and **prior-dependent ambiguous prefixes**
  ("ban", "App", "Zuck") that are only resolvable with `list_context` /
  `household_purchases`. The last group is where the ensemble+prior earns its lift
  over the sequential baseline — include enough of them.
- **Handwriting separately.** Don't let a high print score mask a low handwriting
  score; that's why `input_type` is mandatory.
- **One concept per row.** If a line has two items, split it; the extraction layer's
  job to split is evaluated elsewhere.
- **Grow from real data.** The strongest rows come from real scanned/typed lists
  with their true resolutions — add them as they appear. Synthetic noise is a
  starter, not the destination.

## Validating

`python3 intelligence/ml/eval/validate_eval.py` checks the whole file — required
fields and types, the `input_type` enum, every id (including `list_context` /
`household_purchases`) against `seed.json`, and contradictory labels — and exits
non-zero on any violation. It supersedes the ad-hoc snippet above and takes an
optional path, so it also checks a candidate file before review. Run it after
every merge.

## Growing the set from `corrections.jsonl`

`python3 intelligence/ml/eval/mine_resolution_eval.py` maps the corrections
corpus's `correct_canonical_{en,de,fr,es}` **display names** onto seed ids and
writes `data/resolution_eval_candidates.jsonl`.

**It never writes the eval set.** Labels that are only plausible corrupt the
metric they exist to protect, so the maintainer reviews each candidate and moves
rows across by hand. A row is emitted only when the display name maps to exactly
one seed id, **at least two of the row's four languages independently agree on
that id**, the row names a single item, and the text is not labelled two
different ways elsewhere in the corpus — anything ambiguous is skipped and
counted rather than guessed.

The two-language rule is not paranoia. Seed display names collide across
languages: the corpus row `{en: "Bread", fr: "Pain"}` means bread, but no seed
item is named "Bread" while `bread_roll.name_fr` is exactly "Pain" — so a
single-language match silently labels bread as `bread_roll`, and the eval set
would then punish the resolver for being right. Loosen it with
`--min-language-agreement 1` only if you review every row.

What mined rows can and cannot do:

- **`input_type` is always `print`.** The corpus is OCR corrections and carries
  no handwriting signal, so the handwriting half — the weaker of the two scores
  — cannot be grown this way. It still needs real handwritten lists.
- **They carry no prior.** `list_context` and `household_purchases` are empty, so
  `householdFreq` and `listCooccurrence` export as 0. Mined rows are therefore
  capped (`--limit`, default 300); flooding the set with zero-prior rows would
  drown the hand-curated rows that give those two features any signal at all.
- **Most of the corpus is already trivial.** The seed ships ~231k alias pairs, so
  ~77% of mappable corrections texts resolve by exact alias and teach the scorer
  nothing. Of 39,412 rows, ~1,150 are unambiguously mappable *and* non-trivial.
  Mining is a one-off top-up, not a faucet — the miner prints this pool
  breakdown on every run, and the default `--limit 300` deliberately takes well
  under the pool so the review stays finishable.
- **Watch the alias twin.** `mine_corrections_aliases.py` reads the same rows. An
  alias mined from a row and merged into the seed turns that row's eval twin into
  a free exact-alias hit and inflates precision. Those rows are kept (they *are*
  the non-trivial ones) and flagged in their `note`; each carries its
  `correction_id`. Merge the eval row or its alias twin, never both.
- **Rerun after any alias merge.** Trivial detection compares against the seed as
  it exists now. Merge alias candidates and rebuild the seed, and rows that were
  non-trivial in an older candidates file become free exact-alias hits — the
  file does not know it went stale. Regenerate before each review round.

Mined rows carry two extra keys, `source` and `correction_id`. The Dart
`ResolutionEvalCase.fromJson` reads named fields only and ignores the rest, so a
reviewed row can be moved into the eval set verbatim.
