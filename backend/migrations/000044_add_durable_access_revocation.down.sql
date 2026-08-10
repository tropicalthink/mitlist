DROP TABLE IF EXISTS auth_access_revocations;
ALTER TABLE users DROP COLUMN IF EXISTS auth_valid_after;
