CREATE TABLE testing_signups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(254) NOT NULL CHECK (email = lower(btrim(email))),
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
    consent_version TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (email, platform)
);
