DROP INDEX IF EXISTS idx_list_items_canonical_item_id;

ALTER TABLE list_items
    DROP COLUMN IF EXISTS canonical_item_id;
