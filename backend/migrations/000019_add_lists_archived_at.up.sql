ALTER TABLE lists
    ADD COLUMN archived_at TIMESTAMPTZ;

CREATE INDEX idx_lists_archived_at ON lists(archived_at);

