-- =============================================================================
-- Grocery Intelligence System — graph schema
--
-- The grocery graph is the household's living memory of what it buys, how it
-- writes items, where they live in stores, and what belongs together. Every
-- table is scoped to a household (group_id) and carries a monotonic `version`
-- so clients can pull deltas via GET /grocery/graph?since_version=N. Soft
-- deletes (deleted_at) act as tombstones so deletions also sync.
-- =============================================================================

-- Per-household monotonic version counter. The grocery service bumps this in a
-- transaction and stamps the new value onto each written row, giving clients a
-- gap-free `since_version` cursor.
CREATE TABLE grocery_versions (
    group_id        UUID        PRIMARY KEY REFERENCES groups(id) ON DELETE CASCADE,
    current_version BIGINT      NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- The canonical grocery node. Language-neutral identity; display names are
-- per-language. is_global marks the shipped base taxonomy vs household-created
-- items. product_id optionally links to a tracked inventory product.
CREATE TABLE canonical_items (
    id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id     UUID        NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    name_de      TEXT        NOT NULL DEFAULT '',
    name_en      TEXT        NOT NULL DEFAULT '',
    category     TEXT        NOT NULL DEFAULT '',
    default_unit TEXT        NOT NULL DEFAULT '',
    product_id   UUID        REFERENCES products(id) ON DELETE SET NULL,
    is_global    BOOLEAN     NOT NULL DEFAULT false,
    version      BIGINT      NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at   TIMESTAMPTZ
);

-- Shorthand / spelling / OCR forms that resolve to a canonical item. alias_text
-- is normalized (lowercased, trimmed). weight is reinforced on repeated
-- confirmation. This is the hot lookup path that makes a correction "stick".
CREATE TABLE item_aliases (
    id                UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id          UUID        NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    canonical_item_id UUID        NOT NULL REFERENCES canonical_items(id) ON DELETE CASCADE,
    alias_text        TEXT        NOT NULL,
    lang              TEXT        NOT NULL DEFAULT 'und',
    source            TEXT        NOT NULL DEFAULT 'correction'
                                  CHECK (source IN ('seed', 'correction', 'ocr_observed')),
    weight            INTEGER     NOT NULL DEFAULT 1,
    version           BIGINT      NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at        TIMESTAMPTZ,
    UNIQUE (group_id, alias_text)
);

-- Unified, append-only correction event log. Never UPDATEd — new facts are new
-- rows. A materializer projects confirmed corrections into item_aliases /
-- store_aisles. scope distinguishes household-wide vs per-user corrections.
CREATE TABLE corrections (
    id                       UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id                 UUID        NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id                  UUID        REFERENCES users(id) ON DELETE SET NULL,
    scope                    TEXT        NOT NULL DEFAULT 'household'
                                         CHECK (scope IN ('household', 'user')),
    kind                     TEXT        NOT NULL
                                         CHECK (kind IN ('alias', 'canonical', 'aisle', 'unit', 'reject')),
    raw_text                 TEXT        NOT NULL DEFAULT '',
    resolved_canonical_item_id UUID      REFERENCES canonical_items(id) ON DELETE SET NULL,
    corrected_value          JSONB,
    source                   TEXT        NOT NULL DEFAULT 'manual_review'
                                         CHECK (source IN ('manual_review', 'auto_accept', 'import')),
    version                  BIGINT      NOT NULL DEFAULT 0,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
    applied_at               TIMESTAMPTZ
);

-- Canonical item -> aisle, per store. sort_order drives shopping-route ordering.
CREATE TABLE store_aisles (
    id                UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id          UUID         NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    store_id          UUID         REFERENCES shopping_locations(id) ON DELETE CASCADE,
    canonical_item_id UUID         NOT NULL REFERENCES canonical_items(id) ON DELETE CASCADE,
    aisle             TEXT         NOT NULL DEFAULT '',
    sort_order        INTEGER      NOT NULL DEFAULT 0,
    confidence        REAL         NOT NULL DEFAULT 0.5,
    version           BIGINT       NOT NULL DEFAULT 0,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at        TIMESTAMPTZ,
    UNIQUE (group_id, store_id, canonical_item_id)
);

-- Append-only purchase signal, fed on item check-off / confirmed receipt scan.
CREATE TABLE purchase_history (
    id                UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id          UUID         NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    canonical_item_id UUID         REFERENCES canonical_items(id) ON DELETE SET NULL,
    list_item_id      UUID         REFERENCES list_items(id) ON DELETE SET NULL,
    quantity          NUMERIC(12,3) NOT NULL DEFAULT 1,
    unit              TEXT         NOT NULL DEFAULT '',
    version           BIGINT       NOT NULL DEFAULT 0,
    purchased_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- "Bought together" matrix for suggestions. item_a_id < item_b_id by convention
-- so each unordered pair has a single row.
CREATE TABLE item_cooccurrence (
    group_id     UUID        NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    item_a_id    UUID        NOT NULL REFERENCES canonical_items(id) ON DELETE CASCADE,
    item_b_id    UUID        NOT NULL REFERENCES canonical_items(id) ON DELETE CASCADE,
    count        INTEGER     NOT NULL DEFAULT 0,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    version      BIGINT      NOT NULL DEFAULT 0,
    PRIMARY KEY (group_id, item_a_id, item_b_id)
);

-- Scan provenance + retraining corpus. Local-first; raw images are only
-- uploaded on explicit user consent (image_ref may be a local-only path).
CREATE TABLE scan_artifacts (
    id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id     UUID        NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id      UUID        REFERENCES users(id) ON DELETE SET NULL,
    image_ref    TEXT        NOT NULL DEFAULT '',
    engine       TEXT        NOT NULL DEFAULT 'mlkit'
                             CHECK (engine IN ('mlkit', 'crofai')),
    raw_json     JSONB,
    resolved_json JSONB,
    version      BIGINT      NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    synced_at    TIMESTAMPTZ
);

-- =============================================================================
-- Indexes
-- =============================================================================

-- Hot lookup path: resolve an OCR token to its canonical item.
CREATE INDEX idx_item_aliases_group_text ON item_aliases(group_id, alias_text);
CREATE INDEX idx_item_aliases_canonical ON item_aliases(canonical_item_id);

-- Per-household delta scans (version > N) for sync.
CREATE INDEX idx_canonical_items_group_version ON canonical_items(group_id, version);
CREATE INDEX idx_item_aliases_group_version ON item_aliases(group_id, version);
CREATE INDEX idx_corrections_group_version ON corrections(group_id, version);
CREATE INDEX idx_store_aisles_group_version ON store_aisles(group_id, version);
CREATE INDEX idx_purchase_history_group_version ON purchase_history(group_id, version);
CREATE INDEX idx_item_cooccurrence_group_version ON item_cooccurrence(group_id, version);
CREATE INDEX idx_scan_artifacts_group_version ON scan_artifacts(group_id, version);

CREATE INDEX idx_store_aisles_store ON store_aisles(store_id);
CREATE INDEX idx_purchase_history_group_item ON purchase_history(group_id, canonical_item_id);
