# Plan 028: On-device grocery brain — OFF-enriched bundle + Model2Vec static embedder + semantic resolution

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, stop and report — do not improvise. When done, update
> the status row in `plans/README.md` unless a reviewer told you they maintain it.
>
> **Read first**: `plans/INTELLIGENCE-NORTH-STAR.md`. This plan must satisfy its
> done-criteria gate: every prediction runs on-device or reads a build-time
> bundle; the backend runs no model; third-party data/models are on the license
> green-list; shipped assets are versioned.
>
> **Drift check (run first)**:
> `git diff --stat 6c0df971..HEAD -- intelligence/ml/build_app_seed.py frontend/lib/services/grocery_seed_loader.dart frontend/lib/services/scan/grocery_suggestion_service.dart frontend/lib/services/scan/canonical_resolver_service.dart`
> If any changed since this plan was written, compare against the "Current state"
> excerpts before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: XL
- **Risk**: MED–HIGH (tokenizer parity build-time↔Dart is the main risk)
- **Depends on**: 022 (the fine-tuned embeddings model exists, used **build-time only** as a distillation teacher; an off-the-shelf green-list teacher may be used instead). Supersedes the **027 on-device NO-GO**.
- **Category**: direction (ML feature)
- **Planned at**: commit `6c0df971`, 2026-06-13

## Why this matters

Today item resolution and autocomplete are **alias/prefix string matching** over
the seed (`GrocerySuggestionService`, `CanonicalResolverService`). They miss
semantics ("oat drink" → Hafermilch), cross-language intent, and fuzzy real-world
names. The Phase-8 transformer that would fix this is 470 MB and was ruled
un-shippable on-device (027).

This plan delivers the semantic layer **within the on-device / zero-cost law**:
distill the big model **at build time** into a tiny **static** embedder
([Model2Vec](https://github.com/MinishLab/model2vec), MIT) — at inference it's a
`token → vector` lookup + mean-pool, **pure Dart, no ML runtime, microseconds,
offline**. The catalog of 3,239 canonical items is embedded **at build time** and
shipped as a vector matrix. A query embeds locally and cosine-matches the catalog.
The seed/vocab is first **enriched from Open Food Facts** (ODbL) for real
multilingual product names. Result: semantic, multilingual (DE/EN/FR/ES) item
understanding in a ~5 MB shipped bundle, zero per-prediction cost.

The "woah": type "leche de avena" / "Hafermilch" / "lait d'avoine" and the app
instantly knows it's oat milk — offline, in any of the four languages.

## Architecture (read before coding)

Hard split, mirroring plan 026:

- **Build-time (maintainer-run, Python, needs the model + libs)** — produces
  versioned bundle assets. The executor writes the scripts; the maintainer runs
  them (they need TensorFlow/torch/model2vec/the teacher model, none of which
  exist in a worktree). Outputs:
  1. an **OFF-enriched** canonical seed/vocab,
  2. a **Model2Vec static embedder** bundle (vocab + int8 vector matrix),
  3. a **precomputed catalog matrix** (3,239 items × dim, int8) with item IDs,
  4. a **golden file** (query → expected top-k canonical IDs) for Dart parity.
- **On-device (executor-run, Dart, fully verifiable)** — a pure-Dart
  `StaticEmbeddingService` that loads the bundle and does tokenizer + mean-pool +
  cosine, wired into autocomplete and the resolver. Unit-tested against a
  synthetic fixture and the build-time golden file.

**Key design choice that keeps it pure-Dart:** build the Model2Vec model with a
**word/phrase-level custom vocabulary** (grocery terms across the 4 languages +
OFF names), so the Dart tokenizer is trivial — lowercase, split on whitespace,
greedy longest-match against the vocab, OOV → char-trigram fallback (reuse plan
026's `charTrigrams`). No SentencePiece/WordPiece runtime needed. Mean-pool the
matched token vectors → query vector. The golden file is the parity guard.

## Current state

- `intelligence/ml/build_app_seed.py` — the existing build-time bundle producer:
  reads `intelligence/ml/data/seed.json` (raw 4-language canonical array) and
  writes `frontend/assets/grocery/seed.json` as `{version: ASSET_VERSION,
  items:[...]}` (see its `ASSET_VERSION` constant + `DST.write_text(json.dumps({...}))`).
  This is the pattern every new bundle follows.
- `intelligence/ml/data/seed.json` — 3,239 items, each:
  `{name_de, name_en, name_fr, name_es, category, default_unit, default_quantity,
  aliases_de, aliases_en, aliases_fr, aliases_es}`. This is the canonical label
  space and the catalog to embed.
- `intelligence/ml/data/triplets.jsonl` (7,052) — contrastive triples for
  optional fine-tuning of the embedder.
- `frontend/lib/services/grocery_seed_loader.dart` — loads `assets/grocery/seed.json`
  via `rootBundle.loadString`, version-gates the reseed (`assetVersion` vs stored),
  ingests into Drift. New bundles load the same way (`rootBundle` + a version key).
- `frontend/lib/services/scan/grocery_suggestion_service.dart` — `suggest(query,
  groupId, {limit})` does alias-prefix matching over Drift. **Autocomplete seam.**
- `frontend/lib/services/scan/canonical_resolver_service.dart` — `resolve(itemName,
  groupId)` = exact alias → fuzzy edit-distance → (026) optional classifier. **Resolver seam.**
- `frontend/lib/screens/lists/list_detail_screen.dart:172` `_refreshSuggestions` →
  `grocerySuggestionServiceProvider.suggest(...)`. **UI consumer.**
- `frontend/pubspec.yaml` — assets under `flutter: assets:` include
  `assets/grocery/`; add the new bundle dir there. `tflite_flutter` was added by
  026 but **this plan needs no ML runtime** (pure Dart).
- Plan 026 shipped `GroceryClassifierService.charTrigrams` — reuse it for the OOV
  fallback rather than re-implementing.

License green-list (from north star): OFF = ODbL (attribute; keep derived index
separable), Model2Vec/e5/bge = MIT, gte = Apache-2.0. The 470 MB Phase-8 model is
used **only at build time** as a teacher.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Dart deps | `cd frontend && flutter pub get` | exit 0 |
| Analyze | `cd frontend && flutter analyze lib/ test/` | exit 0, no new errors |
| Dart tests | `cd frontend && flutter test test/services/static_embedding_service_test.dart` | pass |
| Full suite | `cd frontend && flutter test` | no NEW failures vs baseline |
| Python syntax | `python3 -m py_compile intelligence/ml/build_embedder_bundle.py` | exit 0 |

(Build-time scripts are **maintainer-run** — the executor only `py_compile`s them.)

## Scope

**In scope:**
- `intelligence/ml/off_enrich_seed.py` (create — build-time OFF enrichment)
- `intelligence/ml/build_embedder_bundle.py` (create — distill + catalog vectors + golden)
- `frontend/lib/services/scan/static_embedding_service.dart` (create — pure-Dart)
- `frontend/lib/services/scan/grocery_suggestion_service.dart` (add semantic suggest)
- `frontend/lib/services/scan/canonical_resolver_service.dart` (add semantic fallback)
- `frontend/pubspec.yaml` (register the new bundle asset dir)
- `frontend/assets/models/.gitkeep` already exists (026); embedder bundle ships under `assets/grocery/` (versioned) or `assets/models/` — pick `assets/grocery/` to match seed bundles
- `frontend/test/services/static_embedding_service_test.dart` (create)
- `frontend/test/support/static_embedder_fixture.json` (create — synthetic)

**Out of scope (do NOT touch):**
- The backend — no model runs there (029 handles recipe resolution separately).
- `intelligence/ml/build_app_seed.py` — extend via the new scripts; don't rewrite it.
- Real bundle binaries (the embedder matrix, catalog vectors) — **maintainer**
  produces and ships them; the executor commits only `.gitkeep`/synthetic fixtures.
- Barcode scanning UI / OFF nutrition surfacing — that is **028 phase 2** (sketched
  at the end), not this plan.

## Git workflow

- Branch: `advisor/028-on-device-grocery-brain`
- Conventional commits per logical unit (off-enrich script; embedder-bundle script;
  StaticEmbeddingService + tests; autocomplete wiring; resolver wiring).
- Do NOT push.

## Steps

### Step 1 (build-time script): OFF enrichment of the seed/vocab

Create `intelligence/ml/off_enrich_seed.py`. Input: `data/seed.json` + an Open
Food Facts export (the maintainer downloads the ODbL CSV/JSONL dump, or a
per-market subset). For each canonical item, mine additional **real product
names/aliases** in de/en/fr/es from OFF products whose category matches, and
collect a **domain vocabulary** (the set of words/phrases appearing in canonical
names + aliases + mined OFF names, lowercased, across the 4 langs). Output:
- `data/seed_enriched.json` (same shape as seed.json, with extended `aliases_*`),
- `data/embedder_vocab.txt` (one token/phrase per line — the custom vocab).
Add an attribution note in the file header (ODbL requires attribution) and keep
the OFF-derived data in its own file (separable, per ODbL).

**Verify (executor)**: `python3 -m py_compile intelligence/ml/off_enrich_seed.py` → exit 0.
(Running it is the maintainer's step — it needs the OFF dump.)

### Step 2 (build-time script): distill the static embedder + catalog vectors + golden

Create `intelligence/ml/build_embedder_bundle.py`. Using **Model2Vec**:
- Teacher: a green-list multilingual encoder (`intfloat/multilingual-e5-small` or
  `Alibaba-NLP/gte-multilingual-base`), **or** the local Phase-8 fine-tuned model
  as a build-time teacher. (Distillation needs only a teacher + the vocab.)
- Distill with the **custom vocabulary** from Step 1 (`embedder_vocab.txt`) so the
  result is word/phrase-level → trivial Dart tokenization. Apply int8 quantization
  and dimensionality reduction (e.g. 256→128) per Model2Vec's options.
- Emit the bundle under `frontend/assets/grocery/`:
  - `embedder_vocab.json` — `{version, dim, vocab:[...], vectors_int8:[...], scale:[...]}` (or a compact binary the loader reads),
  - `catalog_vectors.json` — `{version, dim, item_ids:[...], vectors_int8:[...], scale:[...]}` for all 3,239 items (embed each item's preferred name),
  - `embedder_golden.json` — e.g. `[{"query":"oat drink","top5_item_ids":[...]}, ...]` across all 4 languages, produced by running the *Python* embed+cosine so Dart can be validated against it.
- Reuse the `{version: ASSET_VERSION}` convention from `build_app_seed.py`.

**Verify (executor)**: `python3 -m py_compile intelligence/ml/build_embedder_bundle.py` → exit 0.

### Step 3 (Dart): `StaticEmbeddingService` — pure-Dart, no runtime

Create `frontend/lib/services/scan/static_embedding_service.dart`. Pure functions
(`@visibleForTesting`), no asset I/O, no native libs:
- `static List<String> tokenize(String text, {required Set<String> vocab})` —
  lowercase, split on `RegExp(r'\s+')`, greedy longest-match phrases against
  `vocab`; for an unmatched token, fall back to `GroceryClassifierService.charTrigrams`
  pieces that are in vocab; drop the rest.
- `static Float32List embed(List<String> tokens, {required Map<String,int> index, required List<Float32List> vectors})` —
  mean-pool the vectors of matched tokens; return a zero vector if none match.
- `static double cosine(Float32List a, Float32List b)` — standard.
The class: lazy-load the two bundles (`embedder_vocab.json`, `catalog_vectors.json`)
via `rootBundle`, dequantize int8→float (`v * scale`), build `index`/`vectors` and
the catalog matrix + `itemIds`. `Future<List<EmbedMatch>> nearest(String query,
{int topK=5})` = tokenize → embed → cosine vs catalog → top-k `EmbedMatch(itemId,
score)`. Fail soft (return `const []`) if the bundle is absent (so the app runs
before the bundle ships). Define `class EmbedMatch { final String itemId; final double score; }`.

**Verify**: `cd frontend && flutter analyze lib/` → exit 0.

### Step 4 (Dart tests): synthetic fixture + golden contract

Create `frontend/test/support/static_embedder_fixture.json` — a tiny hand-built
vocab + 2-D vectors where you can compute cosine by hand. Create
`frontend/test/services/static_embedding_service_test.dart` (model after plan
026's test style): assert `tokenize` (phrase greedy-match, whitespace, OOV
fallback), `embed` (mean-pool correctness, empty→zero), `cosine` (known values),
and `nearest` returns the expected fixture item. These need **no real bundle and
no native libs**. Add a test that *if* `assets/grocery/embedder_golden.json`
exists, every golden query's top-1 matches (skipped when absent — the real bundle
is maintainer-shipped).

**Verify**: `cd frontend && flutter test test/services/static_embedding_service_test.dart` → pass.

### Step 5 (Dart): semantic autocomplete + resolver fallback

- `GrocerySuggestionService`: add an **optional** `StaticEmbeddingService? embedder`
  ctor arg (keep existing call sites compiling, per 026's pattern). In `suggest`,
  when alias-prefix yields few/no results, blend in `embedder.nearest(query)`
  results (map item IDs → canonical items via the DB), de-duped, ranked after exact
  prefix hits. Guard on `embedder == null`.
- `CanonicalResolverService`: add an optional `StaticEmbeddingService? embedder`;
  in the existing `_resolveWithFallback` chain (026), when classifier+fuzzy are
  below threshold, try `embedder.nearest(itemName).first` → map to canonical item.
- Wire providers: a `staticEmbeddingServiceProvider`; pass it into the suggestion
  + resolver providers. `list_detail_screen.dart` keeps calling `suggest` unchanged.

**Verify**: `cd frontend && flutter analyze lib/ test/` → exit 0; `cd frontend && flutter test` → no NEW failures vs baseline.

## Test plan

- `static_embedding_service_test.dart` — pure tokenize/embed/cosine/nearest on the
  synthetic fixture (no bundle, no native libs) + the optional golden-contract test.
- Suggestion/resolver wiring covered by extending their existing tests with a fake
  embedder (scripted `nearest`), asserting semantic results blend in only when
  prefix/fuzzy are weak, and the `embedder == null` path is unchanged.
- Verification: targeted tests pass; full suite shows no new failures.

## Done criteria

- [ ] `python3 -m py_compile intelligence/ml/off_enrich_seed.py intelligence/ml/build_embedder_bundle.py` exits 0
- [ ] `cd frontend && flutter analyze lib/ test/` exits 0
- [ ] `static_embedding_service_test.dart` exists and passes (synthetic fixture)
- [ ] `cd frontend && flutter test` — no NEW failures vs baseline
- [ ] `StaticEmbeddingService` uses **no** `tflite_flutter`/onnx/native runtime (`grep -L`); inference is pure Dart
- [ ] No real bundle binaries committed (only `.gitkeep` / synthetic fixture); bundles are maintainer-shipped
- [ ] North-star gate: no new cloud-inference path; bundles are versioned (`{version: ...}`); OFF usage attributed + separable
- [ ] No files outside the in-scope list modified
- [ ] `plans/README.md` status row updated

## STOP conditions

- Drift check shows an in-scope file changed and excerpts no longer match.
- Model2Vec cannot produce a word/phrase-level custom-vocab model (i.e. the Dart
  trivial-tokenizer assumption fails) — STOP and report; the tokenizer strategy
  needs rethinking before the Dart side is built.
- Wiring the embedder requires touching `list_detail_screen.dart` or other
  out-of-scope UI (it must not — `suggest`/`resolve` signatures are unchanged).
- The synthetic-fixture test can't be made deterministic — report rather than
  loosen assertions.

## Maintainer steps (post-merge, needs Python + model + OFF dump)

1. Download an OFF export (ODbL) for the target markets; run `off_enrich_seed.py`
   → `seed_enriched.json` + `embedder_vocab.txt`.
2. Run `build_embedder_bundle.py` → `embedder_vocab.json`, `catalog_vectors.json`,
   `embedder_golden.json` under `frontend/assets/grocery/`; note the bundle MB.
3. Run the Dart golden-contract test against the real bundle; confirm top-1 parity.
4. (Optional) re-run `build_app_seed.py` from `seed_enriched.json` so the alias
   table also gets the OFF names.

## Phase 2 (later, separate effort): barcode + nutrition surface

Sketch — not this plan. Build an OFF-derived **barcode → canonical item** index
(+ Nutri-Score/eco/allergens) as another versioned bundle; add a barcode-scan
entry point that resolves offline and surfaces health/allergen badges + "healthier
swap" via the embedder's `nearest`. Inherits the north-star law.

## Maintenance notes

- The whole semantic layer is **build-time + on-device** — zero per-prediction
  cost, the core of `INTELLIGENCE-NORTH-STAR.md`.
- Tokenizer parity (Dart ↔ build-time) is the thing to watch in review; the golden
  file is the contract. If the embedder is ever rebuilt with a different vocab
  scheme, regenerate the golden file and re-run the contract test.
- Adding a language later = add its names to the seed (via the DeepSeek pipeline or
  OFF) → rebuild vocab → re-distill. No app release needed (bundles are versioned).
