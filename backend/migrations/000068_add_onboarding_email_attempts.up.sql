-- Reserve every onboarding step before contacting the mail provider. This is
-- intentionally at-most-once: onboarding tips are non-critical, and skipping
-- one after an ambiguous provider failure is better than sending duplicates.
ALTER TABLE onboarding_email_sends
    ADD COLUMN attempted_at TIMESTAMPTZ NOT NULL DEFAULT now();
