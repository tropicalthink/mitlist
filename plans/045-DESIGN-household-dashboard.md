# Plan 045 (SPIKE): Design a household dashboard as the primary landing surface

> **Executor instructions**: This is a **design spike**, not a build plan. The
> deliverable is a written design document (`plans/045-DESIGN.md`) answering the
> questions below with recommendations — plus, optionally, a throwaway prototype.
> Do NOT ship a dashboard from this plan. Run the read-only investigation
> commands, write the doc, and update this plan's row in `plans/README.md`.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- frontend/lib/screens/pinwall/pinwall_board_screen.dart frontend/lib/screens/home`
> If these changed, re-read them before writing the design.

## Status

- **Priority**: P3
- **Effort**: L (spike is M; the build it scopes is L)
- **Risk**: LOW (spike produces a doc, not code)
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

`PRODUCT.md`'s design principle #4 is "What's due, clearly" — household
coordination "lives and dies on seeing what needs attention: overdue chores,
outstanding balances, unpurchased list items should be immediately scannable."
The pinwall board's `_BoardStatsCard` already aggregates chores + finance + lists
into one glanceable view, and the providers behind it
(`cachedCurrentChoresByGroupProvider`, `cachedFinanceSummaryByGroupProvider`, etc.)
already exist. That means a "household dashboard" — a primary landing surface that
answers "what needs my attention right now" — is an *adjacent possible*: the data
model and providers largely support it. This spike decides whether to invest,
and if so, scopes it. Strategy is the maintainer's call; this produces grounded
options.

## Current state (evidence to ground the design)

- `frontend/lib/screens/pinwall/pinwall_board_screen.dart` — contains
  `_BoardStatsCard` / `_BoardTonightTicket` aggregating multiple domains. This is
  the closest existing thing to a dashboard.
- `frontend/lib/screens/home/` — the current home/landing surface. Read it to see
  what lands first today and how it differs from the stats card.
- `frontend/lib/widgets/hub/pinwall_section.dart` — has `_ChoresStatRow`,
  `_FinanceStatRow`, `_ListsStatRow`, `_TonightStatRow` — the per-domain summary
  rows a dashboard would compose.
- Providers to inventory: grep
  `grep -rn "cached.*ByGroupProvider\|presentMembersProvider\|SummaryProvider" frontend/lib`
  to list what aggregate data is already available client-side.

## Investigation commands (read-only)

| Purpose | Command |
|---------|---------|
| Current home | `sed -n '1,120p' frontend/lib/screens/home/*.dart` (read the landing screen) |
| Existing aggregates | `grep -rn "cached.*ByGroupProvider\|SummaryProvider" frontend/lib \| sort -u` |
| Stats card | read `_BoardStatsCard` in `pinwall_board_screen.dart` |
| Backend summary endpoints | `grep -rn "Summary\|summary" backend/internal/api/handlers/finance.go backend/internal/api/handlers/chore.go` |

## Deliverable: `plans/045-DESIGN.md`

Answer all six questions with a recommendation each:

1. **What is the dashboard's job?** Define the one-screen "what needs attention"
   surface concretely: which signals (overdue chores, outstanding balance/who owes
   whom, unpurchased list items, tonight's meal, upcoming calendar) and their
   priority order. Ground each in an existing provider/endpoint.

2. **Reuse vs rebuild.** Can the existing `_BoardStatsCard`/stat-row widgets be
   promoted into a reusable dashboard, or is the pinwall coupling too tight?
   (Cross-reference Plan 039, which extracts shared pinwall widgets — does this
   depend on it?)

3. **Data completeness.** For each signal, is the aggregate already available
   client-side (a provider) or does it need a new/extended backend summary
   endpoint? List the gaps with effort estimates.

4. **Where does it live?** Replace the current home surface, add a new tab, or
   restructure the hub? Note the navigation/routing impact (`router.dart`).

5. **Offline behavior.** The app is offline-first; the dashboard must degrade
   gracefully. Which signals are available offline (cached providers) vs require
   network? How does it show stale data?

6. **Scope slices.** Break the build into shippable increments (e.g. v1: reuse
   stat rows read-only on home; v2: actionable tap-throughs; v3: personalization)
   with coarse effort estimates and a dependency order. Flag what depends on
   Plans 037/039.

## Done criteria

- [ ] `plans/045-DESIGN.md` exists and answers all six questions with a recommendation each
- [ ] Every proposed signal cites an existing provider/endpoint or names the gap
- [ ] Implementation slices listed with coarse estimates and dependency order
- [ ] A clear go/no-go recommendation for the maintainer
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- The investigation shows the aggregates are NOT actually reusable (the stats card
  is deeply pinwall-coupled and the providers are pinwall-specific) — that changes
  the recommendation to "rebuild," which is a bigger bet; say so plainly.

## Maintenance notes

- This is a decision aid, not an approval to build. The maintainer chooses whether
  and how to proceed; selected slices become their own build plans.
- If Plan 039 (shared pinwall widgets) lands first, revisit question 2 — the
  extraction may already make the stat widgets dashboard-ready.
