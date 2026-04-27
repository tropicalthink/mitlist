ALTER TABLE list_items
ADD COLUMN IF NOT EXISTS note TEXT NOT NULL DEFAULT '';

ALTER TABLE list_items
ALTER COLUMN quantity TYPE NUMERIC(12,3)
USING quantity::NUMERIC;

CREATE TABLE IF NOT EXISTS shopping_locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (group_id, name)
);

CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    barcode TEXT NOT NULL DEFAULT '',
    unit TEXT NOT NULL DEFAULT '',
    store_id UUID REFERENCES shopping_locations(id) ON DELETE SET NULL,
    min_stock NUMERIC(12,3) NOT NULL DEFAULT 0,
    in_stock NUMERIC(12,3) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (group_id, name)
);

ALTER TABLE list_items
ADD COLUMN IF NOT EXISTS product_id UUID REFERENCES products(id) ON DELETE SET NULL;

ALTER TABLE list_items
ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES shopping_locations(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_list_items_active_name_unit
ON list_items (list_id, lower(trim(name)), lower(trim(unit)))
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_list_items_active_checked
ON list_items (list_id, checked)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_products_group_barcode
ON products (group_id, barcode)
WHERE barcode <> '';

CREATE INDEX IF NOT EXISTS idx_list_items_store
ON list_items (list_id, store_id)
WHERE deleted_at IS NULL;
