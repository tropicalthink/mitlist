# Plan 032: Fully on-device scanning — default on-device (phase 1), then on-device VLM (phase 2)

> **This plan has two phases.** Phase 1 (below, fully specified) makes on-device
> the default and gates the CrofAI cloud call behind opt-in — small, ship it now,
> it stops the per-scan cost. Phase 2 (sketched at the end) adds a small
> on-device VLM (SmolVLM/Moondream) so the cloud is unnecessary even for hard
> scans, then retires it. Execute phase 1 first; phase 2 is a later, larger,
> spike-flavored effort and will be fleshed out into full steps when phase 1 has
> landed. Folds the former plan 033.

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If a STOP condition occurs, stop and report — do not improvise.
> When done, update the status row for this plan in `plans/README.md` unless a
> reviewer dispatched you and told you they maintain the index.
>
> **Read first**: `plans/INTELLIGENCE-NORTH-STAR.md` — this plan exists to
> remove the one current violation of that law (per-request cloud inference in
> the free hosted tier).
>
> **Drift check (run first)**:
> `git diff --stat 6c0df971..HEAD -- frontend/lib/services/scan/routing_service.dart frontend/lib/services/scan/scan_pipeline_service.dart`
> If either changed since this plan was written, compare against the "Current
> state" excerpts before proceeding; on a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1 (stops ongoing cloud cost)
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt / cost
- **Planned at**: commit `6c0df971`, 2026-06-13

## Why this matters

mitlist's hosted tier is **free and open-source** — every CrofAI/kimi cloud
vision call is pure cost with no revenue, and it's the one place the app does
per-request cloud inference (see `plans/INTELLIGENCE-NORTH-STAR.md`). Today the
scanner silently escalates to CrofAI whenever on-device OCR looks weak. This
plan makes **on-device the default and the cloud call opt-in** (off by default),
so the free tier stops paying per scan immediately, while self-hosters and users
who explicitly enable it keep the cloud fallback.

This is deliberately the *cheap, safe* first step. The richer fix — an on-device
VLM that makes the cloud unnecessary even for hard scans — is plan 033.

## Current state

- `frontend/lib/services/scan/routing_service.dart` — decides on-device vs
  cloud. Three branches return `RoutingDecision.cloud(...)` (lines ~28–43):
  ```dart
  if (substantive.isEmpty) {
    if (!isOnline) return const RoutingDecision.onDevice('offline, keeping on-device despite empty result');
    return const RoutingDecision.cloud('no text recognised on-device');
  }
  if (substantive.length < 2 && isOnline) {
    return const RoutingDecision.cloud('too few lines recognised, possible cursive');
  }
  final hasLongLines = substantive.any((l) => l.text.length > 80);
  if (hasLongLines && isOnline) {
    return const RoutingDecision.cloud('long lines detected, likely a receipt or recipe');
  }
  return RoutingDecision.onDevice('${substantive.length} lines recognised on-device');
  ```
  `decide` signature today: `RoutingDecision decide(List<OcrLine> lines, {bool isOnline = true})`.

- `frontend/lib/services/scan/scan_pipeline_service.dart` — calls routing at
  line ~66 and runs cloud at ~68:
  ```dart
  final decision = _routing.decide(lines, isOnline: isOnline);
  if (!decision.useOnDevice) {
    return _runCloud(imageBytes);
  }
  ```
  `run(...)` already takes `bool isOnline = true` (line ~57).

- Persisted-preference pattern to copy — `frontend/lib/providers/theme_provider.dart`
  (full file is the exemplar): a `StateNotifierProvider` backed by
  `SharedPreferences`, with a `static const _key`, a `_load()` in the
  constructor, and a `set(...)` that writes the pref then updates `state`.

- Settings UI lives in `frontend/lib/screens/you/account_screen.dart`.

Repo conventions: providers in `frontend/lib/providers/`, one notifier per
concern; `shared_preferences` is already a dependency (used by theme_provider).

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Install | `cd frontend && flutter pub get` | exit 0 |
| Analyze | `cd frontend && flutter analyze lib/ test/` | exit 0, no new errors |
| Tests | `cd frontend && flutter test test/services/routing_service_test.dart` | all pass |
| Full suite | `cd frontend && flutter test` | no NEW failures vs baseline |

(Use `flutter analyze lib/ test/` — a bare `flutter analyze` also walks the SDK
and reports thousands of unrelated issues.)

## Scope

**In scope**:
- `frontend/lib/services/scan/routing_service.dart` (add an `allowCloud` gate)
- `frontend/lib/providers/scan_provider.dart` OR a new
  `frontend/lib/providers/scan_settings_provider.dart` (the persisted toggle)
- `frontend/lib/services/scan/scan_pipeline_service.dart` (thread the toggle to `decide`)
- `frontend/lib/screens/you/account_screen.dart` (a switch to enable cloud scan)
- `frontend/test/services/routing_service_test.dart` (create)

**Out of scope** (do NOT touch):
- `frontend/lib/services/scan_service.dart` (the CrofAI client) — it stays; we
  only stop calling it by default. Do not delete or modify it.
- The on-device pipeline stages (OCR/extraction/resolution) — unchanged.
- Anything related to plan 033 (on-device VLM) — not this plan.

## Git workflow

- Branch: `advisor/032-on-device-scan-default`
- Conventional commits (e.g. `feat(scan): default to on-device, gate cloud behind opt-in`).
- Do NOT push.

## Steps

### Step 1: Add an `allowCloud` gate to RoutingService

Change `decide` to `RoutingDecision decide(List<OcrLine> lines, {bool isOnline = true, bool allowCloud = false})`.
At the very top of the method, short-circuit:
```dart
if (!allowCloud) {
  return RoutingDecision.onDevice('cloud scan disabled');
}
```
Leave all existing heuristics below unchanged — they only matter when cloud is
allowed. Default `allowCloud = false` encodes "on-device by default."

**Verify**: `cd frontend && flutter analyze lib/` → exit 0.

### Step 2: Persisted toggle provider

Create a `StateNotifierProvider<CloudScanNotifier, bool>` (default `false`)
modeled exactly on `ThemeModeNotifier` in `theme_provider.dart`: `static const
_key = 'allow_cloud_scan';`, load in constructor, `set(bool)` writes the pref
then updates `state`. Put it in `scan_provider.dart` if that file exists,
otherwise a new `scan_settings_provider.dart`.

**Verify**: `cd frontend && flutter analyze lib/` → exit 0.

### Step 3: Thread the toggle into the pipeline

`ScanPipelineService.run` must learn whether cloud is allowed. Add a
`bool allowCloud = false` parameter to `run(...)` and pass it through:
`final decision = _routing.decide(lines, isOnline: isOnline, allowCloud: allowCloud);`
Then update the call site(s) that invoke `run(...)` to read the provider and pass
its value. Find them: `grep -rn "\.run(" frontend/lib | grep -i scan` plus the
scan launcher (`frontend/lib/widgets/list/list_scan_launcher.dart`) and
`frontend/lib/screens/scanner/`. At each call site, read the toggle provider and
pass `allowCloud:`.

**Verify**: `cd frontend && flutter analyze lib/` → exit 0; `grep -n "allowCloud" frontend/lib/services/scan/scan_pipeline_service.dart` shows the param threaded.

### Step 4: Settings switch in account screen

Add a `SwitchListTile` (or the repo's settings-row widget if one exists — match
the surrounding style in `account_screen.dart`) labeled e.g. **"Cloud scan
assist"** with a subtitle like *"Send hard-to-read scans to the cloud for better
results. Off by default — scanning works fully on-device."* Wire it to the
toggle provider's value + `set(...)`.

**Verify**: `cd frontend && flutter analyze lib/` → exit 0.

### Step 5: Tests

Create `frontend/test/services/routing_service_test.dart` (plain `test`/`expect`,
model after `frontend/test/services/token_store_test.dart`). Build `OcrLine`
lists (see `scan_models.dart` for the constructor) and assert:
- `allowCloud: false` → **always** `useOnDevice == true`, for every case that
  would otherwise go cloud: empty lines, single line, a >80-char line.
- `allowCloud: true` reproduces the old behavior: empty/online → cloud; single
  line/online → cloud; long line/online → cloud; normal multi-line → on-device;
  and `isOnline: false` stays on-device.

**Verify**: `cd frontend && flutter test test/services/routing_service_test.dart` → all pass.

### Step 6: Full gates

**Verify**:
- `cd frontend && flutter analyze lib/ test/` → exit 0.
- `cd frontend && flutter test` → no NEW failures beyond the known pre-existing
  `frontend_flows_test.dart` issue (see `plans/README.md`).

## Test plan

- New: `routing_service_test.dart` — the gate (default-off forces on-device) and
  the preserved heuristics when opted in. This is the regression guard that the
  free tier never silently calls cloud.
- Pattern: `token_store_test.dart`.
- Verification: file passes; full suite shows no new failures.

## Done criteria

- [ ] `cd frontend && flutter analyze lib/ test/` exits 0
- [ ] `routing_service_test.dart` exists and passes; with `allowCloud: false`, no input routes to cloud
- [ ] `cd frontend && flutter test` — no NEW failures vs baseline
- [ ] `grep -n "allowCloud" frontend/lib/services/scan/routing_service.dart frontend/lib/services/scan/scan_pipeline_service.dart` shows the gate threaded end to end
- [ ] Default is OFF: the toggle provider initial state is `false`
- [ ] `scan_service.dart` (CrofAI client) is unmodified (`git status`)
- [ ] No files outside the in-scope list are modified
- [ ] North-star gate (from `INTELLIGENCE-NORTH-STAR.md`): no new code path does cloud inference unless the explicit opt-in is on
- [ ] `plans/README.md` status row updated

## STOP conditions

- The drift check shows `routing_service.dart` or `scan_pipeline_service.dart`
  changed and the excerpts no longer match.
- `run(...)` has more call sites than expected and threading the toggle would
  require touching out-of-scope files — report the list and stop.
- A NEW `flutter test` failure appears unrelated to the known
  `frontend_flows_test.dart` issue.

## Phase 2 (later): on-device VLM for hard scans — retire the cloud

> Sketch only — do **not** execute as part of phase 1. Fleshed into full steps
> once phase 1 lands and a runtime is chosen. Inherits the
> `INTELLIGENCE-NORTH-STAR.md` law (must run on-device, license green-list).

Goal: make the cloud path unnecessary even for cursive/receipt scans by running a
small open VLM **on-device**, so `RoutingDecision.cloud` is never needed and the
CrofAI client can eventually be deleted.

- **Model candidates** (Apache-2.0, license green-list): **SmolVLM-256M/500M** or
  **Moondream2** — both edge-sized and OCR-capable. Pick the smallest that clears
  a handwriting/receipt eval.
- **Runtime decision (the spike):** Flutter has no first-class VLM runtime. Options
  to evaluate, in order of likely fit: MediaPipe LLM Inference (GenAI tasks),
  llama.cpp via FFI, or ONNX Runtime. This choice is the main risk — Phase 2
  should START as a runtime spike with a STOP-and-report gate before committing.
- **Integration:** add a third `RoutingDecision` outcome (on-device VLM) that the
  router prefers over cloud when OCR is weak and a VLM asset is present. The VLM
  produces structured items that feed the *same* extraction → resolve → confidence
  pipeline (it replaces only the OCR/understanding front-end, not resolution).
- **Asset shipping:** the VLM weights ship as a versioned bundle (same mechanism
  as 028's bundles), not bundled in the APK if too large — download-on-demand,
  version-gated.
- **Exit:** on a handwriting/receipt eval set, on-device VLM ≥ the cloud
  baseline; then flip the default and remove the CrofAI client + the opt-in
  toggle from phase 1.

## Maintenance notes

- Phase 1 is the cheap, safe cost-stopper; phase 2 is the real "fully offline
  scanning" win. When phase 2 lands, the phase-1 opt-in toggle and the CrofAI
  client (`scan_service.dart`) can both be deleted.
- Self-hosters who *want* the cloud fallback just flip the phase-1 toggle —
  nothing is removed, only defaulted off.
- Reviewer (phase 1): confirm the toggle truly defaults off and that every
  `run(...)` call site passes the provider value (a missed call site re-opens the
  cost leak).
