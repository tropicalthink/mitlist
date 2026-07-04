# Plan 013: Stop paying a 5 MB JSON parse on every cold start

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- frontend/lib/services/grocery_seed_loader.dart intelligence/ml/build_app_seed.py frontend/pubspec.yaml`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S–M
- **Risk**: LOW
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

`GrocerySeedLoader.loadIfNeeded()` runs on every cold start. Its seed branch reads and fully `jsonDecode`s the 5.4 MB `seed.json` **before** the version gate that decides whether anything needs ingesting — so the common no-op launch pays a multi-megabyte string read plus parse on the calling isolate purely to read one `version` int. On a version bump it additionally builds ~120k alias companions on the same isolate. Two bounded fixes: a tiny sidecar version asset consulted before touching the big file, and moving the reseed-case decode off the main isolate.

## Current state

- `frontend/lib/services/grocery_seed_loader.dart:34-48` — parse before gate:

```dart
  Future<void> _loadSeedIfNeeded() async {
    final raw = await rootBundle.loadString(_seedAsset);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final assetVersion = (json['version'] as num?)?.toInt() ?? 0;

    final installedVersion = await _db.getGroceryVersion(_globalGroupId);
    final existing = await _db.getCanonicalItemsByGroup(_globalGroupId);
    if (existing.isNotEmpty && installedVersion >= assetVersion) return;
    ...
```

The store-aisles (104 KB) and OFF-aliases (17 KB) branches have the same shape but trivial cost — leave them.

- `_ingestSeed` (lines 134-202) builds all companions in memory; inserts are already chunked (comment at line 194 about allocation spikes acknowledges the concern but only for the insert phase).
- Caller: `frontend/lib/providers/list_provider.dart:30` (`loadIfNeeded` on startup).
- Asset generator: `intelligence/ml/build_app_seed.py` — writes `frontend/assets/grocery/seed.json` with `ASSET_VERSION = 5` (line 28). The pubspec bundles the whole `assets/grocery/` directory (`frontend/pubspec.yaml:118`), so a new sidecar file needs no pubspec change.
- Isolate precedent in this codebase: `frontend/lib/services/scan/static_embedding_service.dart` runs decode work in a spawned isolate with `RootIsolateToken`/`BackgroundIsolateBinaryMessenger` (line ~391). For this plan, the far simpler `compute(jsonDecode, raw)` suffices: the asset string is loaded on the main isolate (I/O), only the parse moves off it.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze | `cd frontend && dart analyze lib/` | exit 0 |
| Seed tests | `cd frontend && flutter test test/services/` | pass (look for any existing seed-loader test: `ls frontend/test/services/ \| grep -i seed`) |
| Full | `cd frontend && flutter test` | pass |

## Scope

**In scope**:
- `frontend/lib/services/grocery_seed_loader.dart`
- `frontend/assets/grocery/seed.version.json` (create)
- `intelligence/ml/build_app_seed.py` (emit the sidecar)
- `frontend/test/services/grocery_seed_loader_test.dart` (create or extend)

**Out of scope**:
- The embedder bundle's own lazy load (`static_embedding_service.dart`) — it loads on first semantic query, not cold start.
- Gzipping assets / pre-built SQLite shipping — bigger redesign; note as follow-up.
- The store-aisles / OFF branches — sub-page-cache cost.

## Git workflow

- Branch: `advisor/013-seed-loader-cold-start`
- Commit style: `perf(grocery): sidecar version check + off-main-isolate seed parse`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Emit and commit the sidecar

- In `build_app_seed.py`, after writing `seed.json`, also write `frontend/assets/grocery/seed.version.json` containing exactly `{"version": ASSET_VERSION}`.
- Create the file by hand now with `{"version": 5}` — it must match the committed `seed.json`'s `version` field (confirm: `python3 -c "import json;print(json.load(open('frontend/assets/grocery/seed.json'))['version'])"` → `5`). Do NOT regenerate `seed.json` itself.

**Verify**: the python one-liner above prints the same number as the sidecar

### Step 2: Gate on the sidecar

Rework `_loadSeedIfNeeded`:

```dart
  Future<void> _loadSeedIfNeeded() async {
    final installedVersion = await _db.getGroceryVersion(_globalGroupId);
    final sidecarVersion = await _readSidecarVersion();
    final existing = await _db.getCanonicalItemsByGroup(_globalGroupId);
    if (sidecarVersion != null &&
        existing.isNotEmpty &&
        installedVersion >= sidecarVersion) {
      return; // common case: no 5 MB parse
    }

    final raw = await rootBundle.loadString(_seedAsset);
    final json = await compute(_decodeJsonMap, raw);
    final assetVersion = (json['version'] as num?)?.toInt() ?? 0;
    if (existing.isNotEmpty && installedVersion >= assetVersion) return;

    if (existing.isNotEmpty) {
      await _db.clearGlobalSeed(_globalGroupId);
    }
    await _ingestSeed(json);
    await _db.setGroceryVersion(_globalGroupId, assetVersion);
  }

  Future<int?> _readSidecarVersion() async {
    try {
      final raw = await rootBundle.loadString('assets/grocery/seed.version.json');
      return ((jsonDecode(raw) as Map<String, dynamic>)['version'] as num?)
          ?.toInt();
    } catch (_) {
      return null; // sidecar absent (older asset set) → full check
    }
  }
```

with a top-level function (compute requires it):

```dart
Map<String, dynamic> _decodeJsonMap(String raw) =>
    jsonDecode(raw) as Map<String, dynamic>;
```

Keep the inner `assetVersion` re-check (shown above): the sidecar is advisory; the big file's own version remains authoritative, so a mismatched sidecar can trigger a redundant parse but never a wrong reseed decision.

`compute` needs `package:flutter/foundation.dart` — add the import. Note: in widget tests `compute` runs synchronously on the same isolate (Flutter test binding) — no test-environment special-casing needed.

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 3: Tests

In `frontend/test/services/grocery_seed_loader_test.dart` (create if absent; in-memory Drift + a fake `AssetBundle`? — `rootBundle` is hard-wired in the loader. Check first: if the loader has no bundle seam, add an optional `@visibleForTesting AssetBundle? bundle` parameter defaulting to `rootBundle`, mirroring `CalibratedScorer.load({AssetBundle? bundle})` at `calibrated_scorer.dart:62` — that's the established seam pattern in this codebase):

1. Sidecar version == installed version and items exist → the big asset is never requested (assert via a counting fake bundle that `seed.json` was not loaded).
2. Sidecar version > installed → full load runs, items ingested, version recorded.
3. No sidecar in the bundle → falls through to the full check (today's behavior).

**Verify**: `cd frontend && flutter test test/services/grocery_seed_loader_test.dart` → all pass; `flutter test` → pass

## Test plan

Step 3's three cases; the counting-fake-bundle assertion in case 1 is the point of the plan — it machine-checks "no 5 MB parse on a no-op launch".

## Done criteria

- [ ] `frontend/assets/grocery/seed.version.json` exists and matches `seed.json`'s version
- [ ] `grep -n "seed.version.json" intelligence/ml/build_app_seed.py` → the generator emits it
- [ ] `grep -n "compute(" frontend/lib/services/grocery_seed_loader.dart` → decode is off-isolate
- [ ] New tests pass; `cd frontend && flutter test` exits 0
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Adding the `AssetBundle` seam changes the loader's public constructor in a way that breaks callers beyond `list_provider.dart:30` — list them.
- `compute` cannot ship the decoded map across the isolate boundary (it can — JSON maps are sendable — but if a custom type sneaks in, report).
- The committed `seed.json` version is not 5 (asset regenerated since planning) — write the sidecar to match whatever it is and note it.

## Maintenance notes

- **The sidecar must be regenerated with the seed.** `build_app_seed.py` now writes both; a hand-edited seed without the sidecar bump silently skips ingest on devices already at the old version — the inner authoritative check only runs when the sidecar says "newer or unknown".
- Follow-up (out of scope): shipping the seed as a pre-built SQLite file (attach + copy) would remove the ingest entirely; `_ingestSeed`'s companion build is the remaining big-allocation phase on version-bump launches.
- Reviewer should scrutinize: the fail-soft `_readSidecarVersion` and that case-1's counting bundle really counts `loadString` calls per key.
