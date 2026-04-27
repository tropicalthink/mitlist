DROP INDEX IF EXISTS idx_list_items_active_checked;
DROP INDEX IF EXISTS idx_list_items_active_name_unit;
ALTER TABLE list_items DROP COLUMN IF EXISTS note;
