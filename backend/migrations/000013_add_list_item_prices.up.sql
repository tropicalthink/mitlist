-- Add price_cents to list_items for cost tracking
ALTER TABLE list_items
    ADD COLUMN IF NOT EXISTS price_cents INTEGER;

-- Add index for cost summary queries
CREATE INDEX IF NOT EXISTS idx_list_items_price ON list_items(list_id, price_cents) WHERE price_cents IS NOT NULL;
