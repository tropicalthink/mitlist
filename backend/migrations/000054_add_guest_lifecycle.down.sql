DROP INDEX IF EXISTS idx_users_guest_lifecycle;
ALTER TABLE users
    DROP COLUMN IF EXISTS guest_locked_at,
    DROP COLUMN IF EXISTS guest_last_seen_at;
