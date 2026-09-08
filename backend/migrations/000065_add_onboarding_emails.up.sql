-- Onboarding tips: a short series of emails after sign-up. Opt-out is per
-- account (not per household like notification preferences), because the
-- series is about the person learning the app, not about any one household.
ALTER TABLE users
    ADD COLUMN IF NOT EXISTS tips_emails_enabled BOOLEAN NOT NULL DEFAULT true;

-- One row per (user, step) is the idempotency ledger: a step is sent at most
-- once, and a step that keeps failing (bouncing address, provider down) stops
-- being retried after a few attempts instead of hammering the quota.
CREATE TABLE onboarding_email_sends (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    step TEXT NOT NULL,
    sent_at TIMESTAMPTZ,
    failed_attempts INT NOT NULL DEFAULT 0,
    last_error TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, step)
);
