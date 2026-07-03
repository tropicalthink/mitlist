# Plan 034: Harden server-side outbound fetch against SSRF (blocklist + rebinding)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> "STOP condition" occurs, stop and report. When done, update this plan's row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 8aec2a1e..HEAD -- backend/internal/security/ssrf.go backend/internal/services/recipe_scraping_service.go backend/internal/services/push/endpoint.go`
> On any change, compare live code to the excerpts below first; on mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (over-tight re-validation can reduce scrape/push success)
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `8aec2a1e`, 2026-07-03

## Why this matters

The backend makes server-side outbound HTTP requests from user-supplied targets
in two places — recipe scraping and web-push delivery. Both share an SSRF
blocklist that misses shared/reserved ranges, and both have DNS-rebinding gaps
where validation happens at one time but the fetch happens later against a
possibly-different IP. Consolidating a hardened blocklist and re-validating at
fetch/send time closes the internal-network exposure. This plan bundles four
related findings because they touch the same two files and share one fix (a
shared, complete blocklist + re-resolution at use).

## Current state

**1. Blocklist misses CGNAT/reserved ranges** (`security/ssrf.go:128-148`):

```go
func isBlockedIP(ip net.IP) bool {
	if ip == nil { return true }
	if ip.IsLoopback() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() || ip.IsMulticast() || ip.IsUnspecified() { return true }
	if ip.IsPrivate() { return true }
	if ip.To4() == nil { if len(ip) == net.IPv6len { if ip[0]&0xfe == 0xfc { return true } } }
	return false   // ← no 100.64.0.0/10 (CGNAT), 192.0.0.0/24, 198.18.0.0/15, IPv4-mapped IPv6 normalization
}
```

**2. Push endpoint blocklist has the same gap + validates only at registration**
(`services/push/endpoint.go:22-24, 77-91`): `checkIP` omits the same ranges, and
the doc comment states send-time re-validation is not done (DNS rebinding
residual risk).

**3. FlareSolverr fallback fetches the raw URL outside the pinned transport**
(`recipe_scraping_service.go:246-247, 270-323`): on direct-fetch failure it POSTs
`validated.URL.String()` to an external FlareSolverr browser that re-resolves DNS
and follows redirects itself — the IP pinning from `NewPinnedTransport` is not in
effect, so a low-TTL rebind reaches internal targets. Opt-in via
`SCRAPER_FLARESOLVER_URL`.

**4. Pinned transport dials the original IP on every redirect**
(`ssrf.go:59-68` + `recipe_scraping_service.go:334-343`): `CheckRedirect`
re-validates the new host, but the transport stays pinned to the original URL's
IPs — so a legitimate cross-host redirect connects to the wrong origin (a
reliability bug, not a security hole; the SSRF re-validation is intact).

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Build | `cd backend && go build ./...` | exit 0 |
| Vet | `cd backend && go vet ./...` | exit 0 |
| Tests | `cd backend && go test ./internal/security/ ./internal/services/ ./internal/services/push/` | pass |

## Scope

**In scope**:
- `backend/internal/security/ssrf.go`
- `backend/internal/services/push/endpoint.go`
- `backend/internal/services/recipe_scraping_service.go`
- Test files: `backend/internal/security/ssrf_test.go`,
  `backend/internal/services/push/endpoint_test.go` (create/extend)

**Out of scope**:
- Deploying FlareSolverr on an egress-restricted network — that is an infra
  control, noted in Maintenance, not code.
- Changing the scrape parsing logic.

## Git workflow

- Branch: `advisor/034-ssrf-outbound-hardening`
- Conventional commit: `fix(security): harden SSRF blocklist and re-validate outbound targets`.

## Steps

### Step 1: Complete and share the blocklist (fixes findings 1 & 2)

In `ssrf.go`, extend `isBlockedIP` to also block, via explicit `net.ParseCIDR`
checks: `100.64.0.0/10` (RFC 6598 CGNAT), `192.0.0.0/24`, `192.0.2.0/24`,
`198.18.0.0/15`, `198.51.100.0/24`, `203.0.113.0/24`, `240.0.0.0/4`, and the
IPv6 documentation/benchmark ranges as appropriate. Normalize IPv4-mapped IPv6
first: `if v4 := ip.To4(); v4 != nil { ip = v4 }` before the range checks so
`::ffff:100.64.0.1` is caught. Define the CIDR list once as package vars.

Then make `push/endpoint.go` `checkIP` use the **same** hardened predicate —
either export `security.IsBlockedIP(ip)` and call it from push, or extract the
range set into a shared helper both import. Preserve the push package's
`*api.ValidationError` messages (map a blocked result to a validation error).

**Verify**: `cd backend && go build ./...` → exit 0.

### Step 2: Re-resolve + re-validate the push endpoint at send time (finding 2)

Find the push send path (`grep -rn "func.*Send" backend/internal/services/push/`).
Before issuing the HTTP request to a stored endpoint, re-resolve its host and run
the shared blocklist on the resolved IPs (or pin the connection to a validated IP
as the recipe path does). If re-resolution fails or resolves to a blocked range,
skip that delivery (and optionally mark the subscription for cleanup). Keep it
best-effort so a transient DNS failure doesn't crash the send loop.

**Verify**: `cd backend && go build ./... && go vet ./...` → exit 0.

### Step 3: Pin/re-validate the FlareSolverr fetch (finding 3)

Before calling `fetchViaFlareSolverr`, re-resolve and re-validate the target
host immediately (call `security.ValidateAndResolveURL` again). FlareSolverr
itself runs a browser you cannot pin, so the strongest code-level mitigation is:
(a) re-validate right before the call, and (b) document that FlareSolverr must run
on an egress-restricted network (Maintenance). At minimum, re-validate so a host
that has already rebound to an internal IP is rejected before FlareSolverr sees
it. Do not remove the fallback.

**Verify**: `cd backend && go build ./...` → exit 0.

### Step 4: Re-pin per redirect (finding 4 — reliability)

In `fetchOnce`'s `CheckRedirect` (or by handling redirects manually), when the
redirect target host differs from the pinned host, re-resolve+validate the new
host and rebuild the pinned transport for its IPs so the connection actually
reaches the intended origin. This must re-run the SSRF checks (never dial an
unvalidated host). If re-pinning mid-client is impractical with the current
structure, an acceptable alternative is to disable pinning-based cross-host
redirects and instead perform redirects manually with a fresh validated client
per hop. Pick the smaller change and keep SSRF validation on every hop.

**Verify**: `cd backend && go build ./... && go vet ./...` → exit 0.

### Step 5: Tests

- `ssrf_test.go`: table of IPs asserting `isBlockedIP`/`IsBlockedIP` blocks
  loopback, private, link-local, CGNAT `100.64.0.1`, `198.18.0.1`, IPv4-mapped
  `::ffff:100.64.0.1`, and allows a normal public IP (e.g. `93.184.216.34`).
- `push/endpoint_test.go`: `ValidatePushEndpoint` rejects a CGNAT host/IP and an
  IPv4-mapped internal address; accepts a public https endpoint.

**Verify**: `cd backend && go test ./internal/security/ ./internal/services/push/ -v` → pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `cd backend && go build ./... && go vet ./...` exit 0
- [ ] `grep -n "100.64.0.0/10\|100\\.64" backend/internal/security/ssrf.go` → present
- [ ] push `checkIP` uses the shared hardened predicate (grep shows it calls the security helper, not its own partial switch)
- [ ] The FlareSolverr call is preceded by a re-validate of the target (visible in the diff at `recipe_scraping_service.go`)
- [ ] Redirects to a different host re-validate AND connect to the new host's validated IP (finding 4 addressed or explicitly documented as manual-redirect)
- [ ] New SSRF/push tests pass, including the CGNAT and IPv4-mapped cases
- [ ] `cd backend && go test ./internal/security/ ./internal/services/ ./internal/services/push/` pass
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report if:
- The push send path cannot be located or is structured so send-time re-validation
  needs a broad refactor — do Steps 1, 3, 4, 5 and report Step 2 as needing its
  own plan.
- Re-pinning per redirect (Step 4) requires restructuring the HTTP client
  ownership beyond this file — report the blast radius; finding 4 is reliability,
  not security, and may be split out.

## Maintenance notes

- Infra follow-up (not code): run FlareSolverr on a network with no route to
  internal ranges; the code re-validation is defense-in-depth, not a substitute.
- The blocklist is now the single source of truth for "unsafe outbound target" —
  any new outbound-fetch feature must use it.
- Reviewer: verify IPv4-mapped IPv6 normalization happens before the range checks,
  and that no legitimate public destination is newly blocked.
