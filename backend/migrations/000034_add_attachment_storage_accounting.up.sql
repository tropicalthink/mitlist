ALTER TABLE groups
    ADD COLUMN storage_used_bytes BIGINT NOT NULL DEFAULT 0 CHECK (storage_used_bytes >= 0),
    ADD COLUMN storage_reserved_bytes BIGINT NOT NULL DEFAULT 0 CHECK (storage_reserved_bytes >= 0);

ALTER TABLE attachments
    ADD COLUMN reservation_expires_at TIMESTAMPTZ;

UPDATE groups g
SET storage_used_bytes = usage.ready_bytes,
    storage_reserved_bytes = usage.pending_bytes
FROM (
    SELECT group_id,
           COALESCE(SUM(byte_size) FILTER (WHERE status = 'ready'), 0) AS ready_bytes,
           COALESCE(SUM(byte_size) FILTER (WHERE status = 'pending'), 0) AS pending_bytes
    FROM attachments
    GROUP BY group_id
) usage
WHERE g.id = usage.group_id;

UPDATE attachments
SET reservation_expires_at = created_at + INTERVAL '20 minutes'
WHERE status = 'pending';

CREATE INDEX idx_attachments_pending_expiry
    ON attachments (reservation_expires_at)
    WHERE status = 'pending';

CREATE INDEX idx_attachments_failed_cleanup
    ON attachments (created_at)
    WHERE status = 'failed';
