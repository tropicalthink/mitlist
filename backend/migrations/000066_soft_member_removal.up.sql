ALTER TABLE group_memberships ADD COLUMN IF NOT EXISTS left_at TIMESTAMPTZ;

-- Almost every membership lookup is "active members of this group".
CREATE INDEX IF NOT EXISTS idx_group_memberships_active
    ON group_memberships (group_id, user_id)
    WHERE left_at IS NULL;
