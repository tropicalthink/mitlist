-- Track who added an item to a list (for activity feed attribution).
ALTER TABLE list_items
    ADD COLUMN IF NOT EXISTS added_by UUID REFERENCES users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_list_items_added_by ON list_items(added_by);

