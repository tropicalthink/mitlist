-- Revert list item prices
DROP INDEX IF EXISTS idx_list_items_price;
ALTER TABLE list_items
    DROP COLUMN IF EXISTS price_cents;
