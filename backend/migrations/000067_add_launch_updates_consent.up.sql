ALTER TABLE testing_signups
    ADD COLUMN launch_updates BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN launch_consent_version TEXT,
    ADD COLUMN launch_consented_at TIMESTAMPTZ;

ALTER TABLE testing_signups
    ADD CONSTRAINT testing_signups_launch_consent_complete CHECK (
        (launch_updates = FALSE AND launch_consent_version IS NULL AND launch_consented_at IS NULL)
        OR
        (launch_updates = TRUE AND launch_consent_version IS NOT NULL AND launch_consented_at IS NOT NULL)
    );
