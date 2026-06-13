# Plan 017: Enable resource-safety and async lints in analysis_options.yaml

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 9c9b04f3..HEAD -- frontend/analysis_options.yaml`
> On a mismatch with "Current state", treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/011-outbox-hardening.md (its fixes clear the largest
  expected `cancel_subscriptions` violations first)
- **Category**: dx
- **Planned at**: commit `9c9b04f3`, 2026-06-11

## Why this matters

`frontend/analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`
with an empty `rules:` section — no resource-cleanup or async-safety lints. The
unstored connectivity subscription fixed by plan 011 is exactly the class of bug
`cancel_subscriptions` flags at write time. Cheap, permanent guardrail.

## Current state

`frontend/analysis_options.yaml` — `include: package:flutter_lints/flutter.yaml`;
`linter: rules:` contains only commented-out examples (`# avoid_print: false`,
`# prefer_single_quotes: true`).

Repo conventions the rule choice must respect: single quotes are already the
codebase style; `Logger` is used instead of print.

## Commands you will need

| Purpose | Command (run in `frontend/`) | Expected on success |
|---------|------------------------------|---------------------|
| Analyze | `dart analyze lib/ test/`    | exit 0 (after fixes) |
| Tests   | `flutter test`               | all pass            |

## Scope

**In scope**:
- `frontend/analysis_options.yaml`
- Mechanical fixes in `frontend/lib/` and `frontend/test/` for violations of the
  newly enabled rules ONLY (each fix must be local and behavior-preserving)

**Out of scope**:
- Enabling rules that demand sweeping rewrites this cycle (see Step 1 triage).
- Any behavioral change. If a violation fix would change behavior, suppress with
  a `// ignore:` + brief comment and report it instead.

## Git workflow

- Branch: `chore/lint-strictness` off `new-main-fr`.
- Two commits: `chore: enable resource-safety lints`, `fix: resolve new lint violations`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Enable candidates and triage

Add to `linter: rules:`:

```yaml
    cancel_subscriptions: true
    close_sinks: true
    unawaited_futures: true
    avoid_slow_async_io: true
    only_throw_errors: true
    prefer_single_quotes: true
    avoid_empty_else: true
    throw_in_finally: true
```

Run `dart analyze lib/ test/` and count violations per rule. Triage: keep every
rule with ≤ ~30 mechanically fixable violations. If a rule explodes (likely
candidate: `unawaited_futures` — fire-and-forget is common here), either fix
sites by wrapping intentional cases in `unawaited(...)` (`dart:async`, already a
repo convention from sse_service) if the count is manageable, or drop that rule
and record the count in your report.

### Step 2: Fix violations

Mechanical fixes only: store-and-cancel subscriptions, `unawaited(...)` wrappers,
quote normalization. One commit.

**Verify**: `dart analyze lib/ test/` → exit 0 (zero infos from the new rules).

### Step 3: Full suite

**Verify**: `flutter test` → all pass.

## Test plan

No new tests — behavior-preserving. The full suite is the gate.

## Done criteria

- [ ] `analysis_options.yaml` enables ≥5 of the listed rules
- [ ] `dart analyze lib/ test/` exits 0
- [ ] `flutter test` exits 0
- [ ] Any dropped rule documented in the index row with its violation count
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- A violation fix is not behavior-preserving and not cleanly `// ignore:`-able.
- Total violations exceed ~80 after dropping `unawaited_futures` (the codebase
  state differs from planning assumptions — re-triage with the maintainer).

## Maintenance notes

- These rules now gate `dart analyze` — CI (still deferred) would make them
  un-skippable.
- Reviewer: scan the fix commit for any non-mechanical change; each `// ignore:`
  must carry a justification comment.
