DROP INDEX IF EXISTS idx_group_memberships_active;
DELETE FROM group_memberships WHERE left_at IS NOT NULL;
ALTER TABLE group_memberships DROP COLUMN IF EXISTS left_at;
