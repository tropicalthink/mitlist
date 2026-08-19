ALTER TABLE pinwall_posts
    ADD COLUMN reminder_claimed_at TIMESTAMPTZ;

ALTER TABLE chore_assignments
    ADD COLUMN reminder_claimed_at TIMESTAMPTZ;

DROP INDEX IF EXISTS idx_pinwall_posts_due_reminders;
CREATE INDEX idx_pinwall_posts_due_reminders
    ON pinwall_posts(remind_at)
    WHERE remind_at IS NOT NULL AND reminder_sent_at IS NULL;
