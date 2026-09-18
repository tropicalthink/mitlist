-- Kept as a one-statement migration because the pgx migration driver sends a
-- whole file in one batch and PostgreSQL forbids concurrent index creation in
-- a transaction block.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_expenses_group_date
    ON expenses (group_id, date);
