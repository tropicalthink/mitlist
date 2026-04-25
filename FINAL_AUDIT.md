# FINAL AUDIT — Consolidated findings

Legend: CRITICAL | HIGH | MEDIUM | LOW | FIXED | DEFERRED

## CRITICAL

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| AUTH-1 | CRITICAL | Backend Auth | No access token revocation on logout | **FIXED** |
| AUTH-2 | CRITICAL | Backend Auth | Login/register not rate-limited for brute force | **FIXED** |
| AUTH-3 | CRITICAL | Backend Auth | No brute force protection on login (account lockout) | **FIXED** |
| AUTH-4 | CRITICAL | Backend Auth | No CSRF protection for cookie-based auth | DEFERRED |
| FINANCE-1 | CRITICAL | Backend Finance | PayerID can be set to any group member | **FIXED** |
| FINANCE-2 | CRITICAL | Backend Finance | Split IsSettled can be modified by any member | **FIXED** |
| INFRA-1 | CRITICAL | Backend Config | Hardcoded dev secrets in docker-compose.yml | **FIXED** |
| UX-1 | CRITICAL | Frontend Lists | List detail screen shows mock data | **FIXED** |
| UX-2 | CRITICAL | Frontend Router | Vault/Living/Recipes screens not in router | **FIXED** |
| RES-1 | CRITICAL | Frontend Offline | No offline support | DEFERRED |
| RES-2 | CRITICAL | Frontend Lists | List detail screen uses mock data | **FIXED** |

## HIGH

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| SEC-CONFIG-1 | HIGH | Backend Infra | Rate limiter bypassed when Redis down | **FIXED** |
| RES-3 | HIGH | Frontend Auth | Token refresh not tested under failure | DEFERRED |
| RES-4 | HIGH | Frontend Network | No retry with backoff on network failures | DEFERRED |
| RES-5 | HIGH | Backend DB | Connection pool may exhaust under load | DEFERRED |
| RES-6 | HIGH | Backend AI | No timeout on external API calls | **FIXED** |
| UX-3 | HIGH | Frontend UX | No empty state guidance on first use | DEFERRED |
| UX-4 | HIGH | Frontend UX | Loading states flash briefly | **FIXED** |
| UX-5 | HIGH | Frontend UX | Error messages are generic | DEFERRED |
| UX-6 | HIGH | Frontend UX | No confirmation for destructive actions | DEFERRED |
| UX-7 | HIGH | Frontend UX | Chore completion not user-scoped | DEFERRED |
| PERF-1 | HIGH | Backend Perf | N+1 in chore rotation rebuild | **FIXED** |
| PERF-2 | HIGH | Backend Perf | Reorder items one-at-a-time | **FIXED** |

## MEDIUM

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| MED-1 | MEDIUM | Backend | Password reset token in plaintext email | DEFERRED |
| MED-2 | MEDIUM | Backend | Push notification service is a stub | DEFERRED |
| MED-3 | MEDIUM | Backend | No rate limiting on password reset | **FIXED** |
| MED-4 | MEDIUM | Backend | Missing CGO for race detection | DEFERRED |
| MED-5 | MEDIUM | Backend | Graceful shutdown may not drain requests | DEFERRED |
| MED-6 | MEDIUM | Backend | No health check for 3rd-party services | DEFERRED |
| PERF-5 | MEDIUM | Backend | No Redis caching for frequently accessed data | DEFERRED |
| UX-8 | MEDIUM | Frontend | No character limits shown on inputs | DEFERRED |
| UX-9 | MEDIUM | Frontend | Password policy not shown on signup | DEFERRED |
| UX-10 | MEDIUM | Frontend | No pull-to-refresh on account screen | DEFERRED |
| UX-11 | MEDIUM | Frontend | Settings changes give no feedback | DEFERRED |
| UX-12 | MEDIUM | Frontend | Welcome screen auto-advances too quickly | DEFERRED |
| PERF-4 | MEDIUM | Backend | Pagination limit high on some endpoints | DEFERRED |

## LOW

| ID | Severity | Area | Description | Status |
|----|----------|------|-------------|--------|
| LOW-1 | LOW | Backend | Missing indexes on high-traffic columns | DEFERRED |
| LOW-2 | LOW | Frontend | Integer-only amount fields (UX-14) | DEFERRED |
| LOW-3 | LOW | Frontend | No onboarding for returning users (UX-15) | DEFERRED |
| PERF-8 | LOW | Frontend | No image optimization | DEFERRED |
| PERF-9 | LOW | Frontend | Unused dependencies in pubspec | DEFERRED |

## DEFERRED items with justification

| ID | Reason |
|----|--------|
| AUTH-4 | CSRF protection requires OAuth/redirect flow redesign. Cookie-based auth is secondary to Bearer token auth. Acceptable risk for current scope. |
| RES-1 | Offline support is a significant feature requiring local database, sync engine, and conflict resolution. Tracked separately. |
| RES-3 | Token refresh failure paths need integration tests. Requires running backend + test harness. |
| RES-4 | Retry with backoff is an enhancement. Current behavior (user retries manually) is acceptable. |
| RES-5 | Pool size of 20 is appropriate for initial deployment. Monitor and increase based on production metrics. |
| UX-3 | Empty states show basic guidance. Enhancement tracked for next iteration. |
| UX-5 | Error messages include backend details. Field-level error display needs frontend architectural change. |
| UX-6 | Confirmation dialogs are a UX enhancement, not a data safety issue (all operations check permissions). |
| UX-7 | Any member completing chores is a design choice for shared households. |
| MED-1 | Password reset token lifetime is 24h, single-use. Email interception is out-of-scope for this system. |
| MED-2 | Push notifications are a stub. Full implementation requires push infrastructure setup. |
| MED-4 | Race detection requires CGO. Documented in build instructions. |
| MED-5 | Shutdown timeout of 30s is adequate for current scale. |
| MED-6 | Health checks for external services is an enhancement for multi-region deployment. |
| PERF-5 | Cache layer is an optimization, not a correctness requirement. |
| UX-8-12 | UX polish items tracked for next UI iteration. |
| PERF-4 | Default pagination of 50 items is appropriate. Max 500 is bounded. |
| LOW-1 | Migration creates indexes for all FK columns. Additional indexes would be query-specific. |
| LOW-2 | Amounts as integers (cents) is standard for financial applications. UI could accept decimal input. |
| LOW-3 | Onboarding replay is a nice-to-have, not essential. |
| PERF-8 | Image optimization depends on S3/media infrastructure not yet in place. |
| PERF-9 | Unused dependencies removed from pubspec spec. |
