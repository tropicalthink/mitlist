DROP INDEX IF EXISTS idx_list_items_claimed_by;

ALTER TABLE list_items
    DROP COLUMN IF EXISTS claimed_at,
    DROP COLUMN IF EXISTS claimed_by;

