# Plan 005: Reconcile client slug ids with server UUIDs so grocery sync can carry real data

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 48e6867c..HEAD -- frontend/lib/repositories/grocery_repository.dart frontend/lib/utils/uuid_validation.dart backend/internal/services/grocery_service.go backend/internal/repositories/grocery_repo.go backend/internal/api/handlers/grocery.go`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: plans/001-fix-grocery-sync-spine.md (sync must work at all before ids matter)
- **Category**: bug / tech-debt
- **Planned at**: commit `48e6867c`, 2026-07-02

## Why this matters

Even with the sync endpoints fixed (Plan 001), almost no correction can ever reach the server, for a structural reason: the bundled grocery seed uses **slug ids** (`milk`, `strawberry` — 3,242 items, see `frontend/assets/grocery/seed.json`), while the server schema types every canonical reference as `uuid.UUID` with FK constraints to a `canonical_items` table **that nothing populates**. The client knows this and refuses to upload (`isApiUuid` guard). Net effect: household members never share learned aliases. This plan establishes a deterministic id bridge — UUIDv5 derived from the slug — plus an on-demand canonical upsert on the server, so corrections flow member-to-member without shipping a 3,242-row server catalog (that larger option is the Plan 019 spike).

**The id scheme**: `apiId(slug) = uuidv5(NAMESPACE_URL, 'mitlist:canonical:<slug>')`. Deterministic, computable independently on every device, collision-free per slug, and stable across app versions. Local Drift rows keep their slugs (human-readable, used throughout tests); translation happens only at the sync boundary.

## Current state

- Client upload guard — `frontend/lib/repositories/grocery_repository.dart:249-257`:

```dart
  Future<int> uploadCorrection({ ... required String canonicalItemId, ... }) async {
    if (!isApiUuid(canonicalItemId)) return 0;
```

and `frontend/lib/utils/uuid_validation.dart`:

```dart
/// True when [id] is a UUID the backend will accept in JSON fields typed as
/// `uuid.UUID`. Bundled grocery seed uses stable slugs (e.g. `milk`) locally;
/// those must not be sent to the API until the server graph has assigned a UUID.
bool isApiUuid(String? id) => ...
```

- Client delta apply — `grocery_repository.dart:85-190` (`_applyDelta`) upserts `canonical_items`, `item_aliases`, `corrections`, `store_aisles` rows verbatim, keyed by whatever ids the server sends. If the server sends UUIDv5 canonical ids, the local resolver (keyed by slugs) would not connect them — this plan adds reverse translation.

- Server correction write — `backend/internal/services/grocery_service.go:83-125` (`RecordCorrection`): inserts the correction, then `UpsertAlias(ctx, groupID, *req.ResolvedCanonicalID, ...)`. Both `corrections.resolved_canonical_item_id` and `item_aliases.canonical_item_id` are FK-constrained to `canonical_items(id)` (`backend/migrations/000027_add_grocery_graph.up.sql:44,69`), and no code inserts into `canonical_items` — so any correction referencing a canonical item currently fails the FK even with valid UUIDs.

- Server models — `backend/internal/models/grocery.go:12-25` (`CanonicalItem` struct exists and is already serialized in the delta).

- Aisle feedback has the same disease on a second axis: `store_aisles.store_id` is `UUID REFERENCES shopping_locations(id)` (migration line 82) and `AisleFeedbackItem.StoreID` is `*uuid.UUID` (`grocery_repo.go:258-263`), but the client's shipped store layouts use string ids like `de_rewe` (`frontend/assets/grocery/store_aisles.json`). A PATCH with a seed store id fails JSON decoding. Bounded fix here: omit non-UUID store ids on upload (store-scoped layouts stay device-local); full store-identity unification is Plan 011/019.

- Dart uuid package (already a dependency, used as `Uuid().v4()` everywhere) supports v5: `const Uuid().v5(Uuid.NAMESPACE_URL, name)`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Frontend analyze | `cd frontend && dart analyze lib/` | exit 0 |
| Frontend tests | `cd frontend && flutter test test/services/ test/repositories/` | pass |
| Backend build | `cd backend && go build ./...` | exit 0 |
| Backend integration | `cd backend && go test ./internal/api/handlers/ -run TestGrocery -v` | PASS, no SKIP (needs `docker compose up -d`) |

## Scope

**In scope**:
- `frontend/lib/repositories/grocery_repository.dart`
- `frontend/lib/utils/uuid_validation.dart` (extend, don't delete)
- `frontend/lib/storage/app_database.dart` (only if a lookup helper is missing)
- `backend/internal/services/grocery_service.go`
- `backend/internal/repositories/grocery_repo.go` (add `UpsertCanonicalItem`)
- `backend/internal/api/handlers/grocery.go` (request field passthrough only)
- `backend/internal/api/handlers/grocery_integration_test.go` (extend Plan 001's file)
- `frontend/test/repositories/grocery_id_bridge_test.dart` (create)

**Out of scope**:
- Changing local Drift ids or regenerating `seed.json` — local slugs stay.
- Seeding the full global catalog server-side — Plan 019 spike decides that.
- `purchase_history` / `item_cooccurrence` sync — Plan 018 spike.
- Store identity unification — Plan 011 (client-side) and Plan 019.
- Relaxing/altering FK constraints in migrations.

## Git workflow

- Branch: `advisor/005-canonical-id-reconciliation`
- Commit style: `feat(grocery): bridge slug ids to deterministic UUIDs across sync`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: The id bridge helper (frontend)

In `frontend/lib/utils/uuid_validation.dart`, add:

```dart
const _canonicalNamespacePrefix = 'mitlist:canonical:';

/// Deterministic API id for a canonical item. Local slug ids (e.g. `milk`)
/// map to a stable UUIDv5 every device derives identically; ids that are
/// already UUIDs (server-assigned) pass through unchanged.
String apiCanonicalId(String localId) => isApiUuid(localId)
    ? localId
    : const Uuid().v5(Uuid.NAMESPACE_URL, '$_canonicalNamespacePrefix$localId');
```

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 2: Upload side — send the bridge id plus a canonical payload

In `grocery_repository.dart`'s `uploadCorrection`:

- Replace `if (!isApiUuid(canonicalItemId)) return 0;` with the mapping. Fetch the local canonical row (`_db.getCanonicalItemById(canonicalItemId)`) and include a `canonical_item` object so the server can create the row the FK needs:

```dart
    final apiId = apiCanonicalId(canonicalItemId);
    final item = await _db.getCanonicalItemById(canonicalItemId);
    if (item == null) return 0;
    ...
        data: {
          'raw_text': rawText,
          'kind': kind,
          'scope': scope,
          'canonical_item_id': apiId,
          'lang': lang,
          'canonical_item': {
            'id': apiId,
            'name_de': item.nameDe,
            'name_en': item.nameEn,
            'category': item.category,
            'default_unit': item.defaultUnit,
          },
        },
```

In `updateAisleFeedback`, translate `canonical_item_id` with `apiCanonicalId(...)` and **omit `store_id` when `!isApiUuid(e.storeId)`** (one-line comment: seed store layouts are device-local until store identity unifies).

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 3: Download side — translate incoming canonical ids back to local ids

In `_applyDelta`, before upserting aliases/corrections/aisles, build the reverse map once per call:

```dart
    // Server rows reference UUIDv5 bridge ids; local rows use slugs. Build the
    // reverse map (bridge id → local id) over the local catalog so pulled rows
    // reconnect to the items the resolver actually stores.
    final localItems = [
      ...await _db.getCanonicalItemsByGroup('__global__'),
      ...await _db.getCanonicalItemsByGroup(groupId),
    ];
    final reverse = {
      for (final it in localItems) apiCanonicalId(it.id): it.id,
    };
    String mapId(String id) => reverse[id] ?? id;
```

Apply `mapId` to `canonical_item_id` on incoming `item_aliases`, `store_aisles`, and `resolved_canonical_item_id` on `corrections`. For incoming `canonical_items` rows (household-created on another device): upsert them keeping the server id **unless** `reverse` already maps it (then skip — the local slug row is authoritative).

Check `getCanonicalItemsByGroup` exists in `app_database.dart` (it is used by `GrocerySeedLoader._loadSeedIfNeeded`, so it does). The map is ~3.3k entries built per pull — acceptable for a sync that runs at most once per SSE event/cold start; note it in a comment.

**Verify**: `cd frontend && dart analyze lib/` → exit 0

### Step 4: Server side — upsert the canonical row before the alias write

- `grocery_service.go`: extend the request struct:

```go
type RecordCorrectionRequest struct {
	RawText             string             `json:"raw_text"`
	Kind                string             `json:"kind"`
	Scope               string             `json:"scope"`
	ResolvedCanonicalID *uuid.UUID         `json:"canonical_item_id,omitempty"`
	Lang                string             `json:"lang"`
	CanonicalItem       *CanonicalItemStub `json:"canonical_item,omitempty"`
}

type CanonicalItemStub struct {
	ID          uuid.UUID `json:"id"`
	NameDe      string    `json:"name_de"`
	NameEn      string    `json:"name_en"`
	Category    string    `json:"category"`
	DefaultUnit string    `json:"default_unit"`
}
```

- In `RecordCorrection`, after `NextVersion` and before `InsertCorrection`: when `req.Kind == "alias" && req.ResolvedCanonicalID != nil && req.CanonicalItem != nil`, call a new repo method:

```go
// UpsertCanonicalItem ensures the referenced canonical node exists for this
// household (bridge rows for the client's bundled seed; ON CONFLICT keeps the
// earliest names). Stamped with the current version so it syncs in the delta.
func (r *GroceryRepository) UpsertCanonicalItem(ctx context.Context, groupID uuid.UUID, s *services-visible-stub, version int64) error
```

SQL shape: `INSERT INTO canonical_items (id, group_id, name_de, name_en, category, default_unit, is_global, version, created_at, updated_at) VALUES (...) ON CONFLICT (id) DO NOTHING` — `is_global=false`, timestamps `now()`. (Put the stub struct where both packages can see it — the existing pattern is request structs in `services` and plain args in `repositories`; passing the fields as scalar args to the repo avoids an import cycle. Follow `UpsertAlias`'s parameter style at `grocery_repo.go:328`.)

- Validate at the handler (`grocery.go`): if `kind == "alias"` and `canonical_item_id` is set but `canonical_item` is missing, respond with a `ValidationError` (field `canonical_item`) — matches the existing `raw_text` validation style at `grocery.go:103-105`.

**Verify**: `cd backend && go build ./...` → exit 0

### Step 5: Extend the integration test

In `grocery_integration_test.go` (from Plan 001), add: POST a correction whose canonical id was never seeded, carrying the `canonical_item` stub → 200; assert a `canonical_items` row now exists with that id, the alias row references it, and `GET .../graph?since_version=0` returns the canonical item + alias. Repeat the POST → still 200, still exactly one canonical row (ON CONFLICT path).

**Verify**: `cd backend && go test ./internal/api/handlers/ -run TestGrocery -v` → PASS

### Step 6: Frontend bridge test

Create `frontend/test/repositories/grocery_id_bridge_test.dart`:

1. `apiCanonicalId('milk')` is stable (equals itself on repeat call, is a valid UUID, differs from `apiCanonicalId('oat_milk')`).
2. `apiCanonicalId(<a v4 uuid>)` passes through unchanged.
3. `_applyDelta` reverse mapping: seed an in-memory DB with global item `milk`; apply a delta whose alias row references `apiCanonicalId('milk')`; assert the stored alias's `canonicalItemId == 'milk'` and `findAlias` resolves it. (If `_applyDelta` is private and hard to reach, make it `@visibleForTesting` — matching how other repositories expose test seams; check `list_repository.dart` for precedent, otherwise add the annotation.)

**Verify**: `cd frontend && flutter test test/repositories/grocery_id_bridge_test.dart` → all pass

## Test plan

Steps 5 and 6, plus regression: `flutter test test/services/` and `go test ./internal/services/ ./internal/repositories/` must stay green.

## Done criteria

- [ ] `cd frontend && dart analyze lib/` exits 0; `cd backend && go build ./...` exits 0
- [ ] `grep -n "return 0" frontend/lib/repositories/grocery_repository.dart | head -3` — the `isApiUuid` early-return in `uploadCorrection` is gone (replaced by the bridge)
- [ ] Backend integration test proves: unseeded canonical id + stub → correction persisted, alias FK satisfied, delta round-trips
- [ ] Frontend test proves: pulled alias rows reconnect to local slug items
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Plan 001 is not DONE in `plans/README.md` — this plan's tests cannot pass against the broken version counter.
- The Dart `uuid` package version in `pubspec.lock` lacks `v5` — report the version; do not swap the dependency.
- `canonical_items` gained a server-side seeding mechanism since planning (check for new migrations touching it) — coordinate with that instead of the on-demand upsert.
- Threading the stub through service→repo forces an import cycle you can't resolve with scalar parameters — report the shape you tried.

## Maintenance notes

- Plan 019 (server-delivered seed spike) may later seed all global items server-side with these same UUIDv5 ids — the namespace string `mitlist:canonical:<slug>` is now a **contract**; document any change to it as breaking.
- The reverse map in `_applyDelta` is rebuilt per pull; if pulls become frequent (SSE storms), cache it keyed by catalog version.
- Reviewer should scrutinize: `ON CONFLICT DO NOTHING` means the first uploader's names win for a bridge row; that's fine for seed-derived items (identical everywhere) and acceptable for household items.
- Deferred: store-id unification (Plan 011), purchase-history sync (Plan 018).
