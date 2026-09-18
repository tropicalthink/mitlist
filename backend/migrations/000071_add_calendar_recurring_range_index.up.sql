-- A partial composite index matches the calendar predicate and excludes
-- inactive recurring expenses from the index entirely.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_recurring_expenses_group_next_due_active
    ON recurring_expenses (group_id, next_due)
    WHERE is_active = TRUE;
