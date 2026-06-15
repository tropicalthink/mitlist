# Plan 037: The genius resolution engine — calibrated ensemble + household prior + eval harness

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, stop and report — do not improvise. When done, update
> the status row in `plans/README.md` unless a reviewer told you they maintain it.
>
> **Read first**: `plans/INTELLIGENCE-NORTH-STAR.md` and `intelligence/plan.md §5`
> (selection signals) and `§19` (eval & metrics). This plan finally builds the
> §5 "selection signals in order of weight" model that was specified and never
> implemented, and the §19 eval harness that makes accuracy a measurable number.
>
> **Drift check (run first)**:
> `git diff --stat 45ae60c2..HEAD -- frontend/lib/services/scan/canonical_resolver_service.dart frontend/lib/services/scan/confidence_service.dart frontend/lib/services/scan/scan_pipeline_service.dart`
> On a mismatch with the excerpts below, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: XL
- **Risk**: MED (additive behind a feature flag; old path stays until eval proves the new one wins)
- **Depends on**: 026 (classifier), 028 (embedder), 031 (purchase history). All shipped.
- **Category**: direction (intelligence — accuracy)
- **Planned at**: commit `45ae60c2`, 2026-06-15

## Why this matters

The maintainer's goal is not "a system that runs" — it is **a genius system with
an insane correct rate**. The current resolver structurally cannot get there:

1. **Sequential first-hit, not an ensemble.** `resolve()` tries exact alias →
   fuzzy → classifier → embedder and returns the first thing over `0.85`. The
   four resolvers never vote. Disagreement between them — the richest "I'm
   unsure" signal there is — is discarded.
2. **The confidence number is meaningless.** Fuzzy score is `1 − editDistance`,
   classifier score is a softmax, embedder score is a cosine. Three incompatible
   scales, all compared against the same hardcoded `0.85` (`confidence_service.dart`).
   `confidenceScore` does **not** predict P(correct), so the system cannot tell
   when it is right — and "knows when it is unsure" is the entire game.
3. **The household prior — the biggest accuracy lever — is unused.** `resolve()`
   matches against the *global* alias table. It never weights by what **this
   household actually buys** (`purchase_history`, already collected) nor by the
   **current list** (`item_cooccurrence`, already collected). Resolving "ban" on a
   list that already holds milk + bread should yield Bananas, not Band-Aids. That
   collapse from 3,239 global candidates to the ~200 this household buys is where
   the correct rate goes from good to insane. `intelligence/plan.md §5` specifies
   exactly this and it was never built.
4. **No measurement.** There is no eval set. "Insane correct rate" is currently
   an unfalsifiable claim; you cannot drive a number you do not compute.

This plan rebuilds resolution as **candidate-generation → one calibrated scorer →
an explicit abstention decision**, fuses the household prior + list context +
source agreement, and ships the **eval harness that proves the number moved** —
in lockstep (the maintainer chose "both together"). Everything stays **on-device
/ build-time** (the maintainer chose "hold on-device, period"): the scorer is a
logistic-regression head (a few dozen weights) fit at build time and run as a
pure-Dart dot-product + sigmoid. Zero per-prediction cost. Handwriting
*recognition* accuracy (the ML Kit ceiling) is explicitly **out of scope** here —
that is the deferred on-device-VLM track (032 phase 2). This plan maximises
accuracy on the text→canonical half, which is fully winnable on-device.

## Architecture (read before coding)

```
rawText, groupId, currentListCanonicalIds
  → CandidateGenerator        (union of ALL sources; each remembers who proposed it)
  → FeatureExtractor          (per candidate: a fixed-length feature vector)
  → CalibratedScorer          (logistic regression → P(correct) ∈ [0,1])
  → Decision                  (argmax; auto-accept ≥ τ_auto, review ≥ τ_review, else ask)
```

**Candidate sources** (union, de-duped by `canonicalItemId`):
- household exact-alias hit(s)
- global exact-alias hit(s)
- fuzzy alias top-k (existing `getAliasFuzzyCandidates`)
- classifier top-k (existing `GroceryClassifierService.classify`)
- embedder top-k (existing `StaticEmbeddingService.nearest`)

**Per-candidate features** (the §5 selection signals, one fixed-order `List<double>`):
| # | feature | source |
|---|---|---|
| 0 | best string similarity `1 − normEdit` over its aliases | fuzzy |
| 1 | classifier softmax prob (0 if not proposed) | classifier |
| 2 | embedder cosine (0 if not proposed) | embedder |
| 3 | source-agreement count / 5 | generator |
| 4 | is-household-confirmed-alias (0/1) | corrections |
| 5 | household purchase frequency (normalised) | `getGroupPurchaseHistory` |
| 6 | recency: 1/(1+daysSinceLastPurchase) | `getGroupPurchaseHistory` |
| 7 | current-list co-occurrence score (normalised) | `getTopCooccurrences` |
| 8 | exact-match bit (rawText == an alias) | generator |

**Scorer**: `P = sigmoid(w · features + b)`. `w`/`b` are shipped as a **versioned
bundle** (`resolution_weights.json`, ~10 floats) fit at build time on the eval
set. Pure-Dart inference. A hand-set default weight vector ships first (so the
engine works before the fit), replaced by the fitted vector once the eval set
exists. **The weights are the only learned artifact and they are tiny.**

**Decision**: pick max-P candidate. `τ_auto` and `τ_review` are chosen from the
**calibration curve** (the score at which empirical precision ≥ 99% becomes
`τ_auto`), not hand-guessed. Below `τ_review` → `ask`. Alternatives = next-best
candidates by P. Abstention is a feature, not a failure.

**Eval harness**: a dataset of `{raw_text, expected_canonical_id, input_type}`
plus optional `{household_purchases, list_context}` for prior-dependent cases, and
a runner that reports **precision@auto-accept, coverage, top-1 accuracy** — **print
and handwriting scored separately** (§19; never blend them into one number) — plus
a calibration table. Run it against the OLD resolver first to capture the honest
baseline, then against the new engine to prove the lift.

## Current state

- `frontend/lib/services/scan/canonical_resolver_service.dart` — the sequential
  `resolve()` + `_resolveWithFallback()` described above. Constructor:
  `CanonicalResolverService(this._db, {classifier, embedder})`. Keep it working
  (call sites: `scan_pipeline_service.dart:34`, `shopping_trip_screen.dart`).
- `frontend/lib/services/scan/confidence_service.dart` — hardcoded `0.85`/`0.50`.
- `frontend/lib/storage/app_database.dart` — signals already present:
  - `getAliasFuzzyCandidates({groupId, query})`, `findAlias`, `getCanonicalItemById`
  - `getGroupPurchaseHistory({groupId, limit})` (1071) → frequency + recency prior
  - `getTopCooccurrences({groupId, itemId, limit})` (1096) → list context
- `frontend/lib/services/scan/grocery_classifier_service.dart` — `classify(text, topK)`.
- `frontend/lib/services/scan/static_embedding_service.dart` — `nearest(query, topK)`.
- `intelligence/ml/build_app_seed.py` — the `{version: ASSET_VERSION}` build-time
  bundle convention every shipped asset follows. The weights bundle follows it.
- `frontend/test/services/` — `outbox_coordinator_test.dart` (in-memory Drift),
  `token_store_test.dart` (pure unit). Model the new tests on these.

## Scope

**In scope:**
- `frontend/lib/services/scan/resolution/candidate_generator.dart` (create)
- `frontend/lib/services/scan/resolution/resolution_features.dart` (create — pure feature vector builder, `@visibleForTesting`)
- `frontend/lib/services/scan/resolution/calibrated_scorer.dart` (create — pure LR dot-product+sigmoid, loads weights bundle, ships a default weight vector)
- `frontend/lib/services/scan/canonical_resolver_service.dart` (add an optional `EnsembleResolver` path behind a flag; keep the old path as fallback/baseline)
- `frontend/lib/services/scan/confidence_service.dart` (accept calibrated τ from the weights bundle instead of hardcoded constants; default unchanged)
- `frontend/assets/grocery/resolution_weights.json` (create — versioned default weights; maintainer replaces with the fitted vector)
- `frontend/pubspec.yaml` (register the weights asset if not covered by `assets/grocery/`)
- `intelligence/ml/eval/resolution_eval.py` (create — build-time: runs the eval set, fits LR weights, emits `resolution_weights.json` + a metrics report)
- `intelligence/ml/eval/resolution_eval.schema.md` (create — the dataset row schema + curation notes)
- `frontend/test/services/resolution_features_test.dart`, `frontend/test/services/calibrated_scorer_test.dart`, `frontend/test/services/candidate_generator_test.dart` (create)
- `frontend/test/support/resolution_weights_fixture.json` (create — synthetic)

**Out of scope (do NOT touch):**
- Recognition (OCR/handwriting/VLM) — the ML Kit ceiling is the 032-phase-2 track.
- The scan review UI plumbing (image strips, mark detection) — separate effort.
- The backend — no model runs there (north-star law).
- The real labeled eval dataset — the **maintainer** curates it; the executor ships
  only the schema + a tiny synthetic fixture. Do NOT invent ground-truth labels.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Dart deps | `cd frontend && flutter pub get` | exit 0 |
| Analyze | `cd frontend && flutter analyze lib/ test/` | exit 0 |
| New tests | `cd frontend && flutter test test/services/resolution_features_test.dart test/services/calibrated_scorer_test.dart test/services/candidate_generator_test.dart` | pass |
| Full suite | `cd frontend && flutter test` | no NEW failures vs baseline |
| Python syntax | `python3 -m py_compile intelligence/ml/eval/resolution_eval.py` | exit 0 |

## Steps (built in lockstep — instrument first, then the engine, re-measuring each step)

### Phase A — Instrument (get the honest baseline before changing anything)

**A1.** Write `intelligence/ml/eval/resolution_eval.schema.md`: the JSONL row shape
`{raw_text, expected_canonical_id, input_type: "print"|"handwriting", household_purchases?: [...], list_context?: [...]}`, plus curation notes (real handwritten + print lists, DE+EN, shorthand-heavy, score handwriting separately). State that the dataset file (`intelligence/ml/data/resolution_eval.jsonl`) is **maintainer-curated and git-ignored** like the other ML data.

**A2.** Build a Dart eval runner as a test-mode harness: a function that, given a
list of eval rows + a configured resolver, computes **precision@auto-accept,
coverage, top-1 accuracy**, split by `input_type`. Drive it from a `flutter test`
that loads a committed **synthetic** fixture (5–10 hand-built rows over a seeded
in-memory Drift DB) so it is deterministic and CI-safe without the real dataset.
The same runner is what the maintainer points at the real dataset.

**A3.** Run the runner against the **current** `CanonicalResolverService` to record
the baseline numbers in the report. This is the "honest current number."

**Verify**: new harness test passes on the synthetic fixture; `flutter analyze` clean.

### Phase B — Candidate generation + features (pure, testable)

**B1.** `CandidateGenerator.generate(rawText, groupId, listIds)` → `List<Candidate>`
where `Candidate` carries `canonicalItemId`, `displayName`, and a `Map<source,
rawScore>`. Union the five sources, de-dup by `canonicalItemId`, keep each source's
score. No scoring decision here — just assembly.

**B2.** `resolution_features.dart`: a **pure** `@visibleForTesting`
`List<double> buildFeatures(Candidate c, ResolutionContext ctx)` producing the
fixed-order vector in the table above. `ResolutionContext` holds the precomputed
per-household frequency/recency map and the list co-occurrence map (computed once
per `resolve`, not per candidate). No DB or async in the pure function.

**Verify**: `candidate_generator_test.dart` (in-memory Drift, asserts union + dedup
+ source attribution) and `resolution_features_test.dart` (hand-computed vectors)
pass.

### Phase C — Calibrated scorer + decision

**C1.** `calibrated_scorer.dart`: pure `double score(List<double> features,
List<double> weights, double bias)` = `sigmoid(dot + bias)`. Loads
`resolution_weights.json` (`{version, weights:[...], bias, tau_auto, tau_review}`)
via `rootBundle`, fail-soft to a committed **default** vector when absent. Ship a
sensible hand-set default (positive weights on household-alias, exact-match,
agreement, classifier; smaller on fuzzy/embedder) so the engine is good before any
fit.

**C2.** Assemble `EnsembleResolver`: generate → features → score every candidate →
argmax P → map to `ResolveResult` with `score = P` and alternatives = next-best by
P. Decision thresholds come from the bundle (`tau_auto`/`tau_review`), feeding
`ConfidenceService` (which now reads τ from the bundle, defaulting to today's
0.85/0.50 so behaviour is unchanged until a fit ships).

**C3.** Wire `EnsembleResolver` into `CanonicalResolverService` behind a constructor
flag (`{bool useEnsemble = false}`), defaulting **off** so nothing changes until the
eval proves it wins. `scan_pipeline_service.dart` can flip it on once B–C land and
A shows the lift.

**Verify**: `calibrated_scorer_test.dart` (known dot-products → known sigmoid) passes;
re-run the Phase-A harness against `EnsembleResolver` on the synthetic fixture and
confirm it does **no worse** than baseline on the fixture (the real lift is proven
by the maintainer on the real dataset).

### Phase D — Build-time fit + the proof

**D1.** `intelligence/ml/eval/resolution_eval.py` (maintainer-run): load the real
`resolution_eval.jsonl`, reproduce the same feature vectors (mirror the Dart
`buildFeatures` order — this is the parity contract, like 026/028's golden files),
fit a logistic regression (train/held-out split), pick `tau_auto` as the score
where held-out precision ≥ 0.99, and **emit `frontend/assets/grocery/resolution_weights.json`**
(versioned) + a metrics report (precision@auto / coverage / top-1, print vs
handwriting, calibration table). Also emit a small `resolution_golden.json`
(feature-vector + expected P for a few rows) so the Dart scorer can be parity-checked.

**Verify (executor)**: `python3 -m py_compile intelligence/ml/eval/resolution_eval.py`
exits 0. (Running it is the maintainer's step — needs the real dataset.)

**Verify (maintainer, post-merge)**: run `resolution_eval.py`; confirm the new
engine's precision@auto-accept and coverage **beat the Phase-A baseline**, print and
handwriting reported separately; drop the fitted `resolution_weights.json` into
`assets/grocery/`; flip `useEnsemble: true` in `scan_pipeline_service.dart`.

## Done criteria (executor)

- [ ] `cd frontend && flutter analyze lib/ test/` exits 0
- [ ] `candidate_generator_test.dart`, `resolution_features_test.dart`, `calibrated_scorer_test.dart`, and the Phase-A harness test all pass
- [ ] `cd frontend && flutter test` — no NEW failures vs baseline
- [ ] `python3 -m py_compile intelligence/ml/eval/resolution_eval.py` exits 0
- [ ] `EnsembleResolver` is behind a default-OFF flag; the old sequential path and all current call sites are unchanged in behaviour
- [ ] `CalibratedScorer` uses **no** native/cloud runtime — pure-Dart dot-product+sigmoid; weights are a versioned bundle
- [ ] No real eval dataset, fitted weights, or model binaries committed (only schema + synthetic fixtures + a hand-set default weight vector)
- [ ] North-star gate: no new cloud-inference path; the only learned artifact is the tiny versioned `resolution_weights.json`; all signals computed on-device
- [ ] No files outside the in-scope list modified
- [ ] `plans/README.md` status row updated

## North-star gate (paste-check)

- [x] No new code path performs cloud inference — scorer is on-device pure-Dart.
- [x] Every prediction reads on-device data + a build-time weights bundle.
- [x] No third-party data/model introduced (uses existing classifier/embedder/graph).
- [x] Shipped weights are versioned (`resolution_weights.json` `{version}`), updatable without an app release.

## STOP conditions

- Drift check shows an in-scope file changed and the excerpts no longer match.
- Wiring the ensemble requires editing `shopping_trip_screen.dart` or
  `list_detail_screen.dart` (it must not — the flag defaults off and the
  constructor stays backward-compatible).
- The synthetic-fixture harness can't be made deterministic — report rather than
  loosen assertions.
- Feature-vector parity between Dart `buildFeatures` and the Python fitter cannot
  be guaranteed (different feature order/normalisation) — STOP; the golden file is
  the contract and must match before a fit is meaningful.

## Maintainer steps (post-merge, needs the real eval dataset)

1. Curate `intelligence/ml/data/resolution_eval.jsonl` (real handwritten + print
   lists → ground-truth canonical IDs; DE+EN; shorthand-heavy; mark `input_type`).
   This is the one irreplaceable human asset — accuracy is only as honest as this set.
2. Run `resolution_eval.py` → fitted `resolution_weights.json` + metrics report.
3. Confirm the new engine beats the baseline (precision@auto-accept ↑ at equal or
   higher coverage), print and handwriting separately.
4. Drop the fitted weights into `assets/grocery/`; flip `useEnsemble: true`.
5. Track **repeat-correction-rate** over time (the §19 canary) — it should trend to
   zero as the learning loop + household prior compound. If a user fixes the same
   item twice, the prior or the correction projection is broken.

## Maintenance notes

- This is the §5 selection-signals model and the §19 eval harness, finally built.
- The accuracy engine is the **household prior + source agreement**, not any single
  model. The classifier/embedder are two voters among several; the prior is what
  collapses the candidate space and drives the correct rate up over a household's
  usage. The first scan is ~baseline; the 20th is near-perfect *because it learned*.
- The scorer is deliberately a logistic regression, not a neural net: it is tiny,
  shippable, calibratable, and interpretable (you can read which signal carried a
  decision). Upgrade to gradient-boosted trees only if the eval plateaus and the
  weights bundle stays small.
- `tau_auto` is chosen from the calibration curve for a precision target, not
  guessed. Re-fit when the catalog, classifier, or embedder changes materially.
