-- The supporter pack: a one-time purchase that thanks the buyer with a badge
-- housemates can see and unlocks look customisation. It is tied to the person
-- who paid, not to a household — a theme is personal and follows its owner
-- everywhere, unlike a premium subscription which is pinned to one group.
--
-- A user is a supporter while they hold at least one row with status 'paid'.
-- A refund flips the row to 'refunded' rather than deleting it, so a replayed
-- purchase event can never resurrect a refunded purchase.
CREATE TABLE billing_supporter_purchases (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL DEFAULT 'polar',
    -- Polar order id, Apple original transaction id, or Play purchase token.
    provider_order_id TEXT NOT NULL,
    provider_customer_id TEXT NOT NULL DEFAULT '',
    product_id TEXT NOT NULL,
    -- 'paid' grants the perks; 'refunded' and 'pending' do not.
    status TEXT NOT NULL,
    amount_cents INTEGER NOT NULL DEFAULT 0 CHECK (amount_cents >= 0),
    currency TEXT NOT NULL DEFAULT 'eur',
    purchased_at TIMESTAMPTZ,
    refunded_at TIMESTAMPTZ,
    -- Provider timestamp used to discard out-of-order deliveries, mirroring
    -- billing_subscriptions.provider_modified_at.
    provider_modified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (provider, provider_order_id)
);

-- "Is this user a supporter" is asked on every status call and for every
-- member of a household listing, so the paid rows are indexed by user.
CREATE INDEX idx_billing_supporter_purchases_paid
    ON billing_supporter_purchases(user_id)
    WHERE status = 'paid';
