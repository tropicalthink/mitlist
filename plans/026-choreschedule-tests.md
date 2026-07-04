# Plan 026: Chore recurrence date-math has direct unit tests

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- backend/internal/choreschedule/schedule.go`
> If it changed, compare the excerpt below to live code first; on mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW (test-only)
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

`NextDueForRule` is the single source of truth for when every scheduled chore
next comes due — the reason the chores feature exists. It has substantial pure
date logic (hourly/daily/weekly/monthly/yearly/adaptive branches, interval
multipliers, `StartDate` clamping, `TrackDateOnly` truncation, and a `Rollover`
re-entrancy loop) and **zero** direct tests. Off-by-one, empty-`days` weekly
handling, and the rollover loop would ship silently and surface as wrong due
dates for users. These are pure functions with no DB — a table-driven test is
cheap and high-value, and it's a prerequisite safety net before anyone touches
this file.

## Current state

`backend/internal/choreschedule/schedule.go` — the whole package is one file with
no `_test.go`. Key functions:

```go
// schedule.go:57-107
func NextDueForRule(from time.Time, rule Rule) *time.Time {
	interval := rule.Interval
	if interval <= 0 { interval = 1 }
	base := from
	if rule.StartDate != nil && from.Before(*rule.StartDate) { base = *rule.StartDate }

	var due time.Time
	switch NormalizeFrequency(rule.Frequency) {
	case FrequencyHourly:  due = base.Add(time.Duration(interval) * time.Hour)
	case FrequencyDaily:   due = base.AddDate(0, 0, interval)
	case FrequencyWeekly:  due = nextWeeklyDue(base, interval, rule.PeriodConfig)
	case FrequencyMonthly: due = base.AddDate(0, interval, 0)
	case FrequencyYearly:  due = base.AddDate(interval, 0, 0)
	case FrequencyAdaptive:
		if rule.AverageSpacing == nil || *rule.AverageSpacing <= 0 { return nil }
		due = base.Add(*rule.AverageSpacing)
	default: return nil
	}
	if rule.TrackDateOnly {
		due = time.Date(due.Year(), due.Month(), due.Day(), 0, 0, 0, 0, due.Location())
	}
	if rule.Rollover {
		now := time.Now().UTC()
		for due.Before(now) {
			next := NextDueForRule(due, Rule{ ... })   // recursive; guarded by !next.After(due) break
			...
		}
	}
	return &due
}
```
Also `NextDue(from, frequency)` (`:53`) — thin wrapper; `nextWeeklyDue(from,
interval, days)` (`:109-139`) — day-of-week selection with interval weeks,
returns `from + 7*interval` when `days` is empty or none match; and
`NormalizeFrequency`/`NormalizeRotationType`/`IsScheduled` (`:16-40`).

The `Rollover` loop uses `time.Now()`, so tests that exercise rollover must pick
a `from`/`StartDate` far enough in the past that the outcome is deterministic
relative to "now" (assert the result is `>= now` and on the correct cadence),
rather than asserting an exact wall-clock timestamp.

## Commands you will need

| Purpose | Command                                                    | Expected |
|---------|------------------------------------------------------------|----------|
| Test    | `cd backend && go test ./internal/choreschedule/ -v`       | all pass |
| Cover   | `cd backend && go test ./internal/choreschedule/ -cover`   | prints coverage |

## Scope

**In scope**:
- `backend/internal/choreschedule/schedule_test.go` (create)

**Out of scope**:
- `schedule.go` itself — **do not change the implementation.** These are
  characterization tests: they lock in current behavior. If a test reveals what
  looks like a bug, STOP and report it (do not "fix" it here — a behavior change
  belongs in its own plan with the callers reviewed).

## Git workflow

- Branch: `advisor/026-choreschedule-tests`
- Conventional commit: `test(choreschedule): cover NextDueForRule date math`.

## Steps

### Step 1: Table-driven tests for `NextDueForRule`

Create `schedule_test.go` in package `choreschedule`. Use a fixed base time
(e.g. `time.Date(2026, 3, 1, 9, 0, 0, 0, time.UTC)`). Table cases:
- Hourly interval 1 and 3.
- Daily interval 1 and 5.
- Weekly with empty `PeriodConfig` (→ +7*interval), interval 1 and 2.
- Weekly with a `days` subset (e.g. `["monday","thursday"]`) that must pick the
  next matching weekday, including a case where the next match crosses a week
  boundary.
- Monthly and Yearly interval 1 and 2.
- Adaptive with a set `AverageSpacing` and with `nil`/zero (→ nil).
- `StartDate` in the future (base clamps forward to StartDate).
- `TrackDateOnly` truncates the time-of-day to 00:00.
- `interval <= 0` normalizes to 1.
- An unscheduled/`none` frequency → nil.

Assert exact timestamps for the non-rollover cases.

**Verify**: `cd backend && go test ./internal/choreschedule/ -run NextDue -v` → pass.

### Step 2: Rollover behavior

Add cases with `Rollover: true` and a `from` far in the past. Assert the result
is not before `time.Now().UTC()` and lands on the expected cadence (e.g. for
daily, `result.Sub(base) % 24h == 0`). Include a case that would loop many times
to confirm it terminates (the loop is guarded by `!next.After(due)`).

**Verify**: `cd backend && go test ./internal/choreschedule/ -run Rollover -v` → pass.

### Step 3: Normalization helpers

Add small tests for `NormalizeFrequency` (manual→none, unknown→none, valid
passthrough), `IsScheduled`, and `NormalizeRotationType`.

**Verify**: `cd backend && go test ./internal/choreschedule/ -v` → all pass.

## Test plan

- New file `schedule_test.go`, table-driven, standard-library `testing` only.
- Pattern: model on any existing `backend/internal/**/*_test.go` that is
  table-driven and DB-free.
- Verification: `cd backend && go test ./internal/choreschedule/ -cover` → passes
  with materially higher coverage than 0%.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `backend/internal/choreschedule/schedule_test.go` exists
- [ ] `cd backend && go test ./internal/choreschedule/ -v` all pass
- [ ] Coverage is materially non-zero (`-cover` prints > 60%)
- [ ] `schedule.go` is unchanged (`git diff --stat` shows only the new test file)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report (do NOT change `schedule.go`) if:
- A case you expected to pass reveals surprising behavior (e.g. weekly with a
  `days` subset skips a valid day, or rollover doesn't terminate) — capture the
  input and observed output in your report.
- The excerpt no longer matches live code (drift).

## Maintenance notes

- These lock in current behavior. If a future plan intentionally changes the due
  math, update these tests in that plan and call out the behavior change.
- Reviewer: verify the assertions are exact timestamps (not tautological) for the
  deterministic cases, and range assertions only where `time.Now()` is involved.
