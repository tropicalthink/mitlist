-- First-party product events (plans/048 stage 8): the onboarding funnel and
-- Home actions, so the team can see where new households stall. Pre-signup
-- events carry only a random install id the app generated; signed-in events
-- carry the user. No IP address, user agent or free text is stored: names
-- come from a fixed allowlist and props hold short enumerated values.
CREATE TABLE product_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    occurred_at TIMESTAMPTZ NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    name        TEXT NOT NULL,
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    install_id  UUID,
    group_id    UUID REFERENCES groups(id) ON DELETE CASCADE,
    role        TEXT CHECK (role IN ('creator', 'invitee')),
    props       JSONB NOT NULL DEFAULT '{}'::jsonb,
    CHECK (user_id IS NOT NULL OR install_id IS NOT NULL)
);

CREATE INDEX product_events_name_occurred_idx ON product_events (name, occurred_at);
CREATE INDEX product_events_user_idx ON product_events (user_id, occurred_at) WHERE user_id IS NOT NULL;
