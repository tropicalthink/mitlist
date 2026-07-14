DROP INDEX IF EXISTS idx_attachments_failed_cleanup;
DROP INDEX IF EXISTS idx_attachments_pending_expiry;

ALTER TABLE attachments
    DROP COLUMN IF EXISTS reservation_expires_at;

ALTER TABLE groups
    DROP COLUMN IF EXISTS storage_reserved_bytes,
    DROP COLUMN IF EXISTS storage_used_bytes;
