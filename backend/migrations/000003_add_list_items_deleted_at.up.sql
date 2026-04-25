ALTER TABLE list_items
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_list_items_deleted_at ON list_items (deleted_at);
