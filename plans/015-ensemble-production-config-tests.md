# Plan 015: Test the ensemble as shipped (models wired) and make asset fail-soft visible

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- frontend/lib/services/scan/ frontend/test/services/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. (Plans 003/004/007/010 touch nearby
> code — their landed changes are expected, not drift.)

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none hard; run after 003/004/007 if they landed to test the merged behavior
- **Category**: tests
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

The configuration users actually run — `CanonicalResolverService(db, classifier: …, embedder: …, useEnsemble: true)` inside `ScanPipelineService` — has **zero test coverage**: every ensemble test constructs the resolver without models, so the classifier→alias mapping, the embedder's candidate union, and source-agreement scoring are exercised nowhere. Separately, every asset load on the resolution path fails soft **silently** (empty catch → defaults/empty results), so a corrupt classifier, a bad embedder bundle, or a malformed weights file is indistinguishable in the field from "assets not shipped". Two fixes, one plan: model-in-the-loop tests via the existing test seams, and one diagnostics line per fail-soft branch.

## Current state

- Production config — `frontend/lib/services/scan/scan_pipeline_service.dart:37-46`:

```dart
        _resolver = CanonicalResolverService(
          db,
          classifier: GroceryClassifierService(),
          embedder: StaticEmbeddingService(),
          useEnsemble: true,
        ),
```

No test file for `ScanPipelineService` exists (`ls frontend/test/services/ | grep -i pipeline` → nothing).

- Modelless tests: `frontend/test/services/resolution_baseline_test.dart:122-128` explicitly constructs `EnsembleResolver(db)` with a comment that models "need native libs / asset bundles unavailable here"; `candidate_generator_test.dart` and `canonical_resolver_service_test.dart:250-280` likewise never inject models.

- Test seams that already exist:
  - `StaticEmbeddingService.seedForTest(...)` (`static_embedding_service.dart:352-365`) — injects vocab/catalog vectors, runs in-process, no isolate, no assets.
  - `GroceryClassifierService.classify` is an overridable instance method (`grocery_classifier_service.dart:63-66`) — a test subclass returning canned `ClassifierPrediction`s works; the base constructor only wires lazy asset paths, harmless in tests.
  - `CandidateGenerator(db, classifier:, embedder:)` and `EnsembleResolver(db, classifier:, embedder:, scorer:, generator:)` accept injection (`candidate_generator.dart:23-30`, `ensemble_resolver.dart:28-36`).

- Silent fail-soft sites (each needs one diagnostics line, behavior unchanged):
  - `resolution/calibrated_scorer.dart:70-75` (weight-count / feature-name rejection) and `:83` (`catch (_) { return CalibratedScorer(); }`)
  - `grocery_classifier_inference_native.dart:~58` (load failure → `_unavailable = true`)
  - `static_embedding_service.dart:~285, ~410, ~435` (bundle-load and query failures → `const []`)

- Logging conventions: the scan services have **no logging today**; repositories use `package:logger` (`Logger _log = Logger()`, e.g. `grocery_repository.dart:22`). Follow that: a module-level `Logger` per file is acceptable, messages must name the asset and the reason. Do not throw; do not change return values.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze | `cd frontend && dart analyze lib/` | exit 0 |
| New tests | `cd frontend && flutter test test/services/ensemble_with_models_test.dart test/services/scan_pipeline_smoke_test.dart` | pass |
| Full sweep | `cd frontend && flutter test` | pass |

## Scope

**In scope**:
- `frontend/test/services/ensemble_with_models_test.dart` (create)
- `frontend/test/services/scan_pipeline_smoke_test.dart` (create)
- The four lib files listed under "silent fail-soft sites" (one log line per branch)

**Out of scope**:
- Changing any fail-soft *behavior* (still return defaults/empty).
- OCR/capture stages of the pipeline (`OcrService`, `EnhancementService`, capture_*) — the smoke test stubs before them or enters at the resolution stage.
- Wiring telemetry to GlitchTip (`ErrorReporter`) — a follow-up once the log lines prove useful; note in PR.

## Git workflow

- Branch: `advisor/015-ensemble-production-config-tests`
- Commit style: `test(scan): cover the shipped ensemble config; log asset fail-soft`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Model-in-the-loop ensemble test

Create `frontend/test/services/ensemble_with_models_test.dart` (in-memory Drift; copy the seeding helpers from `canonical_resolver_service_test.dart` — items + aliases for two colliding products, e.g. `spaghetti` and `egg_spaghetti`):

- Fake classifier:

```dart
class _FakeClassifier extends GroceryClassifierService {
  final List<ClassifierPrediction> canned;
  _FakeClassifier(this.canned);
  @override
  Future<List<ClassifierPrediction>> classify(String rawText, {int topK = 5}) async =>
      canned.take(topK).toList();
}
```

- Embedder: real `StaticEmbeddingService()..seedForTest(...)` with a 3-word vocab and 2-item catalog of hand-built unit vectors (make the query token's vector cosine-near item 1).
- Cases:
  1. **Union**: a query where fuzzy finds nothing but classifier + embedder each propose a (different) item → both appear as candidates; resolve returns the higher-scored one; `sources` agreement reflected in the winner's score being > the same setup with one source (assert relative ordering, not absolute values).
  2. **Classifier label→alias mapping**: canned prediction whose label matches a seeded alias resolves to that item; a label matching nothing contributes no candidate.
  3. **Model failure ≡ absence**: same query with `_FakeClassifier(const [])` and an unseeded embedder → same result as the modelless ensemble (parity with the existing baseline tests).

**Verify**: `cd frontend && flutter test test/services/ensemble_with_models_test.dart` → pass

### Step 2: Pipeline smoke test

Create `frontend/test/services/scan_pipeline_smoke_test.dart`: construct `ScanPipelineService(db: memoryDb)` and assert construction succeeds and — entering at the resolution stage, since OCR needs a real image — that its resolver is the ensemble: the cleanest observable is calling the pipeline's resolution step if it's factored out; if `run()` is the only entry, instead assert via `CanonicalResolverService(db, useEnsemble: true)` equivalence is already covered by Step 1 and reduce this file to: constructing `ScanPipelineService` in a test environment does not throw and `corrections` getter returns a usable service. (Keep the file — it pins the constructor wiring, which is where `useEnsemble: true` lives; a regression that drops the flag or a model argument breaks compilation or this smoke.)

**Verify**: `cd frontend && flutter test test/services/scan_pipeline_smoke_test.dart` → pass

### Step 3: Diagnostics on fail-soft

Add one `Logger` warn per branch listed in "Current state", e.g. in `calibrated_scorer.dart`:

```dart
    } catch (e) {
      _log.w('resolution_weights.json unavailable, using default weights: $e');
      return CalibratedScorer();
    }
```

and for the parity rejections, name which guard tripped (`weights length`, `feature_names mismatch`). Same pattern for classifier load failure and the three embedder branches (asset name + error). Keep messages single-line, no user data (raw query text must NOT be logged — only asset names/reasons).

**Verify**: `cd frontend && dart analyze lib/` → exit 0; `flutter test` → pass (the logger writes to console in tests; no assertion on log output needed)

## Test plan

Steps 1–2 are the plan's product. Full-suite pass proves the log lines and fakes changed no behavior. If plans 003/004 landed, their suites re-run green (Step 3 touches shared files).

## Done criteria

- [ ] Both new test files exist and pass
- [ ] `grep -rn "catch (_) {}" frontend/lib/services/scan/ --include="*.dart"` → no bare-silent catches remain on the listed sites (empty catches elsewhere in scan/ that were not listed: leave, but note them in the report)
- [ ] `grep -rn "_log.w" frontend/lib/services/scan/resolution/calibrated_scorer.dart frontend/lib/services/scan/static_embedding_service.dart` → present
- [ ] `cd frontend && flutter test` exits 0
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `GroceryClassifierService.classify` cannot be overridden (became sealed/final since planning) — report; do not add a mocking package.
- `seedForTest` was removed or its signature changed.
- Adding `package:logger` imports to `calibrated_scorer.dart` creates a dependency cycle or breaks const-ness — fall back to `debugPrint` guarded by `kDebugMode` for that file only, and say so.

## Maintenance notes

- Follow-up worth doing once log lines exist: count fail-soft occurrences via `ErrorReporter` in release builds so a broken asset in a shipped build is visible in GlitchTip.
- These tests are the safety net for Plan 006 (shipping a real weights bundle) and Plan 012 (classifier retrain) — run them in any PR touching `assets/models/` or `assets/grocery/`.
