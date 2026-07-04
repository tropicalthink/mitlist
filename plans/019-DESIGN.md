# Plan 019 Design: Server-Delivered Seed

## Recommendation Summary

Keep the bundled seed as the offline bulk floor and deliver versioned server patches for global taxonomy, aliases, store layouts, and OFF aliases. Add a dedicated catalog patch endpoint rather than pushing the full catalog through every household delta. Use the existing UUIDv5 slug contract for canonical ids.

No PoC was created. The `groups` table requires `created_by UUID NOT NULL REFERENCES users(id)`, so a reserved global group row is not a trivial insert without either a synthetic system user or a schema change. The design below avoids requiring global rows in the household delta as the first implementation step.

## Measured Payloads

Current bundled assets:

- `seed.json`: 5,360,320 bytes raw, 968,944 bytes gzipped, 3,242 items, version 5
- `store_aisles.json`: 112,638 bytes raw, 7,228 bytes gzipped after Plan 017
- `off_aliases.json`: 17,417 bytes raw, 5,102 bytes gzipped

Representative patch:

- 100 alias additions serialized as a patch: 8,652 bytes raw, 174 bytes gzipped

Conclusion: bulk catalog delivery is feasible but unnecessary on every sync. Patch delivery is much cheaper and keeps cold starts fast.

## 1. Delivery Channel

Recommendation: versioned catalog patch endpoint, with the bundled asset as the baseline:

```text
GET /grocery/catalog/patches?since_seed_version=5
```

Rejected alternatives:

- Existing per-group delta for global rows: simple, but it would force every household first sync to page through the catalog and requires solving the synthetic global group FK immediately.
- Full catalog endpoint only: cacheable, but wastes bandwidth for small alias fixes and complicates offline fallback.

The endpoint should return global changes since the client's bundled/apply cursor: canonical item additions/updates/tombstones, alias additions/tombstones, store layout updates, OFF alias updates, and `max_seed_version`.

## 2. Source Of Truth And Publishing Flow

Recommendation: `build_app_seed.py` remains the source build step and emits both app assets and a server publish artifact:

```text
frontend/assets/grocery/seed.json
frontend/assets/grocery/seed.version.json
intelligence/ml/dist/seed-v<N>-server.json
```

Publishing should be one operator command that validates parity, writes patch rows into catalog tables or object storage, and records the active version in a `seed_versions` table.

Rejected alternative: hand-written SQL migrations for every seed release. Migrations are reviewable but too large and error-prone for 3,000+ item catalogs.

## 3. Precedence And Tombstones

Recommendation: merge order is household override > wire-global patch > bundled-global seed.

Tombstones must be explicit. A patch that removes or replaces an alias/item should include `deleted_at` or a tombstone operation. The client must not clear-and-reinsert server patch state the way bundled reseed does; it should apply patches idempotently by id/version.

Rejected alternative: lower-version rollback. The existing version gate ignores lower versions, so rollback must publish a higher-version corrective patch instead of decrementing the version.

## 4. FR/ES Columns

Recommendation: add `name_fr` and `name_es` to server `canonical_items` before server-delivered catalog items become authoritative.

Rejected alternative: DE/EN-only wire catalog. The app seed and classifier parity now rely on four-language seed data; dropping FR/ES over the wire would make server patches less complete than the bundled floor.

Alias rows already carry `lang`, so alias language coverage does not need a new table shape.

## 5. Store Layouts And OFF Aliases

Recommendation: include both in the patch channel, but as separate patch sections and version counters:

- `taxonomy_version`
- `store_aisle_version`
- `off_alias_version`

Store aisles are small and high impact, especially after Plan 017. OFF aliases are also small. Both benefit from server updates without app releases.

Rejected alternative: keep aisle/OFF bundled-only. That preserves simplicity but leaves the two most iterative data assets tied to app releases.

## 6. Failure And Rollback

Recommendation:

- publish staged versions first
- run parity and smoke checks before activation
- activate by moving a single `active_seed_version` pointer
- rollback by publishing a higher-version patch that reverts the bad rows
- keep the client fail-soft: if patch fetch or validation fails, continue using bundled data plus the last valid applied patch

Rejected alternative: let clients accept lower versions for rollback. That breaks monotonic cursor semantics and risks divergent devices.

## Implementation Slices

1. Server catalog schema and publish artifact (M): `seed_versions`, patch storage, `name_fr/name_es`, validation command.
2. Catalog patch endpoint (M): unauthenticated or authenticated read, cache headers, gzip-friendly JSON, integration tests.
3. Client patch ingest (M): store a global catalog cursor, apply patches after bundled seed load, preserve bundled fallback.
4. Store aisle/OFF patch support (M): split version counters and update `GrocerySeedLoader` to ingest those patch sections.
5. Release/rollback docs (S): add seed publish checklist to `RELEASING.md` and intelligence README.

## Open Questions

- Should catalog patch reads require authentication, or can they be public static assets on self-hosted deployments?
- Should the server persist full catalog rows in Postgres or serve static JSON artifacts generated by the intelligence pipeline?
- What is the first supported migration path for devices that have bundled v4 or older assets?

