-- Scheduled reminder retries must reuse the same inbox item for each user.
-- Interactive notifications omit dedupe_key and retain normal append semantics.
CREATE UNIQUE INDEX idx_notifications_scheduled_dedupe
    ON notifications (user_id, type, (data->>'dedupe_key'))
    WHERE data->>'dedupe_key' IS NOT NULL;
