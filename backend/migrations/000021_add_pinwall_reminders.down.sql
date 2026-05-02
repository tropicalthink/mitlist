DROP INDEX IF EXISTS idx_pinwall_posts_due_reminders;

ALTER TABLE pinwall_posts
    DROP COLUMN IF EXISTS reminder_sent_at,
    DROP COLUMN IF EXISTS remind_at;

ALTER TABLE notification_preferences
    DROP COLUMN IF EXISTS pinwall_reminder;

