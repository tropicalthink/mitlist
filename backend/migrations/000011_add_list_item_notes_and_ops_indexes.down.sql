DROP INDEX IF EXISTS idx_list_items_store;
DROP INDEX IF EXISTS idx_products_group_barcode;
DROP INDEX IF EXISTS idx_list_items_active_checked;
DROP INDEX IF EXISTS idx_list_items_active_name_unit;
ALTER TABLE list_items DROP COLUMN IF EXISTS store_id;
ALTER TABLE list_items DROP COLUMN IF EXISTS product_id;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS shopping_locations;
ALTER TABLE list_items
ALTER COLUMN quantity TYPE INTEGER
USING CEIL(quantity)::INTEGER;
ALTER TABLE list_items DROP COLUMN IF EXISTS note;
