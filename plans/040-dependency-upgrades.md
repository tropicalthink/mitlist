# Plan 040: Upgrade low-risk Flutter plugins; scope the framework migrations

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- frontend/pubspec.yaml frontend/pubspec.lock`
> On any change, re-run `flutter pub outdated` before starting.

## Status

- **Priority**: P3
- **Effort**: M (leaf bumps); the framework migrations are separate L efforts
- **Risk**: LOW for leaf plugins; MED–HIGH for Riverpod/go_router (deferred)
- **Depends on**: none
- **Category**: migration
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

Several Flutter dependencies are multiple majors behind, cutting off security and
plugin fixes: `firebase_core` 3→4, `firebase_messaging` 15→16, `sentry_flutter`
8→9, `share_plus` 10→13, `connectivity_plus` 6→7 (leaf plugins, low blast radius),
plus `flutter_riverpod` 2→3 and `go_router` 14→17 (each a multi-day migration
touching every provider/route). This plan does the **low-risk leaf bumps now** and
**scopes** the two framework migrations as separate follow-up plans rather than
attempting them blind. Backend Go deps are current — frontend only.

## Current state

Run `cd frontend && flutter pub outdated` to see the live gaps. As of the audit:

| Package | Current | Latest | Tier |
|---|---|---|---|
| firebase_core | 3.x | 4.x | leaf |
| firebase_messaging | 15.x | 16.x | leaf |
| sentry_flutter | 8.14.2 | 9.x | leaf |
| share_plus | 10.x | 13.x | leaf |
| connectivity_plus | 6.x | 7.x | leaf |
| flutter_riverpod | 2.6.1 | 3.x | framework (defer) |
| go_router | 14.8.1 | 17.x | framework (defer) |

`sqlite3_flutter_libs` is at `0.6.0+eol` — note it but do not bump blindly (the
`+eol` line may be intentional pinning for the Drift stack; STOP if unsure).

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Outdated | `cd frontend && flutter pub outdated` | shows gaps |
| Get | `cd frontend && flutter pub get` | resolves |
| Analyze | `cd frontend && dart analyze lib/` | `No issues found!` |
| Test | `cd frontend && flutter test` | pass |

## Scope

**In scope**:
- `frontend/pubspec.yaml`, `frontend/pubspec.lock`
- Minimal call-site fixes required by the leaf-plugin bumps (e.g. a renamed API in
  `share_plus`), in the files that use those plugins only:
  `frontend/lib/services/fcm_service.dart`,
  `frontend/lib/services/error_reporter.dart` (Sentry),
  `frontend/lib/services/share_target_service.dart` / share callers,
  `frontend/lib/services/connectivity_service.dart`.

**Out of scope** (do NOT attempt here):
- `flutter_riverpod` 2→3 and `go_router` 14→17 — each is a separate dedicated
  migration plan (see Maintenance). Do not bump them in this plan.
- `sqlite3_flutter_libs` — leave unless you confirm the `+eol` pin is safe to move.

## Git workflow

- Branch: `advisor/040-dependency-upgrades`
- Commit per plugin (or per small group); conventional commits, e.g.
  `chore(deps): bump sentry_flutter 8→9`.

## Steps

### Step 1: Bump one leaf plugin at a time

For each leaf plugin, update its constraint in `pubspec.yaml`, run
`flutter pub get`, then `dart analyze lib/`. Fix any breaking-API call sites in
the in-scope files (consult the package changelog for the major bump). Run
`flutter test` after each. **One plugin per commit** so a regression is bisectable.

Suggested order (least entangled first): `connectivity_plus`, `share_plus`,
`sentry_flutter`, then `firebase_core` + `firebase_messaging` together (they
version in lockstep).

**Verify after each**: `cd frontend && dart analyze lib/` → `No issues found!`
and `cd frontend && flutter test` → pass.

### Step 2: Confirm push + crash-reporting still work at the code level

Firebase (push) and Sentry (crash reporting) are behind these bumps. Since these
can't be fully exercised in unit tests, verify: analyze clean, the initialization
code compiles against the new API, and any changed method signatures are updated.
Note in your report that runtime verification (actual push/crash delivery) is
deferred to manual QA.

**Verify**: `cd frontend && flutter test` → pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd frontend && flutter pub get` resolves cleanly
- [ ] `cd frontend && dart analyze lib/` exits 0
- [ ] `cd frontend && flutter test` passes (only the known welcome-screen case may fail)
- [ ] `flutter pub outdated` shows the five leaf plugins on their new majors
- [ ] `flutter_riverpod` and `go_router` are UNCHANGED (still 2.x / 14.x)
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- A leaf-plugin major bump cascades into a framework dependency conflict (e.g.
  requires a Riverpod/go_router bump) — stop at that plugin and report; do not
  pull the framework migration in.
- `firebase`/`sentry` init APIs changed in a way that needs more than a mechanical
  call-site fix — report before improvising.

## Maintenance notes

- **Deferred framework migrations (each its own plan, characterization tests
  first):**
  - `flutter_riverpod` 2→3: broad — every `Provider`/`ref` usage. Needs a
    read-through of the 3.0 migration guide and a test net on the most-used
    providers before starting.
  - `go_router` 14→17: touches `router.dart` and every route definition/redirect.
- Reviewer: check the changelogs for the bumped plugins for behavior changes
  (not just API), especially Firebase messaging permission/registration and
  Sentry's default sampling.
