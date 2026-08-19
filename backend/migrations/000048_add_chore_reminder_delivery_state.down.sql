DROP INDEX IF EXISTS idx_chore_assignments_due_reminders;

ALTER TABLE chore_assignments
    DROP COLUMN IF EXISTS reminder_sent_at;
