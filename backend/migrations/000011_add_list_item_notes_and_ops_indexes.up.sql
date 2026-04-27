ALTER TABLE list_items
ADD COLUMN IF NOT EXISTS note TEXT NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_list_items_active_name_unit
ON list_items (list_id, lower(trim(name)), lower(trim(unit)))
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_list_items_active_checked
ON list_items (list_id, checked)
WHERE deleted_at IS NULL;
