ALTER TABLE testing_signups
    DROP CONSTRAINT IF EXISTS testing_signups_launch_consent_complete,
    DROP COLUMN IF EXISTS launch_consented_at,
    DROP COLUMN IF EXISTS launch_consent_version,
    DROP COLUMN IF EXISTS launch_updates;
