DROP INDEX IF EXISTS idx_settlements_group_status;

ALTER TABLE settlements
    DROP COLUMN IF EXISTS status,
    DROP COLUMN IF EXISTS created_by,
    DROP COLUMN IF EXISTS responded_at;
