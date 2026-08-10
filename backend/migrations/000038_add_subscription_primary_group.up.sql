-- A subscription now covers exactly one household — the "premium household",
-- chosen the way a PlayStation designates a primary console. Previously the
-- entitlement followed the payer into every household they belonged to.
--
-- Nullable because a subscription can exist before its household is picked:
-- checkout stamps the group it was started from, but a subscription created
-- outside that flow (or one whose household was later deleted) has none, and
-- the owner chooses in the app. A null primary_group_id covers nothing.
ALTER TABLE billing_subscriptions
    ADD COLUMN primary_group_id UUID REFERENCES groups(id) ON DELETE SET NULL;

-- The entitlement lookup asks "is any live subscription pinned to this group",
-- so the group is the leading column.
CREATE INDEX idx_billing_subscriptions_primary_group
    ON billing_subscriptions(primary_group_id, current_period_end)
    WHERE status IN ('active', 'trialing') AND primary_group_id IS NOT NULL;
