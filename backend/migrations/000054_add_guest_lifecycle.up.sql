-- Guest identities are recoverable after inactivity. The last-seen timestamp
-- drives locking; the lock timestamp starts the long retention/grace window.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS guest_last_seen_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS guest_locked_at TIMESTAMPTZ;

UPDATE users
SET guest_last_seen_at = COALESCE(guest_last_seen_at, created_at)
WHERE is_guest;

CREATE INDEX IF NOT EXISTS idx_users_guest_lifecycle
    ON users (guest_locked_at, guest_last_seen_at)
    WHERE is_guest AND deleted_at IS NULL;
