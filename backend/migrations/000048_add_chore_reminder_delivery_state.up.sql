ALTER TABLE chore_assignments
    ADD COLUMN reminder_sent_at TIMESTAMPTZ;

CREATE INDEX idx_chore_assignments_due_reminders
    ON chore_assignments (due_date)
    WHERE status = 'pending' AND due_date IS NOT NULL AND reminder_sent_at IS NULL;
