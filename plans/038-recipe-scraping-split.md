# Plan 038: Split the recipe-scraping monolith behind a parser interface

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat eca86757..HEAD -- backend/internal/services/recipe_scraping_service.go`
> On any change, re-read the file before starting; on material mismatch, STOP.
> Known drift, already reconciled 2026-07-04: plan 034's SSRF hardening changed
> ~76 lines of this file's **fetch** paths (uncommitted Batch-2 work at
> reconcile time). Line refs below were refreshed against that tree. If the
> fetch code you see does not use `security.ValidateAndResolveURL` with
> per-redirect re-validation, you are on a pre-034 tree — STOP.

## Status

- **Priority**: P3
- **Effort**: L
- **Risk**: MED (many format branches; needs characterization tests first)
- **Depends on**: none (but Step 0 characterization tests are mandatory)
- **Category**: tech-debt
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

`recipe_scraping_service.go` is 2090 lines — ~9× the service median — mixing HTTP
fetch, HTML/JSON-LD/microdata parsing, AMP fallback, and AI fallback in one file.
The README calls recipe clipping a rough, "AI-only" area. It's hard to test a
single parser branch or add per-site parsers (a stated product direction) without
touching the whole monolith. Extracting parsing strategies behind a small
interface makes per-site parsers additive and each branch independently testable.

## Current state

`backend/internal/services/recipe_scraping_service.go` (2104 lines as of the
2026-07-04 refresh, post-plan-034). Read it in full before starting. Its
concerns, roughly:
- **Fetch**: `ScrapeRecipe` (`:95`), `fetchHTML`, `fetchOnce` (`:330`, pinned
  transport + redirect validation), `fetchViaFlareSolverr` (`:274`). SSRF is
  handled via `security.ValidateAndResolveURL` (hardened by plan 034 —
  preserve its behavior exactly when moving fetch code).
- **Parse**: `scrapeHTML` (`:158`) and its helpers — JSON-LD, microdata, and
  heuristic extraction; AMP fallback in `ScrapeRecipe`.
- **AI fallback**: the AI-based extraction path.

Its test is `recipe_scraping_service_test.go` (~626 lines) — read it to see what
behavior is already pinned before you move code.

**This is a refactor, not a behavior change.** Same inputs → same
`RecipeClipResponse`.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Build | `cd backend && go build ./...` | exit 0 |
| Vet | `cd backend && go vet ./...` | exit 0 |
| Tests | `cd backend && go test ./internal/services/ -run Recipe` | pass |
| Cover | `cd backend && go test ./internal/services/ -run Recipe -cover` | prints coverage |

## Scope

**In scope**:
- `backend/internal/services/recipe_scraping_service.go`
- New files under `backend/internal/services/` for the extracted parsers, e.g.
  `recipe_parser_jsonld.go`, `recipe_parser_microdata.go`, `recipe_parser_ai.go`,
  and an interface file `recipe_parser.go` (same package — keep it internal).
- `backend/internal/services/recipe_scraping_service_test.go` and new
  `recipe_parser_*_test.go`

**Out of scope**:
- The SSRF fetch hardening — Plan 034 owns `fetchViaFlareSolverr`/pinning changes.
  If 034 has landed, do not undo it; if not, do not fix SSRF here — only relocate
  code, keeping fetch behavior identical.
- Changing the `RecipeClipResponse` shape or the `/assistant`/recipe endpoints.

## Git workflow

- Branch: `advisor/038-recipe-scraping-split`
- Commit per extraction; conventional commits, e.g.
  `refactor(recipe): extract JSON-LD parser strategy`.

## Steps

### Step 0 (mandatory): lock behavior with characterization tests

Before moving any code, make sure the existing behavior is pinned. Review
`recipe_scraping_service_test.go`; add cases so each parse strategy (JSON-LD,
microdata, AMP, AI-fallback) has at least one input→output test using a fixed HTML
fixture. These tests must pass against the CURRENT monolith. They are the safety
net for the whole refactor.

**Verify**: `cd backend && go test ./internal/services/ -run Recipe -v` → pass
against unmodified `recipe_scraping_service.go`.

### Step 1: Define the parser interface

Add `recipe_parser.go` with a minimal strategy interface, e.g.:

```go
type recipeParser interface {
	// parse attempts to extract a recipe from the document; returns (nil, false)
	// if this strategy doesn't apply.
	parse(doc *html.Node, pageURL string) (*RecipeClipResponse, bool)
}
```
(Match the real types the current parse functions use — `*html.Node`, `*goquery.Document`,
or raw HTML string; use whatever the existing helpers already take so extraction
is mechanical.)

**Verify**: `cd backend && go build ./...` → exit 0.

### Step 2: Extract strategies one at a time

Move JSON-LD parsing into `recipe_parser_jsonld.go` implementing the interface;
run tests. Then microdata; run tests. Then AI-fallback; run tests. After each
extraction the service calls the strategies in order (preserving the current
precedence: structured data first, AI last). Do one strategy per commit and keep
the suite green between commits.

**Verify after each**: `cd backend && go test ./internal/services/ -run Recipe` → pass.

### Step 3: Slim the service to orchestration

`recipe_scraping_service.go` should end up as: fetch + a list of parser strategies
tried in order + AMP fallback wiring. Confirm it is materially smaller.

**Verify**: `wc -l backend/internal/services/recipe_scraping_service.go` → well
under 2090 (target < 1000); `go test ./internal/services/ -run Recipe` → pass.

## Test plan

- Step 0 characterization tests are the safety net; they must pass before and
  after.
- Each new `recipe_parser_*_test.go` tests its strategy in isolation with a fixture.
- Model on the existing `recipe_scraping_service_test.go`.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd backend && go build ./... && go vet ./...` exit 0
- [ ] `recipe_parser.go` defines a parser interface; ≥ 2 strategy files implement it
- [ ] `wc -l backend/internal/services/recipe_scraping_service.go` < 1000
- [ ] `cd backend && go test ./internal/services/ -run Recipe` passes (same behavior)
- [ ] New per-strategy tests exist and pass
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- Step 0 characterization tests can't be made to pass against the current code —
  do NOT refactor without the safety net.
- Extraction forces a change to `RecipeClipResponse` or an endpoint — that's a
  behavior change; STOP.
- The parse functions share deeply-entangled mutable state that resists a clean
  strategy split — report the entanglement; a partial extraction may be the
  pragmatic outcome.

## Maintenance notes

- **This unblocks the "per-site parsers" direction**: once the interface exists,
  adding a site-specific parser is a new file implementing `recipeParser` +
  registration, no monolith surgery. That is the recommended next product step.
- Reviewer: focus on behavior parity via the characterization tests; the diff is
  large but should be pure code movement plus the interface.
