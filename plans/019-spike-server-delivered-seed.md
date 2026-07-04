# Plan 019 (SPIKE): Design server-delivered seed — taxonomy and alias updates without app releases

> **Executor instructions**: This is a DESIGN SPIKE. The deliverable is a
> design document (`plans/019-DESIGN.md`) — no production code. Investigate,
> decide, document, list open questions. Honor STOP conditions. Update the
> index row when done.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- backend/internal/repositories/grocery_repo.go frontend/lib/services/grocery_seed_loader.dart intelligence/ml/build_app_seed.py`
> Plans 001/005/013/014 are expected inputs here, not drift.

## Status

- **Priority**: P3
- **Effort**: L (coarse — spike itself is M)
- **Risk**: MED
- **Depends on**: plans/001, 005 landed (the UUIDv5 bridge is this design's id contract); 014 recommended (pagination for the big first pull)
- **Category**: direction
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

Today, improving the base grocery taxonomy or aliases requires **an app-store release**: the seed is a bundled asset, version-gated on device. Yet the sync layer was clearly designed for more — `canonical_items.is_global` exists server-side, the delta query already includes global rows for every household (`grocery_repo.go:64-66`: `WHERE (group_id = $1 OR is_global = true)`), a reserved global group id is baked into the alias resolution SQL (`grocery_repo.go:302-313`), and the client's `isApiUuid` doc comment anticipates server-assigned ids. Server-delivered seed turns alias fixes, new items, and aisle updates into a deploy instead of a release cycle — and it structurally completes Plan 005 (every canonical id would exist server-side, ending on-demand stub upserts). This spike decides whether/how, without committing to shipping 3,242 items × 4 languages through the delta on day one.

## What exists (read these first)

- Bundled path: `frontend/lib/services/grocery_seed_loader.dart` — version-gated ingest of `seed.json` (5.4 MB), `store_aisles.json`, `off_aliases.json` into Drift under `groupId '__global__'`; Plan 013 adds the sidecar/off-isolate mechanics.
- Asset build: `intelligence/ml/build_app_seed.py` — `ASSET_VERSION` constant, slug ids, alias enrichment pipeline.
- Server global conventions: reserved global group UUID (`00000000-…-0`) in `ResolveAlias` (`grocery_repo.go:302-313`); `is_global` on `canonical_items` (migration 000027:31); delta already ships global canonical rows.
- Schema constraint to resolve: `canonical_items.group_id UUID NOT NULL REFERENCES groups(id)` (migration 000027:25) — a global row needs the reserved group to exist as a real `groups` row (check `groups`' NOT NULL columns; a seed migration may need a synthetic system group).
- Id contract from Plan 005: `uuidv5(NAMESPACE_URL, 'mitlist:canonical:<slug>')` — server-seeded rows must use these exact ids or the client's reverse mapping breaks.
- Language gap: server `canonical_items` has `name_de`/`name_en` only (migration/model), local seed has FR/ES too — schema addition or acceptable loss? Decide.

## Questions the design doc must answer

1. **Delivery channel**: (a) global rows through the existing per-group delta (zero new endpoints, but every household's first sync pulls the whole catalog — size it against Plan 014's pagination); (b) a dedicated versioned catalog endpoint (`GET /grocery/catalog?since_version=`) cacheable at the CDN/proxy layer, with the bundled asset as the offline floor; (c) keep the bundle as the only *bulk* channel and deliver **delta patches** (renames, new items, alias additions) over the wire. Recommendation to evaluate first: (c) then (b) — the bundle already solves bulk cold-start well (Plan 013 made it cheap), so the wire only needs to carry *changes since the bundled version*.
2. **Source of truth + publishing flow**: today `build_app_seed.py` → asset. Server-delivered means the same build must also emit a server-side artifact (SQL migration? admin upload endpoint? a `seed_versions` table + loader job?). Design the publish step so seed v6 is one command targeting both channels.
3. **Precedence and tombstones**: device has bundled v5 + wire patches to v7 + household overrides — define the merge order (household > wire-global > bundled-global by version) and how a *removed* item propagates (the schema has `deleted_at` tombstones; the bundled reseed path clears-and-reinserts — reconcile the two).
4. **FR/ES columns**: add `name_fr/name_es` (+ alias langs already exist) server-side, or declare the wire channel DE/EN-only and keep FR/ES bundled-only? Migration cost is trivial; decide on principle.
5. **Store layouts and OFF aliases**: same mechanism or explicitly bundled-only for now? (Aisle coverage is 7% — Plan 017 — so wire-delivering it early has outsized value.)
6. **Failure/rollback**: a bad seed publish reaching every device within minutes — version pinning, server-side rollback semantics, and the client's fail-soft guarantees (the version-gate means a *lower* version is ignored — is that the rollback story?).

## Spike steps

1. Read the listed code; answer the six questions with recommendation + rejected alternative each.
2. Size the payloads: full catalog JSON vs realistic patch (e.g. v5→v6 = curated alias additions) — measure from `build_app_seed.py` inputs; state bytes on the wire per device per publish.
3. No PoC unless trivially cheap: at most, a local SQL sketch proving the reserved-group seed insert satisfies the FKs (`docker compose` postgres + hand `INSERT`) — timebox one hour.
4. List implementation slices with S/M/L estimates (likely: 1 server seed publish + reserved group, 2 client wire-patch ingest alongside the bundle path, 3 aisle/OFF channels, 4 ops/rollback docs in RELEASING.md).

## Done criteria

- [ ] `plans/019-DESIGN.md` answers all six questions with recommendations
- [ ] Payload sizes measured and stated
- [ ] Implementation slices listed with estimates and dependency order
- [ ] `plans/README.md` status row updated

## STOP conditions

- Plan 005 not DONE — the id contract this design builds on doesn't exist yet.
- The `groups` table cannot host a synthetic system group without violating auth invariants (e.g. NOT NULL `created_by` FK to a real user) — surface the constraint; the design may need a schema change instead of a convention.

## Maintenance notes

- Decisions here bound Plan 018's first-sync payload too (both ride the delta) — cross-reference the two design docs.
- If (c) delta-patches wins, `build_app_seed.py`'s `ASSET_VERSION` becomes a shared version axis between bundle and wire; document it in `intelligence/README.md`'s pipeline table (Plan 016).
