ALTER TABLE auth_sessions
    ADD COLUMN family_id UUID;

UPDATE auth_sessions SET family_id = uuid_generate_v4() WHERE family_id IS NULL;

ALTER TABLE auth_sessions
    ALTER COLUMN family_id SET NOT NULL;

CREATE INDEX idx_auth_sessions_family_id ON auth_sessions(family_id);
