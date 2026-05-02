-- =============================================================================
-- Pinwall reminders
-- =============================================================================

ALTER TABLE pinwall_posts
    ADD COLUMN IF NOT EXISTS remind_at TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS reminder_sent_at TIMESTAMPTZ NULL;

-- Efficient lookup for due reminders.
CREATE INDEX IF NOT EXISTS idx_pinwall_posts_due_reminders
    ON pinwall_posts (remind_at)
    WHERE remind_at IS NOT NULL AND reminder_sent_at IS NULL;

-- Notification preference toggle for pinwall reminders.
ALTER TABLE notification_preferences
    ADD COLUMN IF NOT EXISTS pinwall_reminder BOOLEAN NOT NULL DEFAULT TRUE;

