DROP INDEX IF EXISTS idx_lists_archived_at;

ALTER TABLE lists
    DROP COLUMN IF EXISTS archived_at;

