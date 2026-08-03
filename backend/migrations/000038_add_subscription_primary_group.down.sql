-- Reverting restores the "covers every household the payer belongs to" model,
-- so the per-subscription household choice is discarded.
DROP INDEX IF EXISTS idx_billing_subscriptions_primary_group;

ALTER TABLE billing_subscriptions
    DROP COLUMN IF EXISTS primary_group_id;
