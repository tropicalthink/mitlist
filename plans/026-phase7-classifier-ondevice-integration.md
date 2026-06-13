# Plan 026: Wire the Phase 7 grocery classifier into on-device resolution (Flex-free)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat c862d307..HEAD -- frontend/lib/services/scan/canonical_resolver_service.dart frontend/lib/services/scan/scan_pipeline_service.dart frontend/pubspec.yaml intelligence/ml/phase7_classifier/export.py`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: L
- **Risk**: MED
- **Depends on**: plans/021 (the trained classifier exists — `intelligence/ml/phase7_classifier/model.keras` and `intelligence/ml/models/grocery_classifier_labels.txt` must be present on disk)
- **Category**: direction (ML feature integration)
- **Planned at**: commit `c862d307`, 2026-06-13

## Why this matters

The Phase 7 classifier is trained and on disk, but **nothing in the app uses
it**. Today `CanonicalResolverService` (the function that maps a noisy
OCR/typed item name to a canonical grocery item) does exact-alias lookup, then
normalised edit-distance fuzzy matching, then gives up with score 0. That
fuzzy step handles typos well but fails on the genuinely noisy OCR the
classifier was trained for ("0at M1lk", "Vollmlch 3,5%"). The classifier is the
long-tail win: when the alias/fuzzy path is not confident (score < 0.85), ask
the model.

**There is a blocker that this plan exists to solve.** The classifier
`.tflite` as currently exported bakes a Keras `TextVectorization` (`tf_idf`)
layer *into the graph*, which forces the TensorFlow **Flex delegate**
(`SELECT_TF_OPS`). The stock `tflite_flutter` runtime does **not** ship Flex
ops, and bundling them needs a fragile per-platform custom native build. The
fix (decided by the maintainer): **re-export the model Flex-free** — strip the
vectorization out of the graph, dump its vocabulary + IDF weights to JSON, and
reproduce the TF-IDF math in Dart. No retraining is needed; the trained dense
weights are reused from `model.keras`.

After this lands: a noisy item the fuzzy resolver can't place gets a model
prediction, mapped back to a canonical item, fully offline, on plain
`tflite_flutter`.

## Architecture decision (read before coding)

This plan has a hard split between **what the executor builds** (all the code,
verifiable in a worktree without TensorFlow or a device) and **what the
maintainer runs afterward** (the actual Python re-export, which needs the
`intelligence/.venv` with TensorFlow, plus an on-device smoke test). This
mirrors plans 021/022, where training was the maintainer's step.

- The executor **cannot** run the Python re-export (no TF in the worktree) and
  **cannot** load the real `.tflite` in `flutter test` (no native libs / no
  real model committed). So the executor's verification uses a **synthetic
  fixture** (a tiny hand-built vocab/IDF) to prove the Dart TF-IDF math is
  correct in isolation, plus a **fake classifier** to prove the resolver
  fallback wiring.
- The maintainer's later step uses **golden samples** emitted by the re-export
  to prove the real Dart pipeline matches the real model end-to-end.

Keep the pure-Dart feature math (`charTrigrams` + `buildTfidf`) in functions
that take plain data and return plain data — **no interpreter, no asset I/O** —
so they are unit-testable without native libraries. The interpreter call is a
thin separate method.

## Current state

Files and their roles:

- `frontend/lib/services/scan/canonical_resolver_service.dart` — the resolver.
  The fallback slot is at the two early-return points where it currently gives
  up. Excerpt (lines 73–94):
  ```dart
      if (best == null || best.score < 0.5) {
        return ResolveResult(displayName: _titleCase(itemName), score: 0);
      }

      final canonical = await _db.getCanonicalItemById(best.alias.canonicalItemId);
      if (canonical == null) {
        return ResolveResult(displayName: _titleCase(itemName), score: 0);
      }
      // ... returns best fuzzy match with best.score
  ```
  Constructor today (line 27): `CanonicalResolverService(this._db);`

- `frontend/lib/services/scan/scan_pipeline_service.dart` — constructs the
  resolver at line 46: `_resolver = CanonicalResolverService(db),` and calls it
  at line 80: `final resolved = await _resolver.resolve(item.itemName, groupId);`

- `frontend/lib/screens/shopping/shopping_trip_screen.dart:161` ALSO constructs
  `CanonicalResolverService(db)` directly. **This is why the new classifier
  constructor argument must be optional** — adding a required arg breaks this
  call site.

- `frontend/lib/storage/app_database.dart` — DB lookups available:
  - `findAlias({required String groupId, required String aliasText})` →
    `Future<ItemAliasesTableData?>` (line 868). Matches household + `__global__`
    scope, exact `aliasText`. This is how a predicted canonical name is mapped
    back to a `canonicalItemId`.
  - `getCanonicalItemById(String id)` → `Future<CanonicalItemsTableData?>` (line 828).
  - `CanonicalItemsTableData` has fields `id`, `nameDe`, `nameEn`, `category`,
    `defaultUnit` (seen used in `grocery_suggestion_service.dart:62-66,85-92`).

- `frontend/lib/services/grocery_seed_loader.dart` — the asset-loading
  convention (lines 1-9, 27): `import 'package:flutter/services.dart';` then
  `await rootBundle.loadString('assets/grocery/seed.json')` and
  `jsonDecode(raw)`. Model assets go under `assets/models/` (new dir).

- `frontend/pubspec.yaml` — assets block (lines 110-112) currently lists
  `assets/animations/lottie/` and `assets/grocery/`. No ML runtime in
  `dependencies` (lines 30-67). `dev_dependencies` start at line 68.

- `intelligence/ml/phase7_classifier/export.py` — current export (the file to
  rewrite). It loads `model.keras`, converts with `SELECT_TF_OPS`, and writes
  `grocery_classifier.tflite` + `grocery_classifier_labels.txt`. The model's
  input is `tf.string` shaped `(1,)` and the FIRST non-input layer is a
  `TextVectorization(max_tokens=8000, output_mode="tf_idf")`.

- `intelligence/ml/phase7_classifier/train.py:79` — the exact preprocessing the
  model was trained on (the model input is the *trigram string*, not raw text):
  ```python
  def char_trigrams(text: str, max_len: int = 64) -> str:
      t = text.lower()[:max_len - 4]
      return " ".join(t[i : i + 3] for i in range(len(t) - 2)) if len(t) > 2 else t
  ```
  And the vectorizer config (train.py:120): `TextVectorization(max_tokens=8000,
  output_mode="tf_idf")` adapted on trigram strings. Keras
  `TextVectorization` defaults that matter for Dart parity:
  `standardize="lower_and_strip_punctuation"`, `split="whitespace"`,
  `ngrams=None`. In `tf_idf` mode the output is a dense vector of length
  `len(vocabulary)`; entry `i` = (count of token `i` in the input) × `idf[i]`.
  Index 0 is the padding token `""`, index 1 is OOV `"[UNK]"`.

Repo conventions to match:
- Services live in `frontend/lib/services/scan/`, one class per file, doc
  comment on the class. See `canonical_resolver_service.dart` for the house
  style (private statics for pure helpers, no external deps in the math).
- Tests live in `frontend/test/services/`. Model after
  `frontend/test/services/token_store_test.dart` for a focused service unit
  test (plain `test(...)`/`expect(...)`, no widget pumping).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Install Flutter deps | `cd frontend && flutter pub get` | exit 0, resolves `tflite_flutter` |
| Analyze | `cd frontend && flutter analyze` | exit 0, no new errors |
| Test (filtered) | `cd frontend && flutter test test/services/grocery_classifier_service_test.dart test/services/canonical_resolver_service_test.dart` | all pass |
| Full test suite | `cd frontend && flutter test` | no NEW failures vs baseline (see STOP conditions) |
| Python syntax check | `python3 -m py_compile intelligence/ml/phase7_classifier/export.py` | exit 0 |

(Verified during recon: `flutter test` / `flutter analyze` are the repo's gates
per `AGENTS.md:20` and `frontend/README.md:35`.)

## Suggested executor toolkit

- For the `tflite_flutter` API surface (interpreter creation, `run`, tensor
  shapes), use the **context7** MCP if available: resolve library
  `tflite_flutter` and query "Interpreter.fromAsset run input output". Do not
  guess the API from memory — the plugin's `Interpreter` API changed across
  versions.

## Scope

**In scope** (the only files you should modify or create):
- `frontend/pubspec.yaml` (add dependency + asset dir)
- `frontend/lib/services/scan/grocery_classifier_service.dart` (create)
- `frontend/lib/services/scan/canonical_resolver_service.dart` (add optional
  fallback)
- `frontend/test/services/grocery_classifier_service_test.dart` (create)
- `frontend/test/services/canonical_resolver_service_test.dart` (create)
- `frontend/test/support/grocery_classifier_fixture.json` (create — synthetic
  vocab/IDF fixture for the math test)
- `intelligence/ml/phase7_classifier/export.py` (rewrite for Flex-free export)

**Out of scope** (do NOT touch):
- `frontend/lib/services/scan/scan_pipeline_service.dart` — the pipeline already
  calls `_resolver.resolve(...)`; once the resolver gains an optional
  classifier, wiring the classifier *into the pipeline's resolver construction*
  is deliberately deferred to the maintainer's post-merge step (it needs the
  real model present). Leave the pipeline as-is.
- `frontend/lib/screens/shopping/shopping_trip_screen.dart` — must keep
  compiling against the optional-arg constructor; do not modify it.
- `intelligence/ml/phase7_classifier/train.py` — no retraining; do not change.
- Any real `.tflite` / vocab / golden asset — those are produced by the
  maintainer's re-export, not committed by you. Do NOT create placeholder model
  files under `frontend/assets/models/`.

## Git workflow

- Branch: `advisor/026-phase7-classifier-integration`
- Commit per logical unit (pubspec+dep; classifier service+test; resolver
  fallback+test; export.py). Conventional-commit style to match `git log`
  (e.g. `feat(scan): add on-device grocery classifier service`).
- Do NOT push or open a PR.

## Steps

### Step 1: Add the TFLite runtime and model asset dir

In `frontend/pubspec.yaml`, add to `dependencies` (alphabetical-ish, near other
runtime deps):
```yaml
  tflite_flutter: ^0.11.0
```
And add the new asset directory under the existing `flutter: assets:` list
(after `assets/grocery/`):
```yaml
    - assets/models/
```
Create the directory so pub doesn't error on a missing asset path:
`mkdir -p frontend/assets/models` and add a `frontend/assets/models/.gitkeep`
(empty file) so the dir is tracked.

**Verify**: `cd frontend && flutter pub get` → exit 0, `tflite_flutter` appears
in `pubspec.lock`.

> If `flutter pub get` fails to resolve `tflite_flutter ^0.11.0` against the
> pinned Dart SDK (`frontend/pubspec.yaml` comments note a Dart 3.6.x pin),
> this is a STOP condition — report the version conflict; do not bump the SDK
> or other pins to force it.

### Step 2: Rewrite `export.py` for a Flex-free export

Rewrite `intelligence/ml/phase7_classifier/export.py` so it:

1. Loads `model.keras`.
2. Finds the `TextVectorization` layer by type and extracts:
   - `vocab = vectorizer.get_vocabulary()` (list[str], index 0 = `""`, 1 = `"[UNK]"`)
   - `idf = [float(w) for w in vectorizer.idf_weights.numpy()]` (same length as vocab)
3. Builds a NEW model whose input is the float TF-IDF vector and which reuses
   the trained dense layers (so no retraining):
   ```python
   vec_len = len(vocab)
   inp = tf.keras.Input(shape=(vec_len,), dtype=tf.float32, name="tfidf")
   x = inp
   for layer in model.layers:
       if isinstance(layer, (tf.keras.layers.InputLayer, tf.keras.layers.TextVectorization)):
           continue
       x = layer(x)          # reuses each layer's trained weights
   dense_model = tf.keras.Model(inp, x)
   ```
4. Converts `dense_model` with **builtins only** (no `SELECT_TF_OPS`):
   ```python
   converter = tf.lite.TFLiteConverter.from_keras_model(dense_model)
   converter.optimizations = [tf.lite.Optimize.DEFAULT]
   tflite_model = converter.convert()
   ```
   Write to `../models/grocery_classifier.tflite`.
5. Still writes `grocery_classifier_labels.txt` from `label_encoder.pkl` exactly
   as before (one label per line, `le.classes_` order).
6. Writes `../models/grocery_classifier_vocab.json`:
   ```python
   import json, string
   json.dump({
       "vocab": vocab,
       "idf": idf,
       "max_len": 64,                       # matches char_trigrams default
       "strip_chars": string.punctuation,   # what lower_and_strip_punctuation removes
   }, open(MODELS_DIR / "grocery_classifier_vocab.json", "w"))
   ```
7. Writes `../models/grocery_classifier_golden.json` — a handful of end-to-end
   reference samples so the Dart pipeline can be validated against the real
   model later. Import `char_trigrams` from `train.py` and run the ORIGINAL
   string model (the loaded `model.keras`) on raw inputs:
   ```python
   from train import char_trigrams
   samples = ["Vollmilch", "0at M1lk", "Bananen", "Joghurt natur", "Hähnchenbrust"]
   golden = []
   for raw in samples:
       probs = model.predict([[char_trigrams(raw)]], verbose=0)[0]
       top5 = probs.argsort()[-5:][::-1].tolist()
       golden.append({"raw": raw, "top5_indices": top5,
                      "top5_labels": [le.classes_[i] for i in top5]})
   json.dump(golden, open(MODELS_DIR / "grocery_classifier_golden.json", "w"))
   ```

Add a module docstring noting the model now takes a float TF-IDF vector and the
vectorization is reproduced client-side.

**Verify**: `python3 -m py_compile intelligence/ml/phase7_classifier/export.py`
→ exit 0. (You cannot run it — no TensorFlow in the worktree. Running it is the
maintainer's step. Confirm only that it compiles.)

### Step 3: Create `GroceryClassifierService` (pure math + thin interpreter)

Create `frontend/lib/services/scan/grocery_classifier_service.dart`.

Keep two pure, dependency-free, `@visibleForTesting`-exported static functions:

```dart
/// Reproduces intelligence/ml/phase7_classifier/train.py:char_trigrams.
/// Lowercases, truncates to (maxLen-4), emits space-joined 3-grams.
static String charTrigrams(String text, {int maxLen = 64}) {
  final t = text.toLowerCase();
  final cut = t.length > (maxLen - 4) ? t.substring(0, maxLen - 4) : t;
  if (cut.length <= 2) return cut;
  final grams = <String>[];
  for (var i = 0; i <= cut.length - 3; i++) {
    grams.add(cut.substring(i, i + 3));
  }
  return grams.join(' ');
}

/// Reproduces Keras TextVectorization(output_mode="tf_idf") for the given
/// vocab/idf. Input is the trigram string from [charTrigrams]. Returns a
/// dense Float32List of length vocab.length: entry i = count(token i) * idf[i].
/// Mirrors standardize="lower_and_strip_punctuation" (already lower; strip the
/// chars in [stripChars]) and split="whitespace". Unknown tokens map to the
/// OOV slot (index 1).
static Float32List buildTfidf(
  String trigramString, {
  required Map<String, int> vocabIndex, // token -> index, built once from vocab list
  required List<double> idf,
  required String stripChars,
}) { ... }
```

Implementation notes for `buildTfidf` (match Keras exactly):
- Build a `Set<int>` of strip code units from `stripChars` once.
- Split `trigramString` on runs of whitespace (`RegExp(r'\s+')`), drop empties.
- For each token: remove any chars present in `stripChars`; if the result is
  empty, skip it; look up its index in `vocabIndex`, defaulting to `1` (the
  `[UNK]` slot) when absent.
- `counts[index] += 1`, then `out[i] = counts[i] * idf[i]` for all i.
- Length of `out` == `idf.length` == vocab length.

The class itself:
- Constructor takes the asset paths (defaulted) so tests can avoid asset I/O.
- `Future<void> _ensureLoaded()`: lazily loads the interpreter via
  `Interpreter.fromAsset('assets/models/grocery_classifier.tflite')`, the labels
  from `grocery_classifier_labels.txt` (split on `\n`), and the vocab JSON
  (`rootBundle.loadString` + `jsonDecode`), building `vocabIndex`, `idf`,
  `stripChars`. Use `package:flutter/services.dart` `rootBundle` (see
  `grocery_seed_loader.dart`).
- `Future<List<ClassifierPrediction>> classify(String rawText, {int topK = 5})`:
  trigrams → `buildTfidf` → shape input as `[[...]]` (batch 1) → allocate output
  buffer `[List.filled(labels.length, 0.0)]` → `interpreter.run(input, output)`
  → argsort top-K → return `ClassifierPrediction(label, score)`.
- Define `class ClassifierPrediction { final String label; final double score; }`.
- Wrap interpreter load failures: if the asset is missing (no model shipped
  yet), `_ensureLoaded` should set an `_unavailable` flag and `classify` returns
  `const []` rather than throwing — so the app runs fine before the maintainer
  ships the model.

**Verify**: `cd frontend && flutter analyze` → exit 0 (file may be unused so
far; that's fine).

### Step 4: Unit-test the pure math against a synthetic fixture

Create `frontend/test/support/grocery_classifier_fixture.json` — a tiny
hand-built vocab/IDF you can compute expected TF-IDF by hand. Example:
```json
{
  "vocab": ["", "[UNK]", "mil", "ilc", "lch"],
  "idf":   [0.0, 1.0,    2.0,   3.0,   4.0],
  "max_len": 64,
  "strip_chars": "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
}
```

Create `frontend/test/services/grocery_classifier_service_test.dart` (model
after `token_store_test.dart`'s plain-`test` style). Assert:
- `charTrigrams('milch')` == `'mil ilc lch'`.
- `charTrigrams('ab')` == `'ab'` (≤2 chars short-circuit).
- `charTrigrams('AB CDE')` lowercases and truncates per the rule.
- `buildTfidf('mil ilc lch', ...)` using the fixture yields a `Float32List`
  `[0, 0, 2.0, 3.0, 4.0]` (each trigram appears once → count×idf).
- A repeated trigram doubles its slot: `buildTfidf('mil mil', ...)` → index 2 is
  `4.0` (count 2 × idf 2.0).
- An unknown trigram lands in the OOV slot (index 1): `buildTfidf('zzz', ...)` →
  index 1 == `1.0`.

These tests need **no native lib and no real model** — they exercise only the
pure static functions with the committed fixture.

**Verify**: `cd frontend && flutter test test/services/grocery_classifier_service_test.dart`
→ all pass.

### Step 5: Add the optional classifier fallback to `CanonicalResolverService`

Make the classifier optional and backward-compatible:
- Change the constructor to
  `CanonicalResolverService(this._db, {GroceryClassifierService? classifier}) : _classifier = classifier;`
  with a `final GroceryClassifierService? _classifier;` field. Existing call
  sites (`scan_pipeline_service.dart:46`, `shopping_trip_screen.dart:161`) pass
  no classifier and keep compiling.
- Add a private helper `Future<ResolveResult> _classifierFallback(String itemName, String groupId, double fuzzyScore, String fuzzyDisplay, List<String> fuzzyAlts)` that:
  1. Returns the fuzzy result unchanged if `_classifier == null`.
  2. Calls `final preds = await _classifier!.classify(itemName, topK: 5);`
  3. If empty, returns the fuzzy result unchanged.
  4. Takes `preds.first`; if its `score < 0.85`, returns the fuzzy result
     unchanged (don't override a weak model guess).
  5. Maps the predicted label back to a canonical item:
     `final alias = await _db.findAlias(groupId: groupId, aliasText: _normalise(preds.first.label));`
     then `getCanonicalItemById(alias.canonicalItemId)`. The labels are
     canonical German names (`name_de`), which the seed registers as aliases, so
     this lookup normally resolves.
  6. If it resolves AND the model score beats the fuzzy score, return a
     `ResolveResult` with that canonical item, `score: preds.first.score`, and
     the remaining top predictions' display names as `alternatives` (best
     effort; safe to leave empty). Otherwise return the fuzzy result.
- Call `_classifierFallback(...)` at the two current give-up points (the
  `best.score < 0.5` early return and the post-fuzzy successful return) so the
  model gets a chance whenever the alias/fuzzy confidence is below the 0.85 bar.
  Concretely: build the fuzzy `ResolveResult` as today, then
  `return _resolveWithFallback(itemName, groupId, fuzzyResult);` where
  `_resolveWithFallback` short-circuits to `fuzzyResult` when `_classifier ==
  null` or `fuzzyResult.score >= 0.85`.

Do not change the exact-alias branch (score 1.0) — a perfect alias hit never
needs the model.

**Verify**: `cd frontend && flutter analyze` → exit 0.

### Step 6: Test the resolver fallback with a fake classifier

Create `frontend/test/services/canonical_resolver_service_test.dart`. Use an
in-memory Drift DB (`NativeDatabase.memory()` — see
`outbox_coordinator_test.dart` for the `drift/native.dart` import pattern) and a
hand-written fake classifier implementing the same public surface (a subclass
overriding `classify` to return scripted predictions, or an interface — keep it
simple: give `GroceryClassifierService` a `@visibleForTesting` constructor or
make `classify` overridable).

Cover:
- **No classifier** → resolver behaves exactly as before (a low-confidence input
  returns score 0 / fuzzy result). Regression guard.
- **Classifier confident + label maps to a seeded canonical item** → resolver
  returns that canonical item with the model's score.
- **Classifier confident but score < 0.85** → fuzzy result is kept (model does
  not override).
- **Classifier label doesn't map to any canonical item** → fuzzy result is kept
  (no crash).

Seed the in-memory DB with one canonical item + an alias equal to its
`name_de` so the `findAlias` mapping in step 5 has something to hit. (Inspect
`app_database.dart` for the insert companions; model the seeding on how
`grocery_seed_loader.dart` inserts canonical items + aliases.)

**Verify**:
`cd frontend && flutter test test/services/canonical_resolver_service_test.dart`
→ all pass.

### Step 7: Full suite + analyze

**Verify**:
- `cd frontend && flutter analyze` → exit 0.
- `cd frontend && flutter test` → no NEW failures beyond the known
  pre-existing `frontend_flows_test.dart` compile/finder issue noted in
  `plans/README.md` (cycle 6, plan 025). If a *different* test newly fails,
  that's a STOP condition.

## Test plan

- New: `grocery_classifier_service_test.dart` — pure `charTrigrams` +
  `buildTfidf` correctness against the synthetic fixture (Step 4). No model, no
  native libs.
- New: `canonical_resolver_service_test.dart` — the four fallback cases with a
  fake classifier + in-memory DB (Step 6), including the no-classifier
  regression guard.
- Structural pattern: `frontend/test/services/token_store_test.dart` (plain
  unit test) and `frontend/test/services/outbox_coordinator_test.dart` (Drift
  `NativeDatabase.memory()` setup + fakes).
- Verification: both files pass under `flutter test`; full suite shows no new
  failures.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd frontend && flutter pub get` exits 0 and `tflite_flutter` is in `pubspec.lock`
- [ ] `cd frontend && flutter analyze` exits 0
- [ ] `cd frontend && flutter test test/services/grocery_classifier_service_test.dart test/services/canonical_resolver_service_test.dart` — all pass
- [ ] `cd frontend && flutter test` — no NEW failures vs the documented baseline
- [ ] `python3 -m py_compile intelligence/ml/phase7_classifier/export.py` exits 0
- [ ] `grep -n "SELECT_TF_OPS" intelligence/ml/phase7_classifier/export.py` returns nothing (Flex dependency removed)
- [ ] `grep -n "classifier" frontend/lib/services/scan/canonical_resolver_service.dart` shows the optional param
- [ ] No real `.tflite`/vocab/golden files were committed under `frontend/assets/models/` (only `.gitkeep`)
- [ ] No files outside the in-scope list are modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The drift check shows any in-scope file changed and the "Current state"
  excerpts no longer match the live code.
- `tflite_flutter ^0.11.0` cannot resolve against the pinned Dart SDK (do not
  bump pins to force it — report the conflict).
- `intelligence/ml/phase7_classifier/model.keras` is absent (the dependency on
  plan 021 is unmet — the re-export the maintainer must run needs it; note it
  and continue with the code, but flag clearly).
- `flutter test` shows a NEW failure unrelated to the known pre-existing
  `frontend_flows_test.dart` issue.
- Wiring the fallback appears to require editing `scan_pipeline_service.dart` or
  `shopping_trip_screen.dart` (it must not — the optional constructor arg keeps
  them untouched).
- The `tflite_flutter` `Interpreter` API differs materially from what this plan
  assumes (e.g. no `Interpreter.fromAsset`) — report the actual API rather than
  guessing.

## Maintenance notes (and the maintainer's post-merge steps)

**For the maintainer — required to actually ship the model (needs `intelligence/.venv` with TensorFlow):**
1. Re-run the export: `cd intelligence/ml/phase7_classifier && python3 export.py`.
   This regenerates `grocery_classifier.tflite` (now Flex-free, float input) and
   writes `grocery_classifier_vocab.json` + `grocery_classifier_golden.json`
   alongside the labels in `intelligence/ml/models/`.
2. Copy the four files into the app:
   `cp intelligence/ml/models/grocery_classifier.tflite intelligence/ml/models/grocery_classifier_labels.txt intelligence/ml/models/grocery_classifier_vocab.json frontend/assets/models/`
   (the golden file is for verification, not the app bundle).
3. Validate Dart parity against the real model: write/run a small integration
   check that loads the real assets + `grocery_classifier_golden.json` and
   asserts the Dart pipeline's top-5 indices match each golden sample's
   `top5_indices`. (This is the test that needs the real model, which is why it
   is not in the executor's scope.)
4. Wire the classifier into the live pipeline: in
   `scan_pipeline_service.dart:46`, pass a shared `GroceryClassifierService`
   into `CanonicalResolverService(db, classifier: ...)`. Optionally do the same
   at `shopping_trip_screen.dart:161`. (Deferred from the executor's scope
   because it is only meaningful once the model asset exists.)
5. On-device smoke: scan a noisy handwritten/print item the fuzzy resolver
   misses; confirm the model now resolves it.

**For future reviewers:**
- The Dart `buildTfidf` must stay byte-for-byte faithful to Keras
  `TextVectorization(output_mode="tf_idf")`. If the model is ever retrained with
  a different `standardize`/`split`/`ngrams`/`max_tokens`, the vocab JSON and
  the Dart math must be re-checked against fresh golden samples.
- The 0.85 confidence bar is the README's stated threshold; it lives in
  `_resolveWithFallback`. Tune in one place.
- The model is loaded lazily and fails soft (returns `[]`) when the asset is
  missing — so this code is safe to merge before the model is shipped.
