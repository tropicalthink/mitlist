-- Link a list item to the canonical grocery node it resolved to, so scans and
-- typed items share one identity and history accumulates against it.
ALTER TABLE list_items
    ADD COLUMN IF NOT EXISTS canonical_item_id UUID REFERENCES canonical_items(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_list_items_canonical_item_id ON list_items(canonical_item_id);
