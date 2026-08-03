-- Household premium billing. A subscription belongs to the user who pays for
-- it; the entitlement it grants applies to every household that user belongs
-- to, so there is deliberately no group_id here.
CREATE TABLE billing_subscriptions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider TEXT NOT NULL DEFAULT 'polar',
    provider_subscription_id TEXT NOT NULL,
    provider_customer_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    status TEXT NOT NULL,
    recurring_interval TEXT,
    -- Amount actually charged, after any discount. Stored so revenue reporting
    -- reflects what was paid rather than the catalog price.
    amount_cents INTEGER NOT NULL DEFAULT 0 CHECK (amount_cents >= 0),
    currency TEXT NOT NULL DEFAULT 'eur',
    discount_id TEXT,
    current_period_end TIMESTAMPTZ,
    cancel_at_period_end BOOLEAN NOT NULL DEFAULT FALSE,
    trial_end TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    -- The provider's own modified_at for this subscription. Webhook deliveries
    -- can arrive out of order; an update older than what we already stored is
    -- discarded rather than applied.
    provider_modified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (provider, provider_subscription_id)
);

CREATE INDEX idx_billing_subscriptions_user_id ON billing_subscriptions(user_id);

-- Supports the entitlement lookup, which only ever asks for live subscriptions.
CREATE INDEX idx_billing_subscriptions_entitlement
    ON billing_subscriptions(user_id, current_period_end)
    WHERE status IN ('active', 'trialing');

-- Delivered webhook IDs, for idempotency. Polar follows Standard Webhooks, so
-- every delivery carries a stable webhook-id; a redelivery of an event we have
-- already applied is acknowledged without being applied twice.
CREATE TABLE billing_webhook_events (
    id TEXT PRIMARY KEY,
    provider TEXT NOT NULL DEFAULT 'polar',
    event_type TEXT NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_billing_webhook_events_processed_at ON billing_webhook_events(processed_at);
