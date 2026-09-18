DROP INDEX IF EXISTS idx_lists_due_reminders;

ALTER TABLE lists
    DROP COLUMN IF EXISTS reminder_claimed_at,
    DROP COLUMN IF EXISTS reminder_sent_at,
    DROP COLUMN IF EXISTS remind_at;
