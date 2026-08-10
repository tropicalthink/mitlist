DROP INDEX IF EXISTS idx_auth_sessions_family_id;
ALTER TABLE auth_sessions DROP COLUMN IF EXISTS family_id;
