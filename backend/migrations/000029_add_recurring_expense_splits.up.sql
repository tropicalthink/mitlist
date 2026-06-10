ALTER TABLE recurring_expenses ADD COLUMN IF NOT EXISTS split_mode TEXT NOT NULL DEFAULT 'payer_only';
ALTER TABLE recurring_expenses ADD COLUMN IF NOT EXISTS split_inputs JSONB NOT NULL DEFAULT '[]'::jsonb;
