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
