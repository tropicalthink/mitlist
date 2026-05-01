DROP INDEX IF EXISTS idx_list_items_added_by;

ALTER TABLE list_items
    DROP COLUMN IF EXISTS added_by;

