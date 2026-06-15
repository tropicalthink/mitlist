-- Base-currency projection of each expense. amount/currency stay the original
-- entered values; base_amount is amount converted to the group's currency at
-- fx_rate (base_amount = round(amount * fx_rate)). Existing rows are all in the
-- group currency, so base_amount = amount and fx_rate = 1.
ALTER TABLE expenses ADD COLUMN base_amount BIGINT NOT NULL DEFAULT 0;
ALTER TABLE expenses ADD COLUMN fx_rate NUMERIC(18,8) NOT NULL DEFAULT 1;

UPDATE expenses SET base_amount = amount WHERE base_amount = 0;
