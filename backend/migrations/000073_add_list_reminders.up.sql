-- =============================================================================
-- List reminders: a one-time "remind the household about this list" timestamp.
-- Mirrors pinwall reminders (000021 + 000050): remind_at is the scheduled time,
-- reminder_sent_at is set once delivered, reminder_claimed_at is the short
-- lease the reminder job takes while dispatching so parallel runs never
-- double-send.
-- =============================================================================

ALTER TABLE lists
    ADD COLUMN IF NOT EXISTS remind_at TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS reminder_sent_at TIMESTAMPTZ NULL,
    ADD COLUMN IF NOT EXISTS reminder_claimed_at TIMESTAMPTZ NULL;

-- Efficient lookup for due, unsent reminders on live lists.
CREATE INDEX IF NOT EXISTS idx_lists_due_reminders
    ON lists (remind_at)
    WHERE remind_at IS NOT NULL AND reminder_sent_at IS NULL AND archived_at IS NULL;
